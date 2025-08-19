import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:kontrollers_v2/screens/checklist_aplicaciones_screen.dart' as checklist;
import 'package:kontrollers_v2/screens/checklist_fertirriego_screen.dart';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';
import '../services/auth_service.dart';
import '../services/dropdown_service.dart';
import '../services/cosecha_dropdown_service.dart';
import '../database/database_helper.dart';
import 'login_screen.dart';
import 'checklist_bodega_screen.dart';
import 'checklist_cosecha_screen.dart';
import '../services/aplicaciones_dropdown_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? currentUser;
  bool _hasConnection = false;
  bool _isValidating = false;
  bool _isSyncing = false;
  
  // Variables de sincronización individual
  bool _isSyncingBodega = false;
  bool _isSyncingCosecha = false;
  bool _isSyncingAplicaciones = false;
  
  Map<String, int> _dbStats = {};
  Map<String, int> _cosechaDbStats = {};
  Map<String, dynamic> _validationInfo = {};
  Map<String, int> _aplicacionesDbStats = {};
  
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
    
    _loadUserData();
    _checkConnection();
    _loadDatabaseStats();
    _loadValidationInfo();
    _validateUserPeriodically();
    _autoSyncOnLoad();
    
    // Iniciar animación
    _animationController.forward();
    
    // Validar cada 30 segundos mientras la pantalla esté activa
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _validateUserQuietly();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _autoSyncOnLoad() async {
    if (await AuthService.hasInternetConnection()) {
      setState(() {
        _isSyncing = true;
      });

      try {
        print('Iniciando sincronización automática en home screen...');
        Map<String, dynamic> syncResult = await IntelligentSyncService.performIntelligentSync();

        if (syncResult['sync_status'] == 'success') {
          print('Sincronización exitosa: ${syncResult['synced_items']} elementos');
        } else {
          print('Sincronización con problemas: ${syncResult['message']}');
        }
      } catch (e) {
        print('Error en sincronización automática: $e');
      }

      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        // Recargar estadísticas después de la sincronización automática
        await _loadDatabaseStats();
      }
    }
  }

  // Método mejorado de sincronización manual que incluye todos los módulos - CORREGIDO
  Future<void> _manualSyncImproved() async {
    print('=== INICIO DIAGNÓSTICO DE SINCRONIZACIÓN ===');
    
    // 1. Verificar conexión
    bool hasConnection = await AuthService.hasInternetConnection();
    print('Estado de conexión: $hasConnection');
    
    if (!hasConnection) {
      Fluttertoast.showToast(
        msg: 'Sin conexión a internet. Revise su conectividad.',
        toastLength: Toast.LENGTH_LONG,
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
      print('=== INICIANDO SINCRONIZACIÓN MANUAL COMPLETA ===');
      
      // Mostrar progreso al usuario
      Fluttertoast.showToast(
        msg: 'Iniciando sincronización completa...',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.blue[600],
        textColor: Colors.white,
      );

      int totalSyncedItems = 0;
      List<String> syncErrors = [];
      List<String> successMessages = [];

      // 1. SINCRONIZAR DATOS DE BODEGA PRIMERO
      print('Sincronizando datos de bodega...');
      try {
        Fluttertoast.showToast(
          msg: 'Sincronizando bodega: supervisores, pesadores, fincas...',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.purple[600],
          textColor: Colors.white,
        );

        Map<String, dynamic> bodegaResult = await DropdownService.syncDropdownData();
        print('Resultado sincronización bodega: $bodegaResult');
        
        if (bodegaResult['success']) {
          int bodegaCount = (bodegaResult['count'] as num?)?.toInt() ?? 0;
          totalSyncedItems += bodegaCount;
          successMessages.add('Bodega: $bodegaCount registros');
        } else {
          syncErrors.add('Error en datos de bodega: ${bodegaResult['message']}');
        }
      } catch (e) {
        print('Error sincronizando bodega: $e');
        syncErrors.add('Error bodega: $e');
      }

      // 2. Usar IntelligentSyncService para sincronización robusta
      print('Ejecutando sincronización inteligente...');
      try {
        Map<String, dynamic> intelligentResult = await IntelligentSyncService.performIntelligentSync();
        print('Resultado sincronización inteligente: $intelligentResult');
        
        if (intelligentResult['sync_status'] == 'success' || intelligentResult['sync_status'] == 'partial') {
          totalSyncedItems += (intelligentResult['synced_items'] as num?)?.toInt() ?? 0;
          successMessages.add('Datos principales: ${intelligentResult['synced_items']} registros');
        } else {
          syncErrors.add('Sincronización inteligente falló');
        }
      } catch (e) {
        print('Error en sincronización inteligente: $e');
        syncErrors.add('Error sincronización principal: $e');
      }

      // 3. Sincronizar datos de cosecha específicamente CON VARIEDADES COMPLETAS
      print('Sincronizando datos de cosecha CON TODAS LAS VARIEDADES...');
      try {
        // Mostrar progreso para cosecha
        Fluttertoast.showToast(
          msg: 'Sincronizando cosecha: fincas y bloques...',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );

        Map<String, dynamic> cosechaResult = await CosechaDropdownService.getCosechaDropdownData(forceSync: true);
        print('Resultado sincronización cosecha: $cosechaResult');
        
        if (cosechaResult['success']) {
          int cosechaFincas = (cosechaResult['fincas'] as List?)?.length ?? 0;
          totalSyncedItems += cosechaFincas;
          successMessages.add('Cosecha: $cosechaFincas fincas');
          
          // Sincronizar todos los bloques de cosecha
          print('Sincronizando TODOS los bloques de cosecha...');
          await CosechaDropdownService.syncAllBloquesCosecha();
          successMessages.add('Bloques cosecha sincronizados');

          // Sincronizar TODAS las variedades para TODOS los bloques de cosecha
          print('Sincronizando TODAS las variedades de cosecha...');
          
          Fluttertoast.showToast(
            msg: 'Sincronizando variedades de cosecha...',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green[700],
            textColor: Colors.white,
          );

          await CosechaDropdownService.syncVariedadesIntelligent();
          successMessages.add('Variedades cosecha sincronizadas');
          
        } else {
          syncErrors.add('Error en datos de cosecha');
        }
      } catch (e) {
        print('Error sincronizando cosecha: $e');
        syncErrors.add('Error cosecha: $e');
      }

      // 4. Sincronizar datos de aplicaciones específicamente
      print('Sincronizando datos de aplicaciones...');
      try {
        Fluttertoast.showToast(
          msg: 'Sincronizando aplicaciones...',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.blue[700],
          textColor: Colors.white,
        );

        Map<String, dynamic> aplicacionesResult = await AplicacionesDropdownService.getAplicacionesDropdownData(forceSync: true);
        print('Resultado sincronización aplicaciones: $aplicacionesResult');
        
        if (aplicacionesResult['success']) {
          int aplicacionesFincas = (aplicacionesResult['fincas'] as List?)?.length ?? 0;
          totalSyncedItems += aplicacionesFincas;
          successMessages.add('Aplicaciones: $aplicacionesFincas fincas');
        } else {
          syncErrors.add('Error en datos de aplicaciones');
        }
      } catch (e) {
        print('Error sincronizando aplicaciones: $e');
        syncErrors.add('Error aplicaciones: $e');
      }

      // 5. Sincronizar datos específicos de aplicaciones desde tabla optimizada
      print('Sincronizando tabla aplicaciones_data...');
      try {
        Map<String, dynamic> aplicacionesDataResult = await AplicacionesDropdownService.syncAplicacionesData();
        print('Resultado sincronización aplicaciones_data: $aplicacionesDataResult');
        
        if (aplicacionesDataResult['success']) {
          successMessages.add('Datos aplicaciones optimizados: sincronizados');
        } else {
          syncErrors.add('Error tabla aplicaciones_data');
        }
      } catch (e) {
        print('Error sincronizando aplicaciones_data: $e');
        syncErrors.add('Error aplicaciones_data: $e');
      }

      // 6. Actualizar estadísticas locales
      await _loadDatabaseStats();
      
      // 7. Verificar resultados y mostrar mensaje apropiado
      bool hasErrors = syncErrors.isNotEmpty;
      bool hasSomeSuccess = successMessages.isNotEmpty;
      
      if (!hasErrors && hasSomeSuccess) {
        Fluttertoast.showToast(
          msg: 'Sincronización completada: ${successMessages.join(', ')}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
        
        print('=== SINCRONIZACIÓN EXITOSA ===');
        print('Total sincronizado: $totalSyncedItems elementos');
        print('Detalles: ${successMessages.join(', ')}');
      } else if (hasSomeSuccess && hasErrors) {
        Fluttertoast.showToast(
          msg: 'Sincronización parcial. Éxitos: ${successMessages.length}, Errores: ${syncErrors.length}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
        
        print('=== SINCRONIZACIÓN PARCIAL ===');
        print('Éxitos: ${successMessages.join(', ')}');
        print('Errores: ${syncErrors.join(', ')}');
      } else {
        Fluttertoast.showToast(
          msg: 'Error en sincronización: ${syncErrors.join(', ')}',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
        
        print('=== ERRORES EN SINCRONIZACIÓN ===');
        print('Errores: ${syncErrors.join(', ')}');
      }

    } catch (e) {
      print('=== ERROR CRÍTICO EN SINCRONIZACIÓN ===');
      print('Error: $e');
      print('Stack trace: ${e.toString()}');
      
      Fluttertoast.showToast(
        msg: 'Error crítico en sincronización: ${e.toString()}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red[700],
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
      print('=== FIN PROCESO SINCRONIZACIÓN ===');
    }
  }

  // Método de diagnóstico para debugging
  Future<void> _diagnosticSync() async {
    print('=== DIAGNÓSTICO DEL SISTEMA ===');
    
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Verificar estadísticas de todas las bases de datos
      Map<String, int> generalStats = await dbHelper.getDatabaseStats();
      Map<String, int> cosechaStats = await dbHelper.getCosechaDatabaseStats();
      Map<String, int> aplicacionesStats = await dbHelper.getAplicacionesDatabaseStats();
      
      print('Estadísticas generales: $generalStats');
      print('Estadísticas cosecha: $cosechaStats');
      print('Estadísticas aplicaciones: $aplicacionesStats');
      
      // Verificar conectividad
      bool hasInternet = await AuthService.hasInternetConnection();
      print('Conexión a internet: $hasInternet');
      
      // Verificar autenticación
      bool isLoggedIn = await AuthService.isLoggedIn();
      print('Usuario autenticado: $isLoggedIn');
      
      // Verificar estado del servidor con health check
      if (hasInternet) {
        Map<String, dynamic> healthCheck = await RobustSqlServerService.performHealthCheck();
        print('Health check del servidor: $healthCheck');
      }
      
    } catch (e) {
      print('Error en diagnóstico: $e');
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
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Cargar estadísticas de bodega
      Map<String, int> stats = await dbHelper.getDatabaseStats();
      
      // Cargar estadísticas de cosecha
      Map<String, int> cosechaStats = await dbHelper.getCosechaDatabaseStats();
      
      // Cargar estadísticas de aplicaciones
      Map<String, int> aplicacionesStats = await dbHelper.getAplicacionesDatabaseStats();
      
      if(mounted) {
        setState(() {
          _dbStats = stats;
          _cosechaDbStats = cosechaStats;
          _aplicacionesDbStats = aplicacionesStats;
        });
      }
      
      print('Estadísticas cargadas - General: $stats, Cosecha: $cosechaStats, Aplicaciones: $aplicacionesStats');
    } catch (e) {
      print('Error cargando estadísticas de base de datos: $e');
    }
  }

  Future<void> _loadValidationInfo() async {
    try {
      Map<String, dynamic> info = await AuthService.getValidationInfo();
      setState(() {
        _validationInfo = info;
      });
    } catch (e) {
      print('Error cargando información de validación: $e');
    }
  }

  Future<void> _validateUserPeriodically() async {
    // Validación inicial
    if (await AuthService.needsServerValidation()) {
      await _validateUserQuietly();
    }
  }

  Future<void> _validateUserQuietly() async {
    if (_isValidating) return;

    setState(() {
      _isValidating = true;
    });

    try {
      await AuthService.forceValidateActiveUser();
      await _loadValidationInfo();
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

  // Método mejorado para construir la información de la base de datos
  Widget _buildDatabaseInfo(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 20,
        vertical: isTablet ? 24 : 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header principal
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[700]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: Colors.white,
                  size: isTablet ? 28 : 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base de Datos Local',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 22 : 18,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Datos almacenados offline',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 32 : 24),
          
          if (!_hasDataInBodega() && !_hasDataInCosecha() && !_hasDataInAplicaciones())
            _buildEmptyState(isTablet)
          else ...[
            // Si hay datos en al menos un módulo, se muestran todos
            _buildModuleSection(
              title: 'MÓDULO BODEGA',
              icon: Icons.warehouse_rounded,
              color: Colors.purple,
              isTablet: isTablet,
              items: [
                _buildDataItem('Usuarios', _dbStats['usuarios'] ?? 0, Icons.people_rounded),
                _buildDataItem('Supervisores', _dbStats['supervisores'] ?? 0, Icons.supervisor_account_rounded),
                _buildDataItem('Pesadores', _dbStats['pesadores'] ?? 0, Icons.scale_rounded),
                _buildDataItem('Fincas', _dbStats['fincas'] ?? 0, Icons.location_on_rounded),
              ],
              isSyncing: _isSyncingBodega,
              onSync: () => _syncBodegaData(),
              isEnabled: _hasDataInBodega(),
            ),
            
            SizedBox(height: isTablet ? 24 : 20),
            
            _buildModuleSection(
              title: 'MÓDULO COSECHA Y FERTIRRIEGO',
              icon: Icons.grass_rounded,
              color: Colors.green,
              isTablet: isTablet,
              items: [
                _buildDataItem('Fincas', _cosechaDbStats['fincas'] ?? 0, Icons.location_on_rounded),
                _buildDataItem('Bloques', _cosechaDbStats['bloques'] ?? 0, Icons.grid_view_rounded),
                _buildDataItem('Variedades', _cosechaDbStats['variedades'] ?? 0, Icons.eco_rounded),
              ],
              isSyncing: _isSyncingCosecha,
              onSync: () => _syncCosechaData(),
              isEnabled: _hasDataInCosecha(),
            ),
            
            SizedBox(height: isTablet ? 24 : 20),
            
            _buildModuleSection(
              title: 'MÓDULO APLICACIONES',
              icon: Icons.spa_rounded,
              color: Colors.orange,
              isTablet: isTablet,
              items: [
                _buildDataItem('Fincas', _aplicacionesDbStats['fincas'] ?? 0, Icons.location_on_rounded),
                _buildDataItem('Bloques', _aplicacionesDbStats['bloques'] ?? 0, Icons.grid_view_rounded),
                _buildDataItem('Bombas', _aplicacionesDbStats['bombas'] ?? 0, Icons.water_drop_rounded),
              ],
              isSyncing: _isSyncingAplicaciones,
              onSync: () => _syncAplicacionesData(),
              isEnabled: _hasDataInAplicaciones(),
            ),
          ],
          
          SizedBox(height: isTablet ? 32 : 24),
          
          // Botón de sincronización general mejorado
          _buildGeneralSyncButton(isTablet),
        ],
      ),
    );
  }

  // Métodos para verificar si hay datos en cada módulo (SUMA > 0)
  bool _hasDataInBodega() {
    int totalBodega = (_dbStats['usuarios'] ?? 0) + 
                     (_dbStats['supervisores'] ?? 0) + 
                     (_dbStats['pesadores'] ?? 0) + 
                     (_dbStats['fincas'] ?? 0);
    return totalBodega > 0;
  }

  bool _hasDataInCosecha() {
    int totalCosecha = (_cosechaDbStats['fincas'] ?? 0) + 
                      (_cosechaDbStats['bloques'] ?? 0) + 
                      (_cosechaDbStats['variedades'] ?? 0);
    return totalCosecha > 0;
  }

  bool _hasDataInAplicaciones() {
    int totalAplicaciones = (_aplicacionesDbStats['fincas'] ?? 0) + 
                           (_aplicacionesDbStats['bloques'] ?? 0) + 
                           (_aplicacionesDbStats['bombas'] ?? 0);
    return totalAplicaciones > 0;
  }
  
  // ** INICIO DE NUEVAS FUNCIONES **
  // Métodos para verificar si un módulo está listo (CADA CONTADOR > 0)
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
  // ** FIN DE NUEVAS FUNCIONES **

  // Widget para cada sección de módulo (actualizado)
  Widget _buildModuleSection({
    required String title,
    required IconData icon,
    required Color color,
    required bool isTablet,
    required List<Widget> items,
    required bool isSyncing,
    required VoidCallback onSync,
    required bool isEnabled,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: isEnabled ? color.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled ? color.withOpacity(0.2) : Colors.grey[300]!,
          width: isEnabled ? 1 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección
          Row(
            children: [
              // Icono con estado visual
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: isEnabled ? color.withOpacity(0.15) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey[500],
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 16 : 14,
                        color: isEnabled ? color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    // Indicador de estado
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 8 : 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isEnabled ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEnabled ? Colors.green[200]! : Colors.orange[200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEnabled ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            color: isEnabled ? Colors.green[600] : Colors.orange[600],
                            size: isTablet ? 12 : 10,
                          ),
                          SizedBox(width: 4),
                          Text(
                            isEnabled ? 'Con datos' : 'Sin datos',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 9,
                              color: isEnabled ? Colors.green[700] : Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Botón de sincronización individual
              Container(
                height: isTablet ? 36 : 32,
                child: ElevatedButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled ? color: Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: isTablet ? 8 : 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: isEnabled ? 2 : 1,
                  ),
                  icon: isSyncing 
                      ? SizedBox(
                          width: isTablet ? 16 : 14,
                          height: isTablet ? 16 : 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.sync_rounded,
                          size: isTablet ? 16 : 14,
                        ),
                  label: Text(
                    'Sync',
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isTablet ? 16 : 12),
          
          // Items de datos con estado visual
          AnimatedOpacity(
            duration: Duration(milliseconds: 300),
            opacity: isEnabled ? 1.0 : 0.6,
            child: Wrap(
              spacing: isTablet ? 12 : 8,
              runSpacing: isTablet ? 12 : 8,
              children: items,
            ),
          ),
          
          // Mensaje de estado cuando no hay datos
          if (!isEnabled) ...[
            SizedBox(height: isTablet ? 16 : 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[600],
                    size: isTablet ? 20 : 18,
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Expanded(
                    child: Text(
                      'Este módulo no tiene datos. Ejecute sincronización para cargar información.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: isTablet ? 13 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Widget para cada item de datos
  Widget _buildDataItem(String label, int count, IconData icon) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.grey[600],
            size: isTablet ? 18 : 16,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: isTablet ? 13 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 8 : 6,
              vertical: isTablet ? 4 : 3,
            ),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: count > 0 ? Colors.blue[700] : Colors.grey[500],
                fontSize: isTablet ? 12 : 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para estado vacío
  Widget _buildEmptyState(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cloud_download_rounded,
              color: Colors.grey[400],
              size: isTablet ? 48 : 40,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            'Base de datos inicializada',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            _hasConnection 
                ? 'Ejecute sincronización para cargar datos'
                : 'Conecte a internet para sincronizar',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isTablet ? 14 : 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Botón de sincronización general mejorado
  Widget _buildGeneralSyncButton(bool isTablet) {
    bool isAnySyncing = _isSyncing || _isSyncingBodega || _isSyncingCosecha || _isSyncingAplicaciones;
    
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isAnySyncing ? null : _manualSyncImproved,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 18 : 16,
            horizontal: isTablet ? 24 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: Colors.red.withOpacity(0.3),
        ),
        icon: _isSyncing 
            ? SizedBox(
                width: isTablet ? 24 : 20,
                height: isTablet ? 24 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.sync_rounded,
                size: isTablet ? 24 : 20,
              ),
        label: Text(
          _isSyncing ? 'SINCRONIZANDO TODOS LOS MÓDULOS...' : 'SINCRONIZAR TODOS LOS MÓDULOS',
          style: TextStyle(
            fontSize: isTablet ? 15 : 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // Métodos de sincronización individual - CORREGIDO
  Future<void> _syncBodegaData() async {
    if (!await AuthService.hasInternetConnection()) {
      _showNoConnectionMessage();
      return;
    }

    setState(() {
      _isSyncingBodega = true;
    });

    try {
      Fluttertoast.showToast(
        msg: 'Sincronizando datos de bodega...',
        backgroundColor: Colors.purple[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );

      // CORRECCIÓN: Llamar al método real de sincronización del DropdownService
      Map<String, dynamic> syncResult = await DropdownService.syncDropdownData();
      
      if (syncResult['success']) {
        await _loadDatabaseStats(); // Recargar estadísticas
        
        Fluttertoast.showToast(
          msg: 'Datos de bodega sincronizados exitosamente: ${syncResult['count']} registros',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_SHORT,
        );
        
        print('Sincronización bodega exitosa: ${syncResult['message']}');
      } else {
        Fluttertoast.showToast(
          msg: 'Error sincronizando bodega: ${syncResult['message']}',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        
        print('Error en sincronización bodega: ${syncResult['message']}');
      }

    } catch (e) {
      print('Error sincronizando bodega: $e');
      Fluttertoast.showToast(
        msg: 'Error sincronizando bodega: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingBodega = false;
        });
      }
    }
  }

  Future<void> _syncCosechaData() async {
    if (!await AuthService.hasInternetConnection()) {
      _showNoConnectionMessage();
      return;
    }

    setState(() {
      _isSyncingCosecha = true;
    });

    try {
      Fluttertoast.showToast(
        msg: 'Sincronizando datos de cosecha...',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );

      // Sincronizar todos los datos de cosecha
      Map<String, dynamic> cosechaResult = await CosechaDropdownService.getCosechaDropdownData(forceSync: true);
      
      if (cosechaResult['success']) {
        await CosechaDropdownService.syncAllBloquesCosecha();
        await CosechaDropdownService.syncVariedadesIntelligent();
      }
      
      await _loadDatabaseStats();
      
      Fluttertoast.showToast(
        msg: 'Datos de cosecha sincronizados exitosamente',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );

    } catch (e) {
      print('Error sincronizando cosecha: $e');
      Fluttertoast.showToast(
        msg: 'Error sincronizando cosecha: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingCosecha = false;
        });
      }
    }
  }

  Future<void> _syncAplicacionesData() async {
    if (!await AuthService.hasInternetConnection()) {
      _showNoConnectionMessage();
      return;
    }

    setState(() {
      _isSyncingAplicaciones = true;
    });

    try {
      Fluttertoast.showToast(
        msg: 'Sincronizando datos de aplicaciones...',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );

      // Sincronizar datos de aplicaciones
      Map<String, dynamic> aplicacionesResult = await AplicacionesDropdownService.getAplicacionesDropdownData(forceSync: true);
      
      if (aplicacionesResult['success']) {
        await AplicacionesDropdownService.syncAplicacionesData();
      }
      
      await _loadDatabaseStats();
      
      Fluttertoast.showToast(
        msg: 'Datos de aplicaciones sincronizados exitosamente',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
      );

    } catch (e) {
      print('Error sincronizando aplicaciones: $e');
      Fluttertoast.showToast(
        msg: 'Error sincronizando aplicaciones: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingAplicaciones = false;
        });
      }
    }
  }

  void _showNoConnectionMessage() {
    Fluttertoast.showToast(
      msg: 'Sin conexión a internet. Verifique su conectividad.',
      backgroundColor: Colors.orange[600],
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isTablet ? 4 : 2;
    final padding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar moderno con gradiente
          SliverAppBar(
            expandedHeight: isTablet ? 280 : 240,
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
                    colors: [
                      Colors.red[800]!,
                      Colors.red[600]!,
                      Colors.red[700]!,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isTablet ? 40 : 30),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTablet ? 16 : 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.agriculture,
                                color: Colors.white,
                                size: isTablet ? 32 : 28,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KONTROLLERS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isTablet ? 28 : 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Sistema de Gestión Agrícola',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: isTablet ? 16 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _showLogoutDialog,
                              icon: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: isTablet ? 24 : 20,
                                ),
                              ),
                              tooltip: 'Cerrar sesión',
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 32 : 24),
                        // Estado de conexión y sincronización
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              if (_isSyncing) ...[
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              ] else ...[
                                Icon(
                                  _hasConnection ? Icons.wifi : Icons.wifi_off,
                                  color: _hasConnection ? Colors.green[400] : Colors.orange[400],
                                  size: 20,
                                ),
                              ],
                              SizedBox(width: 12),
                              Text(
                                _isSyncing 
                                    ? 'Sincronizando...' 
                                    : (_hasConnection ? 'Conectado' : 'Sin conexión'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 14 : 12,
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
            actions: [
              // IconButton(
              //   onPressed: () => _manualSyncImproved(),
              //   icon: Container(
              //     padding: EdgeInsets.all(8),
              //     decoration: BoxDecoration(
              //       color: Colors.white.withOpacity(0.2),
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: _isSyncing 
              //         ? SizedBox(
              //             width: 20,
              //             height: 20,
              //             child: CircularProgressIndicator(
              //               strokeWidth: 2,
              //               color: Colors.white,
              //             ),
              //           )
              //         : Icon(Icons.sync, color: Colors.white, size: 20),
              //   ),
              //   tooltip: 'Sincronizar datos',
              // ),
              SizedBox(width: 8),
            ],
          ),

          // Contenido principal
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información del usuario
                      _buildUserInfo(isTablet),
                      
                      SizedBox(height: isTablet ? 40 : 32),
                      
                      // Grid de módulos
                      _buildModulesGrid(crossAxisCount, isTablet),

                      SizedBox(height: isTablet ? 32 : 24),
                      
                      // Información de la base de datos (ahora incluye botones de sync)
                      _buildDatabaseInfo(isTablet),
                      
                      SizedBox(height: isTablet ? 32 : 24),
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
      padding: EdgeInsets.all(isTablet ? 28 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.red[100]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[600]!, Colors.red[700]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: isTablet ? 32 : 28,
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  currentUser?['nombre'] ?? 'Usuario',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        color: Colors.red[600],
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '@${currentUser?['username'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Mostrar información de validación si hay datos
                if (_validationInfo.isNotEmpty && _validationInfo['hasBeenValidated'] == true) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: _getValidationStatusColor(),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Última validación: ${_getValidationText()}',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ** WIDGET MODIFICADO **
  Widget _buildModulesGrid(int crossAxisCount, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final isLandscape = screenWidth > screenHeight;
    final isTabletPortrait = isTablet && !isLandscape;
    
    int adaptiveCrossAxisCount;
    if (isTablet) {
      adaptiveCrossAxisCount = isLandscape ? 4 : 3;
    } else {
      adaptiveCrossAxisCount = 2;
    }
    
    double aspectRatio;
    if (isTabletPortrait) {
      aspectRatio = 0.85;
    } else if (isTablet && isLandscape) {
      aspectRatio = 1.1;
    } else {
      aspectRatio = 1.0;
    }

    final modules = [
      {
        'title': 'Bodega',
        'icon': Icons.warehouse,
        'color': Colors.red[600]!,
        'description': 'Gestión de inventario\ny almacén',
        'active': _isBodegaModuleActive(), // Llama a la nueva función de validación
        'isComingSoon': false,
      },
      {
        'title': 'Cosecha',
        'icon': Icons.grass,
        'color': Colors.red[700]!,
        'description': 'Control de\ncosecha',
        'active': _isCosechaModuleActive(), // Llama a la nueva función de validación
        'isComingSoon': false,
      },
      {
        'title': 'Aplicaciones',
        'icon': Icons.spa_outlined,
        'color': Colors.red[800]!,
        'description': 'Aplicaciones\nfitosanitarias',
        'active': _isAplicacionesModuleActive(), // Llama a la nueva función de validación
        'isComingSoon': false,
      },
      {
        'title': 'Fertirriego',
        'icon': Icons.water_drop,
        'color': Colors.red[500]!,
        'description': 'Sistema de\nriego',
        'active': true,
        'isComingSoon': false, // Este sí es un módulo futuro
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: isTablet ? 32 : 28,
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Módulos Disponibles',
                style: TextStyle(
                  fontSize: isTablet ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: adaptiveCrossAxisCount,
            crossAxisSpacing: isTablet ? 20 : 16,
            mainAxisSpacing: isTablet ? 20 : 16,
            childAspectRatio: aspectRatio,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return _buildModuleCard(
              title: module['title'] as String,
              icon: module['icon'] as IconData,
              color: module['color'] as Color,
              description: module['description'] as String,
              isActive: module['active'] as bool,
              isComingSoon: module['isComingSoon'] as bool, // Pasa el nuevo valor
              isTablet: isTablet,
              onTap: () => _navigateToModule(module['title'] as String),
            );
          },
        ),
      ],
    );
  }

  // ** WIDGET MODIFICADO **
  Widget _buildModuleCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required bool isActive,
    required bool isComingSoon, // Nuevo parámetro
    required bool isTablet,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? color.withOpacity(0.3) : Colors.grey[300]!,
                width: 2,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ] : [],
            ),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: isActive ? color.withOpacity(0.15) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: isTablet ? 40 : 32,
                      color: isActive ? color : Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.grey[800] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: isActive ? Colors.grey[600] : Colors.grey[400],
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isActive) ...[
                    SizedBox(height: isTablet ? 12 : 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        // Lógica para mostrar el texto correcto
                        isComingSoon ? 'Próximamente' : 'Datos incompletos',
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 10,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Métodos helper para validación
  String _getValidationText() {
    if (_validationInfo.isEmpty || _validationInfo['hasBeenValidated'] != true) {
      return 'Nunca';
    }
    
    int hoursAgo = _validationInfo['hoursAgo'] ?? 0;
    
    if (hoursAgo == 0) {
      return 'Hace menos de 1 hora';
    } else if (hoursAgo == 1) {
      return 'Hace 1 hora';
    } else if (hoursAgo < 24) {
      return 'Hace $hoursAgo horas';
    } else {
      int daysAgo = (hoursAgo / 24).floor();
      if (daysAgo == 1) {
        return 'Hace 1 día';
      } else {
        return 'Hace $daysAgo días';
      }
    }
  }

  Color _getValidationStatusColor() {
    if (_validationInfo.isEmpty) return Colors.orange;
    
    bool needsValidation = _validationInfo['needsValidation'] ?? true;
    bool hasConnection = _hasConnection;
    
    if (!needsValidation) {
      return Colors.green;
    } else if (hasConnection) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  IconData _getValidationStatusIcon() {
    if (_validationInfo.isEmpty) return Icons.warning_outlined;
    
    bool needsValidation = _validationInfo['needsValidation'] ?? true;
    bool hasConnection = _hasConnection;
    
    if (!needsValidation) {
      return Icons.verified_user;
    } else if (hasConnection) {
      return Icons.sync_problem;
    } else {
      return Icons.offline_bolt;
    }
  }

  String _getValidationStatusTitle() {
    if (_validationInfo.isEmpty) return 'Estado de validación desconocido';
    
    bool needsValidation = _validationInfo['needsValidation'] ?? true;
    bool hasConnection = _hasConnection;
    
    if (!needsValidation) {
      return 'Usuario validado';
    } else if (hasConnection) {
      return 'Validación pendiente';
    } else {
      return 'Modo offline';
    }
  }
}