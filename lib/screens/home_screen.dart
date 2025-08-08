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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? currentUser;
  bool _hasConnection = false;
  bool _isValidating = false;
  bool _isSyncing = false;
  Map<String, int> _dbStats = {};
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

  // [Métodos existentes permanecen igual - copiando desde el anterior]
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
          int dropdown = result['dropdownSynced'] ?? 0;
          
          if (users > 0 || dropdown > 0) {
            Fluttertoast.showToast(
              msg: "Sincronización completa: $users usuarios, $dropdown datos adicionales",
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
        int dropdown = result['dropdownSynced'] ?? 0;
        
        Fluttertoast.showToast(
          msg: "Sincronización exitosa: $users usuarios, $dropdown datos adicionales",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );

        await _loadDatabaseStats();
        await _loadValidationInfo();
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

  Future<void> _loadValidationInfo() async {
    try {
      Map<String, dynamic> info = await AuthService.getValidationInfo();
      setState(() {
        _validationInfo = info;
      });
    } catch (e) {
      print('Error cargando info de validación: $e');
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
      bool isActive = await AuthService.forceValidateActiveUser();
      
      if (!isActive) {
        print('Usuario no activo, mostrando mensaje y redirigiendo...');
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
    await _loadValidationInfo();
    
    if (await AuthService.hasInternetConnection()) {
      await _autoSyncOnLoad();
    }
    
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700], size: 28),
              SizedBox(width: 12),
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '¿Está seguro que desea cerrar sesión?',
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
            expandedHeight: isTablet ? 200 : 160,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.red[800]!,
                      Colors.red[700]!,
                      Colors.red[600]!,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.agriculture,
                                    color: Colors.white,
                                    size: isTablet ? 40 : 32,
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
                                          fontSize: isTablet ? 32 : 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Text(
                                        'Sistema de Gestión Agrícola',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: isTablet ? 16 : 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              // Indicadores de estado en el AppBar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicador de conexión
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _hasConnection 
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _hasConnection 
                              ? Colors.green.withOpacity(0.5)
                              : Colors.orange.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hasConnection ? Icons.wifi : Icons.wifi_off,
                            color: _hasConnection ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _hasConnection ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: _hasConnection ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Indicador de sincronización
                    if (_isSyncing || _isValidating)
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    SizedBox(width: 8),
                    // Menú de acciones
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.more_vert, color: Colors.white),
                      ),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
              ),
            ],
          ),
          
          // Contenido principal
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    // Tarjeta de bienvenida del usuario
                    _buildUserWelcomeCard(isTablet),
                    
                    SizedBox(height: 24),
                    
                    // Grid de módulos
                    _buildModulesGrid(crossAxisCount, isTablet),
                    
                    SizedBox(height: 24),
                    
                    // Información del sistema
                    _buildSystemInfoCard(isTablet),
                    
                    SizedBox(height: 24),
                    
                    // Botón de sincronización (si hay conexión)
                    if (_hasConnection) _buildSyncButton(isTablet),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserWelcomeCard(bool isTablet) {
    return Container(
      width: double.infinity,
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
        'active': false,
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
                  fontSize: isTablet ? 28 : 24,
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
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
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
              isTabletPortrait: isTabletPortrait,
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
    required bool isTabletPortrait,
    required VoidCallback onTap,
  }) {
    // Ajustes dinámicos según orientación
    final iconSize = isTabletPortrait ? 28.0 : (isTablet ? 36.0 : 32.0);
    final titleSize = isTabletPortrait ? 15.0 : (isTablet ? 18.0 : 16.0);
    final descriptionSize = isTabletPortrait ? 11.0 : (isTablet ? 13.0 : 12.0);
    final statusSize = isTabletPortrait ? 8.0 : (isTablet ? 10.0 : 9.0);
    final iconPadding = isTabletPortrait ? 14.0 : (isTablet ? 20.0 : 16.0);
    final cardPadding = isTabletPortrait ? 16.0 : (isTablet ? 24.0 : 20.0);
    
    return Container(
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
        border: Border.all(
          color: isActive ? color.withOpacity(0.3) : Colors.grey[200]!,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    gradient: isActive 
                        ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                        : LinearGradient(colors: [Colors.grey[300]!, Colors.grey[400]!]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isActive ? color : Colors.grey).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
                
                // Espaciado flexible
                SizedBox(height: isTabletPortrait ? 10 : 16),
                
                // Título
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.grey[800] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Espaciado flexible
                SizedBox(height: isTabletPortrait ? 6 : 8),
                
                // Descripción con altura flexible
                Flexible(
                  flex: 2,
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: descriptionSize,
                      color: isActive ? Colors.grey[600] : Colors.grey[400],
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: isTabletPortrait ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Espaciado flexible
                SizedBox(height: isTabletPortrait ? 8 : 12),
                
                // Badge de estado
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTabletPortrait ? 8 : (isTablet ? 12 : 10),
                    vertical: isTabletPortrait ? 3 : (isTablet ? 6 : 4),
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? color.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? color.withOpacity(0.3) : Colors.grey[300]!,
                    ),
                  ),
                  child: FittedBox(
                    child: Text(
                      isActive ? 'DISPONIBLE' : 'EN DESARROLLO',
                      style: TextStyle(
                        fontSize: statusSize,
                        fontWeight: FontWeight.bold,
                        color: isActive ? color : Colors.grey[500],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard(bool isTablet) {
    return Container(
      width: double.infinity,
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
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[600]!, Colors.red[700]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: isTablet ? 28 : 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Estado del Sistema',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          
          // Estado de conexión
          _buildStatusCard(
            icon: _hasConnection ? Icons.cloud_done : Icons.cloud_off,
            title: _hasConnection ? 'Conectado al servidor' : 'Trabajando offline',
            subtitle: _hasConnection 
                ? 'Sincronización automática activa'
                : 'Usando datos locales almacenados',
            color: _hasConnection ? Colors.green : Colors.orange,
            isTablet: isTablet,
          ),
          
          SizedBox(height: 16),
          
          // Estado de validación de usuario
          _buildStatusCard(
            icon: _getValidationStatusIcon(),
            title: _getValidationStatusTitle(),
            subtitle: _getValidationStatusSubtitle(),
            color: _getValidationStatusColor(),
            isTablet: isTablet,
          ),
          
          SizedBox(height: 16),
          
          // Estado de datos locales
          _buildDataStorageCard(isTablet),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isTablet ? 13 : 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStorageCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red[200]!,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storage,
                  color: Colors.red[600],
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Base de Datos Local',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          if (_dbStats.isNotEmpty) ...[
            Text(
              'Registros disponibles offline:',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildDataChip('Usuarios', _dbStats['usuarios'] ?? 0, Colors.blue, isTablet),
                _buildDataChip('Supervisores', _dbStats['supervisores'] ?? 0, Colors.green, isTablet),
                _buildDataChip('Pesadores', _dbStats['pesadores'] ?? 0, Colors.orange, isTablet),
                _buildDataChip('Fincas', _dbStats['fincas'] ?? 0, Colors.purple, isTablet),
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

  // Métodos helper para validación (mismos del anterior)
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
      return 'Usuario validado recientemente';
    } else if (hasConnection) {
      return 'Validación pendiente con servidor';
    } else {
      return 'Trabajando con validación local';
    }
  }

  String _getValidationStatusSubtitle() {
    if (_validationInfo.isEmpty) return 'Conecte a internet para validar';
    
    bool needsValidation = _validationInfo['needsValidation'] ?? true;
    bool hasConnection = _hasConnection;
    String validationText = _getValidationText();
    
    if (!needsValidation) {
      return 'Última validación: $validationText';
    } else if (hasConnection) {
      return 'Se validará automáticamente. Última: $validationText';
    } else {
      return 'Usuario activo localmente. Última validación: $validationText';
    }
  }
}