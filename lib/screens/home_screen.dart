import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kontrollers_v2/screens/checklist_aplicaciones_screen.dart' as checklist;
import 'package:kontrollers_v2/screens/checklist_fertirriego_screen.dart';
import '../services/auth_service.dart';
import '../services/dropdown_service.dart';
import '../services/cosecha_dropdown_service.dart';
import '../database/database_helper.dart';
import 'login_screen.dart';
import 'checklist_bodega_screen.dart';
import 'checklist_cosecha_screen.dart';
import '../services/aplicaciones_dropdown_service.dart';
import 'checklist_cortes_screen.dart';
import '../services/checklist_cortes_storage_service.dart';
import 'checklist_labores_permanentes_screen.dart';
import '../services/checklist_labores_permanentes_storage_service.dart';
import 'checklist_labores_temporales_screen.dart';
import '../services/checklist_labores_temporales_storage_service.dart';
import 'admin_screen.dart';
import 'observaciones_adicionales_screen.dart';
import 'observaciones_adicionales_records_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? currentUser;
  bool _hasConnection = false;
  bool _isValidating = false;
  bool _isSyncing = false;
  
  // Estadísticas de base de datos
  Map<String, int> _dbStats = {};
  Map<String, int> _cosechaDbStats = {};
  Map<String, int> _aplicacionesDbStats = {};
  Map<String, dynamic> _cortesDbStats = {};
  Map<String, dynamic> _laboresPermanentesDbStats = {};
  Map<String, dynamic> _laboresTemporalesDbStats = {};
  
  // Animaciones
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;


  @override
  void initState() {
    super.initState();
    
    // Inicializar animaciones
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _initializeApp();
    
    // Iniciar animación
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Método de inicialización optimizado
  Future<void> _initializeApp() async {
    await _loadUserData();
    await _checkConnection();
    await _loadDatabaseStats();
    
    // Validar cada 30 segundos mientras la pantalla esté activa
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _validateUserQuietly();
      } else {
        timer.cancel();
      }
    });
  }


  // Método de sincronización general optimizado
  Future<void> _performGeneralSync() async {
    print('=== INICIANDO SINCRONIZACIÓN GENERAL ===');
    
    if (!await AuthService.hasInternetConnection()) {
      Fluttertoast.showToast(
        msg: 'Sin conexión a internet. Verifique su conectividad.',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      Fluttertoast.showToast(
        msg: 'Iniciando sincronización completa...',
        backgroundColor: Colors.blue[600],
        textColor: Colors.white,
      );

      int totalSynced = 0;
      List<String> errors = [];

      // 1. Sincronizar datos de bodega
      print('Sincronizando datos de bodega...');
      try {
        Map<String, dynamic> bodegaResult = await DropdownService.syncDropdownData();
        print('Resultado bodega: $bodegaResult');
        if (bodegaResult['success']) {
          totalSynced += (bodegaResult['count'] as num?)?.toInt() ?? 0;
          print('Bodega sincronizada: ${bodegaResult['count']} registros');
        } else {
          errors.add('Bodega: ${bodegaResult['message']}');
          print('Error en bodega: ${bodegaResult['message']}');
        }
      } catch (e) {
        errors.add('Bodega: $e');
        print('Excepción en bodega: $e');
      }

      // 2. Sincronizar datos de cosecha
      print('Sincronizando datos de cosecha...');
      try {
        Map<String, dynamic> cosechaResult = await CosechaDropdownService.getCosechaDropdownData(forceSync: true);
        print('Resultado cosecha: $cosechaResult');
        if (cosechaResult['success']) {
          print('Sincronizando bloques de cosecha...');
          await CosechaDropdownService.syncAllBloquesCosecha();
          print('Sincronizando variedades de cosecha...');
          await CosechaDropdownService.syncVariedadesIntelligent();
          totalSynced += (cosechaResult['fincas'] as List?)?.length ?? 0;
          print('Cosecha sincronizada: ${(cosechaResult['fincas'] as List?)?.length ?? 0} fincas');
        } else {
          errors.add('Cosecha: Error en sincronización');
          print('Error en cosecha: ${cosechaResult['message']}');
        }
      } catch (e) {
        errors.add('Cosecha: $e');
        print('Excepción en cosecha: $e');
      }

      // 3. Sincronizar datos de aplicaciones
      print('Sincronizando datos de aplicaciones...');
      try {
        Map<String, dynamic> aplicacionesResult = await AplicacionesDropdownService.getAplicacionesDropdownData(forceSync: true);
        print('Resultado aplicaciones: $aplicacionesResult');
        if (aplicacionesResult['success']) {
          print('Sincronizando datos de aplicaciones...');
          await AplicacionesDropdownService.syncAplicacionesData();
          totalSynced += (aplicacionesResult['fincas'] as List?)?.length ?? 0;
          print('Aplicaciones sincronizada: ${(aplicacionesResult['fincas'] as List?)?.length ?? 0} fincas');
        } else {
          errors.add('Aplicaciones: Error en sincronización');
          print('Error en aplicaciones: ${aplicacionesResult['message']}');
        }
      } catch (e) {
        errors.add('Aplicaciones: $e');
        print('Excepción en aplicaciones: $e');
      }

      // 4. Recargar estadísticas
      print('Recargando estadísticas después de sincronización...');
      await _loadDatabaseStats();
      
      // 5. Mostrar resultado
      print('Total sincronizado: $totalSynced elementos');
      print('Errores: ${errors.length}');
      
      if (errors.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Sincronización completada: $totalSynced elementos',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: 'Sincronización parcial. Errores: ${errors.length}',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      }

    } catch (e) {
      print('Error general en sincronización: $e');
      Fluttertoast.showToast(
        msg: 'Error en sincronización: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
      print('=== FIN SINCRONIZACIÓN GENERAL ===');
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

  Future<void> _loadDatabaseStats() async {
    try {
      print('=== CARGANDO ESTADÍSTICAS DE BASE DE DATOS ===');
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Cargar todas las estadísticas en paralelo
      final results = await Future.wait([
        dbHelper.getDatabaseStats(),
        dbHelper.getCosechaDatabaseStats(),
        dbHelper.getAplicacionesDatabaseStats(),
        ChecklistCortesStorageService.getStatistics(),
        ChecklistLaboresPermanentesStorageService.getStatistics(),
        ChecklistLaboresTemporalesStorageService.getStatistics(),
      ]);
      
      print('Resultados obtenidos:');
      print('Bodega: ${results[0]}');
      print('Cosecha: ${results[1]}');
      print('Aplicaciones: ${results[2]}');
      print('Cortes: ${results[3]}');
      print('Labores Permanentes: ${results[4]}');
      print('Labores Temporales: ${results[5]}');
      
      if(mounted) {
        setState(() {
          _dbStats = results[0] as Map<String, int>;
          _cosechaDbStats = results[1] as Map<String, int>;
          _aplicacionesDbStats = results[2] as Map<String, int>;
          _cortesDbStats = results[3] as Map<String, dynamic>;
          _laboresPermanentesDbStats = results[4] as Map<String, dynamic>;
          _laboresTemporalesDbStats = results[5] as Map<String, dynamic>;
        });
        
        print('Estado actualizado en UI:');
        print('_dbStats: $_dbStats');
        print('_cosechaDbStats: $_cosechaDbStats');
        print('_aplicacionesDbStats: $_aplicacionesDbStats');
      }
      
      print('=== ESTADÍSTICAS CARGADAS EXITOSAMENTE ===');
    } catch (e) {
      print('=== ERROR CARGANDO ESTADÍSTICAS ===');
      print('Error: $e');
      print('Stack trace: ${e.toString()}');
    }
  }

  Future<void> _validateUserQuietly() async {
    if (_isValidating) return;

    setState(() {
      _isValidating = true;
    });

    try {
      await AuthService.forceValidateActiveUser();
      await _checkConnection();
    } catch (e) {
      print('Error en validación de usuario: $e');
    }

    if (mounted) {
      setState(() {
        _isValidating = false;
      });
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '¿Cerrar sesión?',
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Se perderán todos los datos no sincronizados.',
            style: TextStyle(color: Colors.grey[800]),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancelar', 
                style: TextStyle(color: Colors.grey[600])
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Cerrar Sesión'),
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
      case 'Cosecha':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistCosechaScreen()),
        );
        break;
      case 'Aplicaciones':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => checklist.ChecklistAplicacionesScreen()),
        );
        break;
      case 'Fertirriego':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistFertiriegoScreen()),
        );
        break;
      case 'Cortes del Día':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistCortesScreen()),
        );
        break;
      case 'Labores Permanentes':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistLaboresPermanentesScreen()),
        );
        break;
      case 'Labores Temporales':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ChecklistLaboresTemporalesScreen()),
        );
        break;
      case 'Reportería':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminScreen()),
        );
        break;
      case 'Observaciones adicionales':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ObservacionesAdicionalesScreen()),
        );
        break;
      case 'Observaciones Registros':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ObservacionesAdicionalesRecordsScreen()),
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

  // Métodos de verificación de módulos activos
  bool _isBodegaModuleActive() {
    return (_dbStats['usuarios'] ?? 0) > 0 &&
           (_dbStats['supervisores'] ?? 0) > 0 &&
           (_dbStats['pesadores'] ?? 0) > 0 &&
           (_dbStats['fincas'] ?? 0) > 0;
  }

  bool _isCosechaModuleActive() {
    return (_cosechaDbStats['fincas'] ?? 0) > 0 &&
           (_cosechaDbStats['bloques'] ?? 0) > 0 &&
           (_cosechaDbStats['variedades'] ?? 0) > 0;
  }

  bool _isAplicacionesModuleActive() {
    return (_aplicacionesDbStats['fincas'] ?? 0) > 0 &&
           (_aplicacionesDbStats['bloques'] ?? 0) > 0 &&
           (_aplicacionesDbStats['bombas'] ?? 0) > 0;
  }

  bool _isCortesModuleActive() {
    return (_cortesDbStats['totalChecklists'] ?? 0) > 0 || _isCosechaModuleActive();
  }

  bool _isLaboresPermanentesModuleActive() {
    return (_laboresPermanentesDbStats['totalChecklists'] ?? 0) > 0 || _isCosechaModuleActive();
  }

  bool _isLaboresTemporalesModuleActive() {
    return (_laboresTemporalesDbStats['totalChecklists'] ?? 0) > 0 || _isCosechaModuleActive();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar optimizado para tablet
          SliverAppBar(
            expandedHeight: isTablet ? 280 : 160,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.red[700],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.red[800]!, Colors.red[600]!],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 40 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isTablet ? 20 : 10),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 20 : 12),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.agriculture,
                                color: Colors.white,
                                size: isTablet ? 40 : 24,
                              ),
                            ),
                            SizedBox(width: isTablet ? 24 : 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KONTROLLERS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isTablet ? 32 : 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'Sistema de Gestión Agrícola',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: isTablet ? 18 : 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _showLogoutDialog,
                              icon: Container(
                                padding: EdgeInsets.all(isTablet ? 12 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: isTablet ? 28 : 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 24 : 16),
                        // Estado de conexión
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 24 : 16, 
                            vertical: isTablet ? 12 : 8
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasConnection ? Icons.wifi : Icons.wifi_off,
                                color: _hasConnection ? Colors.green[400] : Colors.orange[400],
                                size: isTablet ? 24 : 16,
                              ),
                              SizedBox(width: isTablet ? 12 : 8),
                              Text(
                                _hasConnection ? 'Conectado' : 'Sin conexión',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 16 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contenido principal
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 40 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información del usuario
                      _buildUserInfo(isTablet),
                      
                      
                      
                      SizedBox(height: isTablet ? 32 : 24),
                      
                      // Módulos separados
                      _buildModulesSection(isTablet),
                      
                      SizedBox(height: isTablet ? 40 : 24),

                      // Contadores de datos
                      _buildDataCounters(isTablet),
                      SizedBox(height: isTablet ? 32 : 24),
                      
                      // Botón de sincronización general
                      _buildGeneralSyncButton(isTablet),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[600]!, Colors.red[700]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: isTablet ? 36 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 24 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 4),
                Text(
                  currentUser?['nombre'] ?? 'Usuario',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: isTablet ? 12 : 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 8, 
                    vertical: isTablet ? 8 : 4
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    '@${currentUser?['username'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 12,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Botón de sincronización general
  Widget _buildGeneralSyncButton(bool isTablet) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _performGeneralSync,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        icon: _isSyncing 
            ? SizedBox(
                width: isTablet ? 28 : 20,
                height: isTablet ? 28 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.sync, size: isTablet ? 28 : 20),
        label: Text(
          _isSyncing ? 'SINCRONIZANDO...' : 'SINCRONIZAR TODOS LOS DATOS',
          style: TextStyle(
            fontSize: isTablet ? 20 : 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Contadores de datos
  Widget _buildDataCounters(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contadores de Datos',
            style: TextStyle(
              fontSize: isTablet ? 24 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: isTablet ? 24 : 16),
          Wrap(
            spacing: isTablet ? 20 : 12,
            runSpacing: isTablet ? 20 : 12,
            children: [
              _buildCounterCard('Usuarios', _dbStats['usuarios'] ?? 0, Icons.people, Colors.blue, isTablet),
              _buildCounterCard('Fincas', _dbStats['fincas'] ?? 0, Icons.location_on, Colors.green, isTablet),
              _buildCounterCard('Bloques', _cosechaDbStats['bloques'] ?? 0, Icons.grid_view, Colors.orange, isTablet),
              _buildCounterCard('Variedades', _cosechaDbStats['variedades'] ?? 0, Icons.eco, Colors.purple, isTablet),
              _buildCounterCard('Bombas', _aplicacionesDbStats['bombas'] ?? 0, Icons.water_drop, Colors.cyan, isTablet),
              _buildCounterCard('Supervisores', _dbStats['supervisores'] ?? 0, Icons.supervisor_account, Colors.indigo, isTablet),
              _buildCounterCard('Pesadores', _dbStats['pesadores'] ?? 0, Icons.scale, Colors.brown, isTablet),
              //_buildCounterCard('Cortes', _cortesDbStats['totalChecklists'] ?? 0, Icons.content_cut, Colors.red, isTablet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(String title, int count, IconData icon, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16, 
        vertical: isTablet ? 20 : 12
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isTablet ? 32 : 20),
          SizedBox(width: isTablet ? 16 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: isTablet ? 28 : 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Módulos separados
  Widget _buildModulesSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Módulos del Sistema',
          style: TextStyle(
            fontSize: isTablet ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: isTablet ? 24 : 16),
        
        // Módulos principales
        _buildModuleCategory(
          'Módulos Principales',
          [
            _buildModuleCard('Bodega', Icons.warehouse, Colors.red[600]!, _isBodegaModuleActive(), isTablet),
            _buildModuleCard('Cosecha', Icons.grass, Colors.green[600]!, _isCosechaModuleActive(), isTablet),
            _buildModuleCard('Aplicaciones', Icons.spa, Colors.orange[600]!, _isAplicacionesModuleActive(), isTablet),
            _buildModuleCard('Fertirriego', Icons.water_drop, Colors.blue[600]!, true, isTablet),
          ],
          isTablet,
        ),
        
        SizedBox(height: isTablet ? 32 : 20),
        
        // Módulos de control separados
        _buildModuleCategory(
          'Control de Calidad',
          [
            _buildModuleCard('Cortes del Día', Icons.content_cut, Colors.purple[600]!, _isCortesModuleActive(), isTablet),
            _buildModuleCard('Labores Permanentes', Icons.agriculture, Colors.deepPurple[600]!, _isLaboresPermanentesModuleActive(), isTablet),
            _buildModuleCard('Labores Temporales', Icons.construction, Colors.amber[600]!, _isLaboresTemporalesModuleActive(), isTablet),
            
          ],
          isTablet,
        ),
        
        // Módulo de administración - siempre visible
        SizedBox(height: isTablet ? 32 : 20),
        _buildModuleCategory(
          'Observaciones adicionales',
          [
            _buildModuleCard('Observaciones adicionales', Icons.note_add_outlined, Colors.teal[600]!, true, isTablet),
          ],
          isTablet,
        ),
        SizedBox(height: isTablet ? 32 : 20),
        _buildModuleCategory(
          'Reportería',
          [
            _buildModuleCard('Reportería', Icons.document_scanner, Colors.red[700]!, true, isTablet),
            //_buildModuleCard('Observaciones Registros', Icons.library_books_outlined, Colors.teal[700]!, true, isTablet),
          ],
          isTablet,
        ),
      ],
    );
  }

  Widget _buildModuleCategory(String title, List<Widget> modules, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 20 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: isTablet ? 20 : 12),
        Wrap(
          spacing: isTablet ? 20 : 12,
          runSpacing: isTablet ? 20 : 12,
          children: modules,
        ),
      ],
    );
  }

  Widget _buildModuleCard(String title, IconData icon, Color color, bool isActive, bool isTablet) {
    return InkWell(
      onTap: isActive ? () => _navigateToModule(title) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: isTablet ? 200 : 150,
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color.withOpacity(0.3) : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ] : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? color : Colors.grey[400],
              size: isTablet ? 56 : 32,
            ),
            SizedBox(height: isTablet ? 16 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isTablet ? 18 : 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.grey[800] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (!isActive) ...[
              SizedBox(height: isTablet ? 8 : 4),
              Text(
                'Datos incompletos',
                style: TextStyle(
                  fontSize: isTablet ? 14 : 10,
                  color: Colors.orange[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}