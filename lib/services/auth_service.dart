import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';

class AuthService {
  // Variable estática para mantener el usuario actual
  static Map<String, dynamic>? _currentUser;
  
  // ==================== GESTIÓN DE SESIÓN BÁSICA ====================
  
  // Obtener usuario actual
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }
  
  // Establecer usuario actual
  static void setCurrentUser(Map<String, dynamic>? user) {
    _currentUser = user;
    print('Usuario actual establecido: ${user?['username'] ?? 'null'}');
  }
  
  // Verificar si hay un usuario logueado
  static bool isUserLoggedIn() {
    return _currentUser != null;
  }
  
  // Alias para compatibilidad
  static bool isLoggedIn() {
    return isUserLoggedIn();
  }
  
  // Obtener ID del usuario actual
  static int? getCurrentUserId() {
    return _currentUser?['id'];
  }
  
  // Obtener nombre del usuario actual
  static String? getCurrentUserName() {
    return _currentUser?['nombre'] ?? _currentUser?['username'];
  }
  
  // ==================== AUTENTICACIÓN PRINCIPAL ====================
  
  // Login principal (offline first)
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      print('Iniciando login para usuario: $username');
      
      // 1. PRIMERO: Intentar login offline
      Map<String, dynamic>? localUser = await _loginOffline(username, password);
      if (localUser != null) {
        print('Login offline exitoso para: $username');
        setCurrentUser(localUser);
        return {
          'success': true,
          'user': localUser,
          'source': 'offline',
          'message': 'Login offline exitoso'
        };
      }

      // 2. SEGUNDO: Si no hay datos locales, intentar online
      if (await hasInternetConnection()) {
        print('Sin datos locales, intentando login online...');
        Map<String, dynamic>? onlineUser = await _loginOnline(username, password);
        
        if (onlineUser != null) {
          // Guardar usuario localmente para próximos logins offline
          await _saveUserLocally(onlineUser);
          setCurrentUser(onlineUser);
          print('Login online exitoso y guardado localmente');
          
          return {
            'success': true,
            'user': onlineUser,
            'source': 'online',
            'message': 'Login online exitoso'
          };
        } else {
          return {
            'success': false,
            'message': 'Credenciales incorrectas'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sin conexión y sin datos locales'
        };
      }
      
    } catch (e) {
      print('Error en login: $e');
      return {
        'success': false,
        'message': 'Error durante el login: $e'
      };
    }
  }

  // Login offline
  static Future<Map<String, dynamic>?> _loginOffline(String username, String password) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? user = await dbHelper.getUser(username, password);
      
      if (user != null) {
        print('Usuario encontrado en base de datos local');
        return user;
      }
      
      print('Usuario no encontrado en base de datos local');
      return null;
    } catch (e) {
      print('Error en login offline: $e');
      return null;
    }
  }

  // Login online
  static Future<Map<String, dynamic>?> _loginOnline(String username, String password) async {
    try {
      Map<String, dynamic>? user = await SqlServerService.authenticateUser(username, password);
      return user;
    } catch (e) {
      print('Error en login online: $e');
      return null;
    }
  }

  // Guardar usuario localmente
  static Future<void> _saveUserLocally(Map<String, dynamic> user) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.insertOrUpdateUser(user);
      print('Usuario guardado localmente: ${user['username']}');
    } catch (e) {
      print('Error guardando usuario localmente: $e');
    }
  }

  // Login rápido con validación básica
  static Future<Map<String, dynamic>> quickLogin(String username, String password) async {
    // Validaciones básicas
    if (username.isEmpty || password.isEmpty) {
      return {
        'success': false,
        'message': 'Username y password son requeridos'
      };
    }
    
    return await login(username, password);
  }

  // Logout
  static Future<void> logout() async {
    try {
      print('Cerrando sesión para usuario: ${_currentUser?['username']}');
      _currentUser = null;
      print('Sesión cerrada exitosamente');
    } catch (e) {
      print('Error en logout: $e');
    }
  }

  // ==================== VALIDACIÓN DE USUARIOS ====================
  
  // Obtener información de validación del usuario actual
  static Map<String, dynamic> getValidationInfo() {
    try {
      if (_currentUser == null) {
        return {
          'isValid': false,
          'reason': 'No user logged in',
          'needsValidation': true,
          'lastValidation': null,
          'source': 'none'
        };
      }
      
      DateTime? lastUpdate = null;
      if (_currentUser!['fecha_actualizacion'] != null) {
        try {
          lastUpdate = DateTime.parse(_currentUser!['fecha_actualizacion']);
        } catch (e) {
          print('Error parsing fecha_actualizacion: $e');
        }
      }
      
      // Determinar si necesita validación (más de 24 horas)
      bool needsValidation = false;
      if (lastUpdate != null) {
        Duration timeSinceUpdate = DateTime.now().difference(lastUpdate);
        needsValidation = timeSinceUpdate.inHours > 24;
      } else {
        needsValidation = true;
      }
      
      return {
        'isValid': _currentUser!['activo'] == 1,
        'userId': _currentUser!['id'],
        'username': _currentUser!['username'],
        'needsValidation': needsValidation,
        'lastValidation': lastUpdate?.toIso8601String(),
        'hoursSinceUpdate': lastUpdate != null ? DateTime.now().difference(lastUpdate).inHours : null,
        'source': 'memory',
        'userActive': _currentUser!['activo'] == 1
      };
    } catch (e) {
      print('Error obteniendo información de validación: $e');
      return {
        'isValid': false,
        'reason': 'Error getting validation info: $e',
        'needsValidation': true,
        'lastValidation': null,
        'source': 'error'
      };
    }
  }
  
  // Verificar si el usuario necesita validación en servidor
  static bool needsServerValidation() {
    try {
      Map<String, dynamic> validationInfo = getValidationInfo();
      return validationInfo['needsValidation'] ?? true;
    } catch (e) {
      print('Error verificando necesidad de validación: $e');
      return true;
    }
  }

  // Forzar validación del usuario activo en servidor
  static Future<Map<String, dynamic>> forceValidateActiveUser() async {
    try {
      if (_currentUser == null) {
        return {
          'success': false,
          'valid': false,
          'action': 'logout',
          'reason': 'No hay usuario logueado'
        };
      }
      
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'valid': true,
          'action': 'none',
          'reason': 'Sin conexión a internet - usando validación local',
          'source': 'local'
        };
      }
      
      print('Forzando validación del usuario activo: ${_currentUser!['username']}');
      
      String username = _currentUser!['username'];
      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE username = '$username'
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> users = SqlServerService.processQueryResult(result);
      
      if (users.isEmpty) {
        return {
          'success': true,
          'valid': false,
          'action': 'logout',
          'reason': 'Usuario no encontrado en el servidor',
          'source': 'server'
        };
      }
      
      Map<String, dynamic> serverUser = users.first;
      bool isActive = serverUser['activo'] == 1;
      
      if (!isActive) {
        return {
          'success': true,
          'valid': false,
          'action': 'logout',
          'reason': 'Usuario desactivado en el servidor',
          'source': 'server',
          'serverData': serverUser
        };
      }
      
      // Usuario válido - actualizar información local
      try {
        setCurrentUser(serverUser);
        await _saveUserLocally(serverUser);
        
        print('Usuario validado y actualizado exitosamente');
        
        return {
          'success': true,
          'valid': true,
          'action': 'update',
          'reason': 'Usuario válido y actualizado',
          'source': 'server',
          'updatedUser': serverUser
        };
        
      } catch (e) {
        print('Error actualizando usuario validado: $e');
        return {
          'success': true,
          'valid': true,
          'action': 'none',
          'reason': 'Usuario válido pero error actualizando datos locales',
          'source': 'server',
          'error': e.toString()
        };
      }
      
    } catch (e) {
      print('Error en validación forzada: $e');
      return {
        'success': false,
        'valid': false,
        'action': 'error',
        'reason': 'Error durante la validación: $e',
        'source': 'error'
      };
    }
  }
  
  // Validar usuario silenciosamente (sin afectar la sesión actual)
  static Future<Map<String, dynamic>> validateUserQuietly() async {
    try {
      if (_currentUser == null) {
        return {
          'success': false,
          'valid': false,
          'reason': 'No user logged in'
        };
      }
      
      // Si no hay conexión, usar validación local
      if (!await hasInternetConnection()) {
        Map<String, dynamic> validationInfo = getValidationInfo();
        return {
          'success': true,
          'valid': validationInfo['isValid'],
          'source': 'local',
          'reason': validationInfo['isValid'] ? 'Valid locally' : 'Invalid locally',
          'validationInfo': validationInfo
        };
      }
      
      // Validar en servidor sin cambiar la sesión actual
      String username = _currentUser!['username'];
      String query = '''
        SELECT id, username, activo, 
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE username = '$username'
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> users = SqlServerService.processQueryResult(result);
      
      if (users.isNotEmpty) {
        Map<String, dynamic> serverUser = users.first;
        bool isValid = serverUser['activo'] == 1;
        
        // Actualizar información local silenciosamente si es válido
        if (isValid) {
          _currentUser!['activo'] = serverUser['activo'];
          _currentUser!['fecha_actualizacion'] = serverUser['fecha_actualizacion'];
          
          try {
            DatabaseHelper dbHelper = DatabaseHelper();
            await dbHelper.insertOrUpdateUser(_currentUser!);
          } catch (e) {
            print('Error guardando usuario validado: $e');
          }
        }
        
        return {
          'success': true,
          'valid': isValid,
          'source': 'server',
          'reason': isValid ? 'Valid on server' : 'User inactive on server',
          'serverData': serverUser
        };
      } else {
        return {
          'success': true,
          'valid': false,
          'source': 'server',
          'reason': 'User not found on server'
        };
      }
      
    } catch (e) {
      print('Error en validación silenciosa: $e');
      return {
        'success': false,
        'valid': false,
        'reason': 'Error during validation: $e',
        'source': 'error'
      };
    }
  }

  // Verificar si las credenciales son válidas (sin establecer sesión)
  static Future<bool> validateCredentials(String username, String password) async {
    try {
      Map<String, dynamic> result = await login(username, password);
      if (result['success']) {
        // Si el login fue exitoso, hacer logout inmediato para no afectar la sesión actual
        Map<String, dynamic>? previousUser = _currentUser;
        await logout();
        _currentUser = previousUser;
        return true;
      }
      return false;
    } catch (e) {
      print('Error validando credenciales: $e');
      return false;
    }
  }

  // ==================== SINCRONIZACIÓN DE DATOS ====================
  
  // Sincronizar datos básicos (usuarios, supervisores, pesadores, fincas)
  static Future<Map<String, dynamic>> syncBasicData() async {
    try {
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'message': 'Sin conexión a internet'
        };
      }

      print('Iniciando sincronización de datos básicos...');
      
      int totalSynced = 0;
      List<String> errors = [];

      // Sincronizar usuarios
      try {
        List<Map<String, dynamic>> usuarios = await SqlServerService.getUsersFromServer();
        if (usuarios.isNotEmpty) {
          DatabaseHelper dbHelper = DatabaseHelper();
          for (Map<String, dynamic> usuario in usuarios) {
            await dbHelper.insertOrUpdateUser(usuario);
          }
          totalSynced += usuarios.length;
          print('${usuarios.length} usuarios sincronizados');
        }
      } catch (e) {
        errors.add('Usuarios: $e');
        print('Error sincronizando usuarios: $e');
      }

      // Sincronizar supervisores
      try {
        await _syncSupervisores();
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> supervisores = await dbHelper.getAllSupervisores();
        totalSynced += supervisores.length;
        print('${supervisores.length} supervisores sincronizados');
      } catch (e) {
        errors.add('Supervisores: $e');
        print('Error sincronizando supervisores: $e');
      }

      // Sincronizar pesadores  
      try {
        await _syncPesadores();
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> pesadores = await dbHelper.getAllPesadores();
        totalSynced += pesadores.length;
        print('${pesadores.length} pesadores sincronizados');
      } catch (e) {
        errors.add('Pesadores: $e');
        print('Error sincronizando pesadores: $e');
      }

      // Sincronizar fincas básicas
      try {
        await _syncFincasBasicas();
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> fincas = await dbHelper.getAllFincas();
        totalSynced += fincas.length;
        print('${fincas.length} fincas básicas sincronizadas');
      } catch (e) {
        errors.add('Fincas: $e');
        print('Error sincronizando fincas: $e');
      }

      if (errors.isEmpty) {
        return {
          'success': true,
          'message': 'Sincronización básica exitosa. $totalSynced registros sincronizados.',
          'count': totalSynced
        };
      } else {
        return {
          'success': false,
          'message': 'Sincronización parcial. Errores: ${errors.join(', ')}',
          'count': totalSynced
        };
      }

    } catch (e) {
      print('Error en sincronización básica: $e');
      return {
        'success': false,
        'message': 'Error durante la sincronización: $e'
      };
    }
  }

  // Alias para compatibilidad
  static Future<Map<String, dynamic>> syncData() async {
    return await syncBasicData();
  }

  // Sincronización inteligente basada en el estado actual
  static Future<Map<String, dynamic>> smartSync() async {
    try {
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'message': 'Sin conexión a internet'
        };
      }
      
      print('Iniciando sincronización inteligente...');
      
      // Verificar qué datos necesitan sincronización
      Map<String, int> localStats = await getLocalDataStats();
      List<String> needsSync = [];
      
      if (localStats['usuarios']! < 1) needsSync.add('usuarios');
      if (localStats['supervisores']! < 1) needsSync.add('supervisores');
      if (localStats['pesadores']! < 1) needsSync.add('pesadores');
      if (localStats['fincas']! < 1) needsSync.add('fincas');
      
      if (needsSync.isEmpty) {
        return {
          'success': true,
          'message': 'Todos los datos están sincronizados',
          'action': 'none',
          'stats': localStats
        };
      }
      
      print('Sincronizando datos faltantes: ${needsSync.join(', ')}');
      
      // Ejecutar sincronización básica
      Map<String, dynamic> syncResult = await syncBasicData();
      
      return {
        'success': syncResult['success'],
        'message': 'Sincronización inteligente ${syncResult['success'] ? 'exitosa' : 'fallida'}',
        'action': 'sync',
        'missing_before': needsSync,
        'sync_result': syncResult,
        'stats_after': await getLocalDataStats()
      };
      
    } catch (e) {
      print('Error en sincronización inteligente: $e');
      return {
        'success': false,
        'message': 'Error en sincronización inteligente: $e'
      };
    }
  }

  // Sincronización rápida (solo datos críticos)
  static Future<Map<String, dynamic>> quickSync() async {
    try {
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'message': 'Sin conexión a internet'
        };
      }
      
      print('Iniciando sincronización rápida...');
      
      int totalSynced = 0;
      List<String> errors = [];
      
      // Solo sincronizar usuarios si no hay ninguno
      try {
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> localUsers = await dbHelper.getAllUsers();
        
        if (localUsers.isEmpty) {
          List<Map<String, dynamic>> usuarios = await SqlServerService.getUsersFromServer();
          for (Map<String, dynamic> usuario in usuarios) {
            await dbHelper.insertOrUpdateUser(usuario);
          }
          totalSynced += usuarios.length;
          print('${usuarios.length} usuarios sincronizados en modo rápido');
        }
      } catch (e) {
        errors.add('Usuarios: $e');
      }
      
      // Sincronizar fincas básicas si no hay ninguna
      try {
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> localFincas = await dbHelper.getAllFincas();
        
        if (localFincas.isEmpty) {
          await _syncFincasBasicas();
          List<Map<String, dynamic>> fincas = await dbHelper.getAllFincas();
          totalSynced += fincas.length;
          print('${fincas.length} fincas sincronizadas en modo rápido');
        }
      } catch (e) {
        errors.add('Fincas: $e');
      }
      
      return {
        'success': errors.isEmpty,
        'message': errors.isEmpty ? 
          'Sincronización rápida exitosa. $totalSynced registros.' : 
          'Sincronización rápida con errores: ${errors.join(', ')}',
        'count': totalSynced,
        'errors': errors,
        'mode': 'quick'
      };
      
    } catch (e) {
      print('Error en sincronización rápida: $e');
      return {
        'success': false,
        'message': 'Error en sincronización rápida: $e'
      };
    }
  }

  // ==================== MÉTODOS AUXILIARES DE SINCRONIZACIÓN ====================
  
  // Sincronizar supervisores
  static Future<void> _syncSupervisores() async {
    try {
      String query = '''
        SELECT id, nombre, cedula, activo, fecha_actualizacion
        FROM supervisores 
        WHERE activo = 1
        ORDER BY nombre
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> supervisor in data) {
          await dbHelper.insertOrUpdateSupervisor(supervisor);
        }
        print('${data.length} supervisores sincronizados desde servidor');
      }
    } catch (e) {
      print('Error sincronizando supervisores: $e');
      rethrow;
    }
  }

  // Sincronizar pesadores
  static Future<void> _syncPesadores() async {
    try {
      String query = '''
        SELECT id, nombre, cedula, activo, fecha_actualizacion
        FROM pesadores 
        WHERE activo = 1
        ORDER BY nombre
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> pesador in data) {
          await dbHelper.insertOrUpdatePesador(pesador);
        }
        print('${data.length} pesadores sincronizados desde servidor');
      }
    } catch (e) {
      print('Error sincronizando pesadores: $e');
      rethrow;
    }
  }

  // Sincronizar fincas básicas
  static Future<void> _syncFincasBasicas() async {
    try {
      String query = '''
        SELECT DISTINCT FINCA as nombre
        FROM Kontrollers.dbo.base_MIPE 
        WHERE FINCA IS NOT NULL 
          AND FINCA != ''
        ORDER BY FINCA
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> fincaData in data) {
          Map<String, dynamic> finca = {
            'nombre': fincaData['nombre'],
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateFinca(finca);
        }
        print('${data.length} fincas básicas sincronizadas desde servidor');
      }
    } catch (e) {
      print('Error sincronizando fincas básicas: $e');
      rethrow;
    }
  }

  // ==================== VERIFICACIONES DE CONECTIVIDAD ====================
  
  // Verificar conexión a internet (optimizado)
  static Future<bool> hasInternetConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Test rápido de conectividad real
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 3));
      
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  // Test rápido de conexión SQL Server
  static Future<bool> testSqlConnection() async {
    try {
      if (!await hasInternetConnection()) {
        return false;
      }
      
      return await SqlServerService.testConnection();
    } catch (e) {
      print('Error en test SQL: $e');
      return false;
    }
  }

  // ==================== GESTIÓN DE DATOS LOCALES ====================
  
  // Verificar si hay datos básicos en local
  static Future<bool> hasBasicDataLocally() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      List<Map<String, dynamic>> usuarios = await dbHelper.getAllUsers();
      List<Map<String, dynamic>> fincas = await dbHelper.getAllFincas();
      
      return usuarios.isNotEmpty && fincas.isNotEmpty;
    } catch (e) {
      print('Error verificando datos locales: $e');
      return false;
    }
  }

  // Obtener estadísticas de datos locales
  static Future<Map<String, int>> getLocalDataStats() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      return await dbHelper.getDatabaseStats();
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {
        'usuarios': 0,
        'supervisores': 0,
        'pesadores': 0,
        'fincas': 0,
      };
    }
  }

  // Verificar estado de sincronización
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      Map<String, int> stats = await getLocalDataStats();
      DateTime? lastSync = await _getLastSyncTime();
      
      // Determinar estado basado en los datos disponibles
      bool hasEssentialData = stats['usuarios']! > 0 && stats['fincas']! > 0;
      bool hasFullData = hasEssentialData && 
                        stats['supervisores']! > 0 && 
                        stats['pesadores']! > 0;
      
      String status;
      if (hasFullData) {
        status = 'complete';
      } else if (hasEssentialData) {
        status = 'partial';
      } else {
        status = 'empty';
      }
      
      // Verificar si los datos están desactualizados
      bool isOutdated = false;
      if (lastSync != null) {
        Duration timeSinceSync = DateTime.now().difference(lastSync);
        isOutdated = timeSinceSync.inDays > 7;
      }
      
      return {
        'status': status,
        'has_essential_data': hasEssentialData,
        'has_full_data': hasFullData,
        'is_outdated': isOutdated,
        'last_sync': lastSync?.toIso8601String(),
        'days_since_sync': lastSync != null ? DateTime.now().difference(lastSync).inDays : null,
        'stats': stats,
        'recommendations': _getSyncRecommendations(status, isOutdated, stats)
      };
    } catch (e) {
      print('Error obteniendo estado de sincronización: $e');
      return {
        'status': 'error',
        'error': e.toString(),
        'has_essential_data': false,
        'has_full_data': false,
        'recommendations': ['Reiniciar la aplicación']
      };
    }
  }

  // Obtener última fecha de sincronización
  static Future<DateTime?> _getLastSyncTime() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      List<Map<String, dynamic>> result = await dbHelper.database.then((db) => 
        db.rawQuery('''
          SELECT MAX(fecha_actualizacion) as last_sync FROM (
            SELECT fecha_actualizacion FROM usuarios_local WHERE fecha_actualizacion IS NOT NULL
            UNION ALL
            SELECT fecha_actualizacion FROM supervisores_local WHERE fecha_actualizacion IS NOT NULL
            UNION ALL
            SELECT fecha_actualizacion FROM pesadores_local WHERE fecha_actualizacion IS NOT NULL
            UNION ALL
            SELECT fecha_actualizacion FROM fincas_local WHERE fecha_actualizacion IS NOT NULL
          )
        ''')
      );
      
      if (result.isNotEmpty && result.first['last_sync'] != null) {
        return DateTime.parse(result.first['last_sync']);
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo última fecha de sincronización: $e');
      return null;
    }
  }

  // Generar recomendaciones de sincronización
  static List<String> _getSyncRecommendations(String status, bool isOutdated, Map<String, int> stats) {
    List<String> recommendations = [];
    
    switch (status) {
      case 'empty':
        recommendations.add('Ejecutar sincronización completa inmediatamente');
        break;
      case 'partial':
        recommendations.add('Sincronizar supervisores y pesadores');
        break;
      case 'complete':
        if (isOutdated) {
          recommendations.add('Actualizar datos (última sync hace más de 7 días)');
        } else {
          recommendations.add('Datos actualizados y completos');
        }
        break;
    }
    
    if (stats['usuarios']! == 0) {
      recommendations.add('CRÍTICO: Sincronizar usuarios');
    }
    if (stats['fincas']! == 0) {
      recommendations.add('CRÍTICO: Sincronizar fincas');
    }
    
    return recommendations;
  }

  // ==================== MÉTODOS DE INICIALIZACIÓN ====================
  
  // Inicialización de la app (cargar datos básicos)
  static Future<Map<String, dynamic>> initializeApp() async {
    try {
      print('Inicializando aplicación...');
      
      // Verificar si hay datos básicos localmente
      bool hasLocalData = await hasBasicDataLocally();
      
      if (hasLocalData) {
        print('Datos básicos encontrados localmente');
        return {
          'success': true,
          'message': 'App inicializada con datos locales',
          'source': 'local'
        };
      }
      
      // Si no hay datos locales, intentar sincronizar básicos
      if (await hasInternetConnection()) {
        print('Sin datos locales, sincronizando datos básicos...');
        Map<String, dynamic> syncResult = await syncBasicData();
        
        if (syncResult['success']) {
          return {
            'success': true,
            'message': 'App inicializada con sincronización básica',
            'source': 'sync',
            'syncResult': syncResult
          };
        } else {
          return {
            'success': false,
            'message': 'Error en sincronización inicial: ${syncResult['message']}'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Sin datos locales ni conexión a internet'
        };
      }
      
    } catch (e) {
      print('Error inicializando app: $e');
      return {
        'success': false,
        'message': 'Error durante la inicialización: $e'
      };
    }
  }

  // Verificar y reparar datos básicos
  static Future<Map<String, dynamic>> checkAndRepairBasicData() async {
    try {
      print('Verificando integridad de datos básicos...');
      
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, int> stats = await dbHelper.getDatabaseStats();
      
      List<String> missing = [];
      if (stats['usuarios']! < 1) missing.add('usuarios');
      if (stats['fincas']! < 1) missing.add('fincas');
      
      if (missing.isEmpty) {
        return {
          'success': true,
          'message': 'Datos básicos están completos',
          'stats': stats
        };
      }
      
      // Intentar reparar datos faltantes
      if (await hasInternetConnection()) {
        print('Reparando datos faltantes: ${missing.join(', ')}');
        Map<String, dynamic> syncResult = await syncBasicData();
        
        return {
          'success': syncResult['success'],
          'message': 'Reparación ${syncResult['success'] ? 'exitosa' : 'fallida'}',
          'missing_before': missing,
          'sync_result': syncResult
        };
      } else {
        return {
          'success': false,
          'message': 'Datos faltantes pero sin conexión: ${missing.join(', ')}'
        };
      }
      
    } catch (e) {
      print('Error verificando datos básicos: $e');
      return {
        'success': false,
        'message': 'Error en verificación: $e'
      };
    }
  }

  // ==================== MÉTODOS AVANZADOS DE GESTIÓN ====================
  
  // Obtener información completa del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    try {
      if (_currentUser == null) {
        return null;
      }
      
      // Intentar obtener información actualizada desde la base de datos local
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? userDetails = await dbHelper.getUserById(_currentUser!['id']);
      
      if (userDetails != null) {
        // Actualizar el usuario actual con la información más reciente
        setCurrentUser(userDetails);
        return userDetails;
      }
      
      // Si no se encuentra en local, retornar el usuario actual en memoria
      return _currentUser;
    } catch (e) {
      print('Error obteniendo detalles del usuario actual: $e');
      return _currentUser;
    }
  }
  
  // Refrescar información del usuario actual desde el servidor
  static Future<Map<String, dynamic>> refreshCurrentUser() async {
    try {
      if (_currentUser == null) {
        return {
          'success': false,
          'message': 'No hay usuario logueado'
        };
      }
      
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'message': 'Sin conexión a internet'
        };
      }
      
      // Buscar usuario actualizado en el servidor
      String username = _currentUser!['username'];
      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE username = '$username' AND activo = 1
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> users = SqlServerService.processQueryResult(result);
      
      if (users.isNotEmpty) {
        Map<String, dynamic> updatedUser = users.first;
        
        // Actualizar en base de datos local
        await _saveUserLocally(updatedUser);
        
        // Actualizar usuario actual en memoria
        setCurrentUser(updatedUser);
        
        return {
          'success': true,
          'user': updatedUser,
          'message': 'Usuario actualizado exitosamente'
        };
      } else {
        return {
          'success': false,
          'message': 'Usuario no encontrado en el servidor'
        };
      }
      
    } catch (e) {
      print('Error refrescando usuario actual: $e');
      return {
        'success': false,
        'message': 'Error refrescando usuario: $e'
      };
    }
  }

  // Validar y manejar usuario según resultado
  static Future<Map<String, dynamic>> validateAndHandleUser() async {
    try {
      Map<String, dynamic> validation = await forceValidateActiveUser();
      
      // Manejar acciones automáticamente
      switch (validation['action']) {
        case 'logout':
          await logout();
          print('Usuario cerrado automáticamente: ${validation['reason']}');
          break;
        case 'update':
          print('Usuario actualizado automáticamente');
          break;
        case 'error':
          print('Error en validación automática: ${validation['reason']}');
          break;
        default:
          print('Sin acción requerida');
      }
      
      return validation;
    } catch (e) {
      print('Error en validación y manejo automático: $e');
      return {
        'success': false,
        'valid': false,
        'action': 'error',
        'reason': 'Error en validación automática: $e'
      };
    }
  }

  // Verificar estado completo de autenticación
  static Future<Map<String, dynamic>> getAuthStatus() async {
    try {
      Map<String, dynamic> status = {
        'timestamp': DateTime.now().toIso8601String(),
        'isLoggedIn': isLoggedIn(),
        'hasInternetConnection': await hasInternetConnection(),
        'canValidateOnServer': false,
        'validationInfo': {},
        'syncStatus': {},
        'recommendations': <String>[]
      };
      
      if (isLoggedIn()) {
        status['user'] = {
          'id': getCurrentUserId(),
          'username': _currentUser!['username'],
          'name': getCurrentUserName(),
          'active': _currentUser!['activo'] == 1
        };
        
        status['validationInfo'] = getValidationInfo();
        status['canValidateOnServer'] = await hasInternetConnection();
        
        // Obtener estado de sincronización
        status['syncStatus'] = await getSyncStatus();
        
        // Generar recomendaciones
        List<String> recommendations = [];
        
        if (needsServerValidation() && status['canValidateOnServer']) {
          recommendations.add('Validar usuario en servidor');
        }
        
        Map<String, dynamic> syncStatus = status['syncStatus'];
        if (syncStatus['status'] == 'empty' || syncStatus['status'] == 'partial') {
          recommendations.add('Sincronizar datos básicos');
        }
        
        if (syncStatus['is_outdated'] == true) {
          recommendations.add('Actualizar datos (antiguos)');
        }
        
        if (recommendations.isEmpty) {
          recommendations.add('Estado óptimo');
        }
        
        status['recommendations'] = recommendations;
      } else {
        status['recommendations'] = ['Iniciar sesión'];
      }
      
      return status;
    } catch (e) {
      print('Error obteniendo estado de autenticación: $e');
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'isLoggedIn': false,
        'error': e.toString(),
        'recommendations': ['Reiniciar aplicación']
      };
    }
  }

  // Ejecutar rutina de mantenimiento de autenticación
  static Future<Map<String, dynamic>> performMaintenanceRoutine() async {
    try {
      print('Ejecutando rutina de mantenimiento de autenticación...');
      
      Map<String, dynamic> results = {
        'timestamp': DateTime.now().toIso8601String(),
        'actions_performed': <String>[],
        'errors': <String>[],
        'success': true
      };
      
      // 1. Validar usuario si está logueado
      if (isLoggedIn()) {
        try {
          if (needsServerValidation() && await hasInternetConnection()) {
            Map<String, dynamic> validation = await forceValidateActiveUser();
            results['actions_performed'].add('Validación de usuario');
            results['user_validation'] = validation;
            
            if (!validation['valid']) {
              results['success'] = false;
              results['errors'].add('Usuario inválido en servidor');
            }
          }
        } catch (e) {
          results['errors'].add('Error en validación de usuario: $e');
        }
      }
      
      // 2. Verificar estado de datos básicos
      try {
        Map<String, dynamic> syncStatus = await getSyncStatus();
        results['sync_status'] = syncStatus;
        
        if (syncStatus['status'] == 'empty' && await hasInternetConnection()) {
          Map<String, dynamic> quickSyncResult = await quickSync();
          results['actions_performed'].add('Sincronización rápida');
          results['quick_sync'] = quickSyncResult;
          
          if (!quickSyncResult['success']) {
            results['errors'].add('Error en sincronización rápida');
          }
        }
      } catch (e) {
        results['errors'].add('Error verificando datos: $e');
      }
      
      // 3. Limpiar datos temporales si es necesario
      try {
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, dynamic> dbSize = await dbHelper.getDatabaseSize();
        
        // Si la base de datos es muy grande (>50MB), sugerir limpieza
        if (dbSize['size_mb'] > 50) {
          results['actions_performed'].add('Sugerencia de limpieza de DB');
          results['database_cleanup_suggested'] = true;
        }
        
        results['database_size'] = dbSize;
      } catch (e) {
        results['errors'].add('Error verificando tamaño de DB: $e');
      }
      
      results['success'] = results['errors'].isEmpty;
      
      print('Rutina de mantenimiento completada. Acciones: ${results['actions_performed'].length}, Errores: ${results['errors'].length}');
      
      return results;
    } catch (e) {
      print('Error en rutina de mantenimiento: $e');
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'success': false,
        'error': e.toString(),
        'actions_performed': [],
        'errors': ['Error general en rutina de mantenimiento']
      };
    }
  }

  // ==================== MÉTODOS DE UTILIDAD ====================
  
  // Login automático si hay credenciales guardadas
  static Future<Map<String, dynamic>> autoLogin() async {
    try {
      // Si ya hay un usuario logueado, retornar éxito
      if (isUserLoggedIn()) {
        return {
          'success': true,
          'user': _currentUser,
          'source': 'memory',
          'message': 'Usuario ya logueado'
        };
      }
      
      // TODO: Implementar auto-login con credenciales guardadas
      // Por ahora solo verifica si hay datos básicos
      bool hasLocalData = await hasBasicDataLocally();
      
      return {
        'success': false,
        'message': hasLocalData ? 'Datos locales disponibles, login manual requerido' : 'No hay datos locales'
      };
      
    } catch (e) {
      print('Error en auto-login: $e');
      return {
        'success': false,
        'message': 'Error en auto-login: $e'
      };
    }
  }

  // Cambiar contraseña (método placeholder)
  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      if (_currentUser == null) {
        return {
          'success': false,
          'message': 'No hay usuario logueado'
        };
      }
      
      // TODO: Implementar cambio de contraseña en el servidor
      return {
        'success': false,
        'message': 'Funcionalidad de cambio de contraseña no implementada'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error cambiando contraseña: $e'
      };
    }
  }
  
  // Verificar si el usuario actual tiene permisos específicos
  static bool hasPermission(String permission) {
    // TODO: Implementar sistema de permisos
    return isUserLoggedIn();
  }
  
  // Obtener rol del usuario actual
  static String getCurrentUserRole() {
    // TODO: Implementar sistema de roles
    return isUserLoggedIn() ? 'user' : 'guest';
  }

  // Método de emergencia para resetear autenticación
  static Future<Map<String, dynamic>> emergencyReset() async {
    try {
      print('Ejecutando reset de emergencia...');
      
      // Cerrar sesión actual
      await logout();
      
      // Limpiar datos de usuario (mantener otros datos)
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.clearUsers();
      
      // Verificar estado después del reset
      Map<String, dynamic> status = await getAuthStatus();
      
      return {
        'success': true,
        'message': 'Reset de emergencia completado',
        'status_after_reset': status
      };
    } catch (e) {
      print('Error en reset de emergencia: $e');
      return {
        'success': false,
        'message': 'Error en reset de emergencia: $e'
      };
    }
  }
}