import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/dropdown_service.dart';
import 'login_screen.dart';
import 'checklist_bodega_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? currentUser;
  bool _hasConnection = false;
  bool _isValidating = false;
  bool _isSyncing = false;
  Map<String, int> _dbStats = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkConnection();
    _loadDatabaseStats();
    _validateUserPeriodically();
    _autoSyncOnLoad();
    
    // Validar cada 30 segundos mientras la pantalla esté activa
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _validateUserQuietly();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _autoSyncOnLoad() async {
    // Sincronización automática al cargar la pantalla principal
    if (await AuthService.hasInternetConnection()) {
      setState(() {
        _isSyncing = true;
      });

      try {
        print('Iniciando sincronización automática en home screen...');
        Map<String, dynamic> result = await AuthService.syncData();

        if (result['success']) {
          int users = result['usersSynced'] ?? 0;
          int dropdown = result['dropdownSynced'] ?? 0;
          
          // Solo mostrar toast si se sincronizaron datos nuevos
          if (users > 0 || dropdown > 0) {
            Fluttertoast.showToast(
              msg: "Sincronización completa: $users usuarios, $dropdown datos adicionales",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green[600],
              textColor: Colors.white,
            );
          }

          // Actualizar estadísticas después de la sincronización
          await _loadDatabaseStats();
        } else {
          print('Error en sincronización automática: ${result['message']}');
        }
      } catch (e) {
        print('Error en sincronización automática: $e');
      }

      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _manualSync() async {
    if (!await AuthService.hasInternetConnection()) {
      Fluttertoast.showToast(
        msg: 'No hay conexión a internet para sincronizar',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      print('Iniciando sincronización manual...');
      Fluttertoast.showToast(
        msg: 'Sincronizando datos...',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue[600],
        textColor: Colors.white,
      );

      Map<String, dynamic> result = await AuthService.syncData();

      if (result['success']) {
        int users = result['usersSynced'] ?? 0;
        int dropdown = result['dropdownSynced'] ?? 0;
        
        Fluttertoast.showToast(
          msg: "Sincronización exitosa: $users usuarios, $dropdown datos adicionales",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );

        // Actualizar estadísticas y estado de conexión
        await _loadDatabaseStats();
        await _checkConnection();
      } else {
        Fluttertoast.showToast(
          msg: "Error en sincronización: ${result['message']}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error durante la sincronización: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _loadDatabaseStats() async {
    try {
      Map<String, int> stats = await DropdownService.getLocalStats();
      setState(() {
        _dbStats = stats;
      });
    } catch (e) {
      print('Error cargando estadísticas de BD: $e');
    }
  }

  Future<void> _validateUserPeriodically() async {
    setState(() {
      _isValidating = true;
    });

    try {
      print('Iniciando validación de usuario en home screen...');
      // Usar validación forzada para asegurar que se verifique en servidor
      bool isActive = await AuthService.forceValidateActiveUser();
      
      if (!isActive) {
        print('Usuario no activo, mostrando mensaje y redirigiendo...');
        // Usuario desactivado, mostrar mensaje y redirigir al login
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'Su usuario ha sido desactivado. Cerrando sesión...',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red[700],
            textColor: Colors.white,
            fontSize: 16,
          );
          
          await Future.delayed(Duration(seconds: 3));
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
        return;
      }
      
      print('Usuario validado correctamente');
    } catch (e) {
      print('Error validating user: $e');
    }

    if (mounted) {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _validateUserQuietly() async {
    try {
      // Validación silenciosa cada 30 segundos
      bool isActive = await AuthService.forceValidateActiveUser();
      
      if (!isActive && mounted) {
        print('Usuario desactivado detectado en validación silenciosa');
        Fluttertoast.showToast(
          msg: 'Su usuario ha sido desactivado. Cerrando sesión...',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red[700],
          textColor: Colors.white,
          fontSize: 16,
        );
        
        await Future.delayed(Duration(seconds: 2));
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } catch (e) {
      print('Error en validación silenciosa: $e');
    }
  }

  Future<void> _loadUserData() async {
    Map<String, dynamic>? user = await AuthService.getCurrentUser();
    setState(() {
      currentUser = user;
    });
  }

  Future<void> _checkConnection() async {
    bool connected = await AuthService.hasInternetConnection();
    setState(() {
      _hasConnection = connected;
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isValidating = true;
    });

    print('Refrescando datos y validando usuario...');
    
    await _checkConnection();
    await _loadDatabaseStats();
    
    // También intentar sincronización si hay conexión
    if (await AuthService.hasInternetConnection()) {
      await _autoSyncOnLoad();
    }
    
    // Usar validación forzada en el refresh
    bool isActive = await AuthService.forceValidateActiveUser();
    
    if (!isActive) {
      print('Usuario desactivado durante refresh');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Su usuario ha sido desactivado. Cerrando sesión...',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red[700],
          textColor: Colors.white,
          fontSize: 16,
        );
        
        await Future.delayed(Duration(seconds: 2));
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
        return;
      }
    }
    
    await _loadUserData();

    if (mounted) {
      setState(() {
        _isValidating = false;
      });

      Fluttertoast.showToast(
        msg: 'Datos actualizados',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cerrar Sesión',
            style: TextStyle(color: Colors.red[800]),
          ),
          content: Text('¿Está seguro que desea cerrar sesión?'),
          actions: [
            TextButton(
              child: Text(
                'Cancelar', 
                style: TextStyle(color: Colors.grey[600])
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Cerrar Sesión', 
                style: TextStyle(color: Colors.red[700])
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToModule(String moduleName) {
    switch (moduleName) {
      case 'Bodega':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistBodegaScreen()),
        );
        break;
      default:
        Fluttertoast.showToast(
          msg: 'Módulo $moduleName - En desarrollo',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'KONTROLLERS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.red[700],
        elevation: 2,
        automaticallyImplyLeading: false,
        actions: [
          // Indicador de conexión
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  _hasConnection ? Icons.wifi : Icons.wifi_off,
                  color: _hasConnection ? Colors.white : Colors.red[300],
                  size: 20,
                ),
                SizedBox(width: 4),
                if (_isValidating || _isSyncing) ...[
                  SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  if (_isSyncing) ...[
                    SizedBox(width: 4),
                    Text(
                      'Sync',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          
          // Menú popup
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            color: Colors.white,
            onSelected: (String value) {
              switch (value) {
                case 'sync':
                  _manualSync();
                  break;
                case 'refresh':
                  _refreshData();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'sync',
                enabled: !_isSyncing,
                child: Row(
                  children: [
                    _isSyncing 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red[700],
                            ),
                          )
                        : Icon(Icons.sync, color: Colors.red[700], size: 20),
                    SizedBox(width: 12),
                    Text(
                      _isSyncing ? 'Sincronizando...' : 'Sincronizar',
                      style: TextStyle(
                        color: _isSyncing ? Colors.grey[500] : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.red[700], size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Actualizar',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red[700], size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del usuario
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Colors.red[100]!,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bienvenido',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              currentUser?['nombre'] ?? 'Usuario',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Divider(color: Colors.red[100]),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        color: Colors.red[600],
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Usuario: ${currentUser?['username'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 32),
            
            // Título de módulos
            Row(
              children: [
                Icon(
                  Icons.dashboard_outlined,
                  color: Colors.red[800],
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'Módulos Disponibles',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Grid de botones de módulos
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _buildModuleButton(
                  title: 'Bodega',
                  icon: Icons.warehouse,
                  color: Colors.red[600]!,
                  onTap: () => _navigateToModule('Bodega'),
                ),
                _buildModuleButton(
                  title: 'Cosecha',
                  icon: Icons.grass,
                  color: Colors.red[700]!,
                  onTap: () => _navigateToModule('Cosecha'),
                ),
                _buildModuleButton(
                  title: 'Aplicaciones',
                  icon: Icons.spa_outlined,
                  color: Colors.red[800]!,
                  onTap: () => _navigateToModule('Aplicaciones'),
                ),
                _buildModuleButton(
                  title: 'Fertirriego',
                  icon: Icons.water_drop,
                  color: Colors.red[500]!,
                  onTap: () => _navigateToModule('Fertirriego'),
                ),
              ],
            ),
            
            SizedBox(height: 32),
            
            // Estado de conexión y datos
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Colors.red[100]!,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.red[800],
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Estado del Sistema',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Estado de conexión
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _hasConnection ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hasConnection ? Colors.red[200]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasConnection ? Icons.cloud_done : Icons.cloud_off,
                          color: _hasConnection ? Colors.red[700] : Colors.grey[600],
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasConnection ? 'Conectado al servidor' : 'Trabajando offline',
                                style: TextStyle(
                                  color: _hasConnection ? Colors.red[700] : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                _hasConnection 
                                    ? 'Sincronización automática activa'
                                    : 'Usando datos locales almacenados',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Estado de datos locales
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red[200]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              color: Colors.red[600],
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Datos locales disponibles',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (_dbStats.isNotEmpty) ...[
                          Text(
                            'Datos disponibles offline:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem('Usuarios', _dbStats['usuarios'] ?? 0),
                              _buildStatItem('Supervisores', _dbStats['supervisores'] ?? 0),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem('Pesadores', _dbStats['pesadores'] ?? 0),
                              _buildStatItem('Fincas', _dbStats['fincas'] ?? 0),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'Base de datos SQLite inicializada',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _hasConnection 
                                ? 'Sincronizando datos...'
                                : 'Conecte a internet para sincronizar',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),

            // Botón de sincronización manual (alternativo al menú)
            if (_hasConnection)
              Container(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _manualSync,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: EdgeInsets.symmetric(vertical: 12),
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
                      : Icon(Icons.sync, size: 20),
                  label: Text(
                    _isSyncing ? 'SINCRONIZANDO DATOS...' : 'SINCRONIZAR DATOS MANUALMENTE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            SizedBox(height: _hasConnection ? 20 : 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Text(
      '$label: $count',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildModuleButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: color,
                ),
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Container(
                height: 3,
                width: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}