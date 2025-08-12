import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/auth_service.dart';
import '../services/dropdown_service.dart';
import '../services/cosecha_dropdown_service.dart';
import '../database/database_helper.dart';
import 'login_screen.dart';
import 'checklist_bodega_screen.dart';
import 'checklist_cosecha_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? currentUser;
  bool _hasConnection = false;
  bool _isValidating = false;
  bool _isSyncing = false;
  Map<String, int> _dbStats = {};
  Map<String, int> _cosechaDbStats = {};
  Map<String, dynamic> _validationInfo = {};
  
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
        Map<String, dynamic> result = await AuthService.syncData();

        if (result['success']) {
          int users = result['usersSynced'] ?? 0;
          int bodegaDropdown = result['bodegaDropdownSynced'] ?? 0;
          int cosechaDropdown = result['cosechaDropdownSynced'] ?? 0;
          
          if (users > 0 || bodegaDropdown > 0 || cosechaDropdown > 0) {
            Fluttertoast.showToast(
              msg: "Sincronización completa: $users usuarios, $bodegaDropdown bodega, $cosechaDropdown cosecha",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green[600],
              textColor: Colors.white,
            );
          }

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
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );

      Map<String, dynamic> result = await AuthService.syncData();

      if (result['success']) {
        int users = result['usersSynced'] ?? 0;
        int bodegaDropdown = result['bodegaDropdownSynced'] ?? 0;
        int cosechaDropdown = result['cosechaDropdownSynced'] ?? 0;
        
        Fluttertoast.showToast(
          msg: "Sincronización exitosa: $users usuarios, $bodegaDropdown datos de bodega, $cosechaDropdown datos de cosecha",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );

        await _loadDatabaseStats();
      } else {
        Fluttertoast.showToast(
          msg: result['message'],
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error en sincronización manual: $e');
      Fluttertoast.showToast(
        msg: 'Error durante la sincronización: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }

    setState(() {
      _isSyncing = false;
    });
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
      Map<String, int> cosechaStats = await CosechaDropdownService.getLocalCosechaStats();
      
      setState(() {
        _dbStats = stats;
        _cosechaDbStats = cosechaStats;
      });
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
      await AuthService.validateUserQuietly();
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
                                    color: Colors.red[700],
                                  ),
                                )
                              ] else ...[
                                Icon(
                                  _hasConnection ? Icons.wifi : Icons.wifi_off,
                                  color: _hasConnection ? Colors.green[700] : Colors.orange[700],
                                  size: 20,
                                ),
                              ],
                              SizedBox(width: 12),
                              Text(
                                _isSyncing 
                                    ? 'Sincronizando...' 
                                    : (_hasConnection ? 'Conectado' : 'Sin conexión'),
                                style: TextStyle(
                                  color: _isSyncing 
                                      ? Colors.red[700]
                                      : (_hasConnection ? Colors.green[700] : Colors.orange[700]),
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
              IconButton(
                onPressed: () => _manualSync(),
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isSyncing 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.sync, color: Colors.white, size: 20),
                ),
                tooltip: 'Sincronizar datos',
              ),
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
                      
                      // Información de la base de datos
                      _buildDatabaseInfo(isTablet),
                      
                      SizedBox(height: isTablet ? 32 : 24),
                      
                      // Botón de sincronización
                      _buildSyncButton(isTablet),
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

  Widget _buildDatabaseInfo(bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 20,
        vertical: isTablet ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.storage,
                  color: Colors.blue[600],
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base de Datos Local',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 18 : 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Datos almacenados offline',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isTablet ? 14 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          if (_dbStats.isNotEmpty || _cosechaDbStats.isNotEmpty) ...[
            // Sección de Bodega
            Text(
              'DATOS DE BODEGA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDataChip('Usuarios', _dbStats['usuarios'] ?? 0, Colors.blue, isTablet),
                _buildDataChip('Supervisores', _dbStats['supervisores'] ?? 0, Colors.green, isTablet),
                _buildDataChip('Pesadores', _dbStats['pesadores'] ?? 0, Colors.orange, isTablet),
                _buildDataChip('Fincas', _dbStats['fincas'] ?? 0, Colors.purple, isTablet),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Sección de Cosecha
            Text(
              'DATOS DE COSECHA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDataChip('Fincas', _cosechaDbStats['fincas'] ?? 0, Colors.teal, isTablet),
                _buildDataChip('Bloques', _cosechaDbStats['bloques'] ?? 0, Colors.indigo, isTablet),
                _buildDataChip('Variedades', _cosechaDbStats['variedades'] ?? 0, Colors.pink, isTablet),
              ],
            ),
          ] else ...[
            Text(
              'Base de datos SQLite inicializada',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isTablet ? 14 : 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _hasConnection 
                  ? 'Sincronizando datos...'
                  : 'Conecte a internet para sincronizar',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isTablet ? 12 : 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataChip(String label, int count, Color color, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isTablet ? 8 : 6,
            height: isTablet ? 8 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontSize: isTablet ? 12 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton(bool isTablet) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _manualSync,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 20 : 16,
            horizontal: isTablet ? 32 : 24,
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
                Icons.sync,
                size: isTablet ? 24 : 20,
              ),
        label: Text(
          _isSyncing ? 'SINCRONIZANDO DATOS...' : 'SINCRONIZAR DATOS AHORA',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildModulesGrid(int crossAxisCount, bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Detectar orientación y ajustar diseño
    final isLandscape = screenWidth > screenHeight;
    final isTabletPortrait = isTablet && !isLandscape;
    
    // Ajustar número de columnas según orientación
    int adaptiveCrossAxisCount;
    if (isTablet) {
      adaptiveCrossAxisCount = isLandscape ? 4 : 3; // 4 en horizontal, 3 en vertical
    } else {
      adaptiveCrossAxisCount = 2; // Siempre 2 en móviles
    }
    
    // Calcular aspect ratio dinámico
    double aspectRatio;
    if (isTabletPortrait) {
      aspectRatio = 0.85; // Más alto en tablet vertical
    } else if (isTablet && isLandscape) {
      aspectRatio = 1.1; // Más ancho en tablet horizontal
    } else {
      aspectRatio = 1.0; // Cuadrado en móviles
    }

    final modules = [
      {
        'title': 'Bodega',
        'icon': Icons.warehouse,
        'color': Colors.red[600]!,
        'description': 'Gestión de inventario\ny almacén',
        'active': true,
      },
      {
        'title': 'Cosecha',
        'icon': Icons.grass,
        'color': Colors.red[700]!,
        'description': 'Control de\ncosecha',
        'active': true,
      },
      {
        'title': 'Aplicaciones',
        'icon': Icons.spa_outlined,
        'color': Colors.red[800]!,
        'description': 'Aplicaciones\nfitosanitarias',
        'active': false,
      },
      {
        'title': 'Fertirriego',
        'icon': Icons.water_drop,
        'color': Colors.red[500]!,
        'description': 'Sistema de\nriego',
        'active': false,
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
              isTablet: isTablet,
              onTap: () => _navigateToModule(module['title'] as String),
            );
          },
        ),
      ],
    );
  }

  Widget _buildModuleCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required bool isActive,
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
                        'Próximamente',
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