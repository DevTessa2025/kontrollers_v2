import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';
import '../services/auth_service.dart';
import '../services/sql_server_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _hasConnection = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _autoSync();
  }

  Future<void> _checkConnection() async {
    bool connected = await AuthService.hasInternetConnection();
    setState(() {
      _hasConnection = connected;
    });
  }

  Future<void> _autoSync() async {
    // Sincronización automática al cargar la pantalla
    if (await AuthService.hasInternetConnection()) {
      setState(() {
        _isSyncing = true;
      });

      try {
        Map<String, dynamic> syncResult = await IntelligentSyncService.performIntelligentSync();

        if (syncResult['sync_status'] == 'success') {
          print('Sincronización exitosa: ${syncResult['synced_items']} elementos');
        } else {
          print('Sincronización con problemas: ${syncResult['message']}');
        }
      } catch (e) {
        // Error silencioso en auto-sync, el usuario puede hacer sync manual si quiere
        print('Auto-sync error: $e');
      }

      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? result = await AuthService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (result != null && result['success']) {
        Fluttertoast.showToast(
          msg: "Login exitoso (${result['mode']})",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        Fluttertoast.showToast(
          msg: result?['message'] ?? 'Error de login',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      Map<String, dynamic> syncResult = await IntelligentSyncService.performIntelligentSync();

      if (syncResult['sync_status'] == 'success') {
        print('Sincronización exitosa: ${syncResult['synced_items']} elementos');
      } else {
        print('Sincronización con problemas: ${syncResult['message']}');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error de sincronización: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    setState(() {
      _isSyncing = false;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      bool connectionOk = await SqlServerService.testConnection();
      
      Fluttertoast.showToast(
        msg: connectionOk 
            ? 'Conexión al servidor exitosa' 
            : 'No se pudo conectar al servidor',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: connectionOk ? Colors.green : Colors.red,
        textColor: Colors.white,
      );

      if (connectionOk) {
        await _checkConnection();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error probando conexión: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    setState(() {
      _isSyncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo o título
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.agriculture,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32),
                  
                  Text(
                    'KONTROLLERS',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                  
                  SizedBox(height: 8),
                  
                  Text(
                    'Sistema de Gestión Agrícola',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[600],
                    ),
                  ),
                  
                  SizedBox(height: 48),

                  // Indicador de conexión y sincronización automática
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasConnection ? Icons.wifi : Icons.wifi_off,
                        color: _hasConnection ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _hasConnection ? 'En línea' : 'Sin conexión',
                        style: TextStyle(
                          color: _hasConnection ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isSyncing && _hasConnection) ...[
                        SizedBox(width: 16),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Sincronizando...',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  SizedBox(height: 24),

                  // Campo de usuario
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      labelStyle: TextStyle(color: Colors.red[700]),
                      prefixIcon: Icon(Icons.person, color: Colors.red[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red[700]!, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese su usuario';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 16),

                  // Campo de contraseña
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      labelStyle: TextStyle(color: Colors.red[700]),
                      prefixIcon: Icon(Icons.lock, color: Colors.red[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red[700]!, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese su contraseña';
                      }
                      return null;
                    },
                  ),
                  
                  SizedBox(height: 24),

                  // Botón de login
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'INGRESAR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  SizedBox(height: 16),

                  // Botón de sincronización
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _syncData,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[700]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSyncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red[700],
                              ),
                            )
                          : Icon(Icons.sync),
                      label: Text(
                        _isSyncing ? 'SINCRONIZANDO...' : 'SINCRONIZAR MANUALMENTE',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Botón de test de conexión
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: TextButton.icon(
                      onPressed: _isSyncing ? null : _testConnection,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                      icon: Icon(Icons.network_check, size: 20),
                      label: Text(
                        'PROBAR CONEXIÓN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}