import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userIdKey = 'userId';
  static const String _usernameKey = 'username';
  static const String _nameKey = 'name';
  static const String _lastValidationKey = 'lastValidation';
  static const int _validationIntervalHours = 4; // Validar cada 4 horas
  
  // Variable estática para mantener el usuario actual en memoria
  static Map<String, dynamic>? _currentUser;

  // ==================== LOGIN ====================
  
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      // 1. Intentar login offline primero
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localUser = await dbHelper.getUser(username, password);
      
      if (localUser != null) {
        // Verificar si el usuario está activo localmente
        if (localUser['activo'] != 1) {
          return {
            'success': false,
            'message': 'Usuario desactivado localmente',
            'mode': 'offline'
          };
        }

        // Login exitoso offline - guardar en memoria y preferencias
        _currentUser = localUser;
        await _saveUserSession(localUser);
        
        return {
          'success': true,
          'user': localUser,
          'mode': 'offline'
        };
      }

      // 2. Si no hay usuario offline, intentar online
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'message': 'No hay conexión y no se encontraron credenciales offline',
          'mode': 'offline'
        };
      }

      // Intentar login online
      Map<String, dynamic>? serverUser = await SqlServerService.authenticateUser(username, password);
      
      if (serverUser != null) {
        if (serverUser['activo'] != 1) {
          return {
            'success': false,
            'message': 'Usuario desactivado en el servidor',
            'mode': 'online'
          };
        }

        // Login exitoso online - guardar localmente y en memoria
        await dbHelper.insertOrUpdateUser(serverUser);
        _currentUser = serverUser;
        await _saveUserSession(serverUser);
        
        // Marcar como validado recientemente
        await _updateValidationTimestamp();
        
        return {
          'success': true,
          'user': serverUser,
          'mode': 'online'
        };
      }

      return {
        'success': false,
        'message': 'Credenciales incorrectas',
        'mode': 'online'
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante el login: $e',
      };
    }
  }

  // ==================== VALIDACIÓN DE USUARIO ACTIVO ====================
  
  // Validación principal - más robusta y clara
  static Future<Map<String, dynamic>> validateActiveUser() async {
    try {
      print('=== INICIANDO VALIDACIÓN DE USUARIO ACTIVO ===');
      
      // 1. Verificar que hay usuario en sesión
      if (_currentUser == null) {
        await _loadCurrentUserFromPreferences();
      }
      
      if (_currentUser == null) {
        print('No hay usuario en sesión');
        return {
          'success': false,
          'valid': false,
          'action': 'no_user',
          'message': 'No hay usuario en sesión'
        };
      }

      print('Validando usuario: ${_currentUser!['username']} (ID: ${_currentUser!['id']})');

      // 2. Validación local SIEMPRE primero
      Map<String, dynamic> localValidation = await _validateUserLocally();
      if (localValidation['valid']) {
        await logout(forced: true);
        return localValidation;
      }

      // 3. Verificar si necesita validación con servidor
      if (!await needsServerValidation()) {
        print('Validación local exitosa - no requiere validación en servidor aún');
        return {
          'success': true,
          'valid': true,
          'action': 'none',
          'message': 'Usuario válido - usando cache local',
          'source': 'local_cache'
        };
      }

      // 4. Validación con servidor si hay conexión
      if (await hasInternetConnection()) {
        print('Validando con servidor...');
        return await _validateUserOnServer();
      } else {
        print('Sin conexión - manteniendo validación local');
        return {
          'success': true,
          'valid': true,
          'action': 'none',
          'message': 'Usuario válido localmente - sin conexión para validar en servidor',
          'source': 'local_no_connection'
        };
      }

    } catch (e) {
      print('Error en validación de usuario: $e');
      return {
        'success': false,
        'valid': false,
        'action': 'error',
        'message': 'Error durante la validación: $e'
      };
    }
  }

  // Validación local del usuario
  static Future<Map<String, dynamic>> _validateUserLocally() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localUser = await dbHelper.getUserById(_currentUser!['id']);
      
      if (localUser == null) {
        print('Usuario no encontrado en base de datos local');
        return {
          'success': true,
          'valid': false,
          'action': 'logout',
          'message': 'Usuario no encontrado localmente',
          'source': 'local'
        };
      }

      if (localUser['activo'] != 1) {
        print('Usuario desactivado localmente');
        return {
          'success': true,
          'valid': false,
          'action': 'logout',
          'message': 'Usuario desactivado localmente',
          'source': 'local'
        };
      }

      // Actualizar usuario en memoria si hay cambios
      _currentUser = localUser;
      
      print('Validación local exitosa');
      return {
        'success': true,
        'valid': true,
        'action': 'none',
        'message': 'Usuario válido localmente',
        'source': 'local'
      };

    } catch (e) {
      print('Error en validación local: $e');
      return {
        'success': false,
        'valid': false,
        'action': 'error',
        'message': 'Error en validación local: $e'
      };
    }
  }

  // Validación con servidor
  static Future<Map<String, dynamic>> _validateUserOnServer() async {
    try {
      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE id = ${_currentUser!['id']}
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> users = SqlServerService.processQueryResult(result);
      
      if (users.isEmpty) {
        print('Usuario no encontrado en servidor');
        await logout(forced: true);
        return {
          'success': true,
          'valid': false,
          'action': 'logout',
          'message': 'Usuario no encontrado en servidor',
          'source': 'server'
        };
      }

      Map<String, dynamic> serverUser = users.first;
      
      if (serverUser['activo'] != 1) {
        print('Usuario desactivado en servidor');
        await logout(forced: true);
        return {
          'success': true,
          'valid': false,
          'action': 'logout',
          'message': 'Usuario desactivado en servidor',
          'source': 'server'
        };
      }

      // Usuario válido - actualizar datos locales y en memoria
      print('Usuario válido en servidor - actualizando datos locales');
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.insertOrUpdateUser(serverUser);
      _currentUser = serverUser;
      await _updateValidationTimestamp();

      return {
        'success': true,
        'valid': true,
        'action': 'updated',
        'message': 'Usuario válido y actualizado desde servidor',
        'source': 'server'
      };

    } catch (e) {
      print('Error validando en servidor: $e');
      // En caso de error del servidor, mantener sesión local si es válida
      return {
        'success': false,
        'valid': true,
        'action': 'none',
        'message': 'Error del servidor - manteniendo sesión local válida',
        'source': 'server_error',
        'error': e.toString()
      };
    }
  }

  // Validación forzada (sin cache de tiempo)
  static Future<Map<String, dynamic>> forceValidateActiveUser() async {
    try {
      print('=== VALIDACIÓN FORZADA SOLICITADA ===');
      
      if (_currentUser == null) {
        await _loadCurrentUserFromPreferences();
      }
      
      if (_currentUser == null) {
        return {
          'success': false,
          'valid': false,
          'action': 'no_user',
          'message': 'No hay usuario para validar'
        };
      }

      // Validación local primero
      Map<String, dynamic> localValidation = await _validateUserLocally();
      if (!localValidation['valid']) {
        await logout();
        return localValidation;
      }

      // Forzar validación con servidor si hay conexión
      if (await hasInternetConnection()) {
        return await _validateUserOnServer();
      } else {
        return {
          'success': true,
          'valid': true,
          'action': 'none',
          'message': 'Usuario válido localmente - sin conexión para validar en servidor',
          'source': 'forced_local'
        };
      }

    } catch (e) {
      print('Error en validación forzada: $e');
      return {
        'success': false,
        'valid': false,
        'action': 'error',
        'message': 'Error en validación forzada: $e'
      };
    }
  }

  // ==================== GESTIÓN DE SESIÓN ====================
  
  static Future<void> _saveUserSession(Map<String, dynamic> user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_userIdKey, user['id']);
    await prefs.setString(_usernameKey, user['username']);
    await prefs.setString(_nameKey, user['nombre'] ?? '');
  }

  static Future<void> _loadCurrentUserFromPreferences() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLogged = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (!isLogged) {
        _currentUser = null;
        return;
      }

      int? userId = prefs.getInt(_userIdKey);
      if (userId != null) {
        DatabaseHelper dbHelper = DatabaseHelper();
        _currentUser = await dbHelper.getUserById(userId);
      }
    } catch (e) {
      print('Error cargando usuario desde preferencias: $e');
      _currentUser = null;
    }
  }

  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool logged = prefs.getBool(_isLoggedInKey) ?? false;
    
    // Si está logueado pero no hay usuario en memoria, cargarlo
    if (logged && _currentUser == null) {
      await _loadCurrentUserFromPreferences();
    }
    
    return logged && _currentUser != null;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUser == null) {
      await _loadCurrentUserFromPreferences();
    }
    return _currentUser;
  }

  // Callback para notificar cambios de estado de autenticación
  static Function(bool)? _onAuthStateChanged;
  static Function()? _onForceLogout;

  // Configurar callbacks para reaccionar a cambios de autenticación
  static void setAuthStateListeners({
    Function(bool)? onAuthStateChanged,
    Function()? onForceLogout,
  }) {
    _onAuthStateChanged = onAuthStateChanged;
    _onForceLogout = onForceLogout;
  }

  static Future<void> logout({bool forced = false}) async {
    print('Cerrando sesión de usuario (forced: $forced)');
    
    try {
      // Limpiar preferencias
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Limpiar usuario en memoria
      _currentUser = null;
      
      // Notificar cambio de estado
      if (_onAuthStateChanged != null) {
        _onAuthStateChanged!(false);
      }
      
      // Si es un logout forzado (por validación), ejecutar callback específico
      if (forced && _onForceLogout != null) {
        _onForceLogout!();
      }
      
      print('Sesión cerrada exitosamente');
      
    } catch (e) {
      print('Error durante el logout: $e');
    }
  }

  // ==================== VALIDACIÓN TEMPORAL ====================
  
  static Future<void> _updateValidationTimestamp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<bool> needsServerValidation() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? lastValidation = prefs.getInt(_lastValidationKey);
      
      if (lastValidation == null) {
        return true; // Nunca se ha validado
      }
      
      DateTime lastValidationDate = DateTime.fromMillisecondsSinceEpoch(lastValidation);
      DateTime now = DateTime.now();
      Duration difference = now.difference(lastValidationDate);
      
      return difference.inHours >= _validationIntervalHours;
    } catch (e) {
      print('Error verificando necesidad de validación: $e');
      return true;
    }
  }

  static Future<Map<String, dynamic>> getValidationInfo() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? lastValidation = prefs.getInt(_lastValidationKey);
      
      if (lastValidation == null) {
        return {
          'hasBeenValidated': false,
          'lastValidation': null,
          'hoursAgo': null,
          'needsValidation': true,
        };
      }
      
      DateTime lastValidationDate = DateTime.fromMillisecondsSinceEpoch(lastValidation);
      DateTime now = DateTime.now();
      Duration difference = now.difference(lastValidationDate);
      
      return {
        'hasBeenValidated': true,
        'lastValidation': lastValidationDate,
        'hoursAgo': difference.inHours,
        'needsValidation': difference.inHours >= _validationIntervalHours,
      };
    } catch (e) {
      print('Error obteniendo información de validación: $e');
      return {
        'hasBeenValidated': false,
        'lastValidation': null,
        'hoursAgo': null,
        'needsValidation': true,
      };
    }
  }

  // ==================== UTILIDADES ====================
  
  static Future<bool> hasInternetConnection() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conectividad: $e');
      return false;
    }
  }

  // ==================== SINCRONIZACIÓN ====================
  
  static Future<Map<String, dynamic>> syncData() async {
    try {
      if (!await hasInternetConnection()) {
        return {
          'success': false,
          'message': 'No hay conexión a internet'
        };
      }

      print('Iniciando sincronización completa...');
      
      // Sincronizar usuarios
      List<Map<String, dynamic>> serverUsers = await SqlServerService.getUsersFromServer();
      
      DatabaseHelper dbHelper = DatabaseHelper();
      int usersSynced = 0;
      
      for (Map<String, dynamic> user in serverUsers) {
        await dbHelper.insertOrUpdateUser(user);
        usersSynced++;
      }

      // Sincronizar datos de dropdown
      int dropdownSynced = 0;
      String dropdownMessage = '';
      try {
        dropdownSynced = await _syncDropdownData();
        dropdownMessage = 'Dropdown sincronizado correctamente.';
      } catch (e) {
        dropdownMessage = 'Error sincronizando dropdown: $e';
        print('Error sincronizando datos de dropdown: $e');
      }

      return {
        'success': true,
        'message': 'Sincronización exitosa. $usersSynced usuarios y $dropdownSynced datos adicionales sincronizados. $dropdownMessage',
        'count': usersSynced + dropdownSynced,
        'usersSynced': usersSynced,
        'dropdownSynced': dropdownSynced
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante la sincronización: $e'
      };
    }
  }

  static Future<int> _syncDropdownData() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      int totalSynced = 0;

      // Sincronizar supervisores
      try {
        String supervisoresQuery = '''
          SELECT id, nombre, cedula, activo 
          FROM supervisores 
          WHERE activo = 1 
          ORDER BY nombre
        ''';
        String result = await SqlServerService.executeQuery(supervisoresQuery);
        List<Map<String, dynamic>> supervisores = SqlServerService.processQueryResult(result);
        
        for (Map<String, dynamic> supervisor in supervisores) {
          supervisor['fecha_actualizacion'] = DateTime.now().toIso8601String();
          await dbHelper.insertOrUpdateSupervisor(supervisor);
          totalSynced++;
        }
        print('${supervisores.length} supervisores sincronizados');
      } catch (e) {
        print('Error sincronizando supervisores: $e');
      }

      // Sincronizar pesadores
      try {
        String pesadoresQuery = '''
          SELECT id, nombre, cedula, activo 
          FROM pesadores 
          WHERE activo = 1 
          ORDER BY nombre
        ''';
        String result = await SqlServerService.executeQuery(pesadoresQuery);
        List<Map<String, dynamic>> pesadores = SqlServerService.processQueryResult(result);
        
        for (Map<String, dynamic> pesador in pesadores) {
          pesador['fecha_actualizacion'] = DateTime.now().toIso8601String();
          await dbHelper.insertOrUpdatePesador(pesador);
          totalSynced++;
        }
        print('${pesadores.length} pesadores sincronizados');
      } catch (e) {
        print('Error sincronizando pesadores: $e');
      }

      // Sincronizar fincas
      try {
        String fincasQuery = '''
          SELECT DISTINCT LOCALIDAD as nombre
          FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
          WHERE LOCALIDAD IS NOT NULL 
            AND LOCALIDAD != ''
          ORDER BY LOCALIDAD
        ''';
        String result = await SqlServerService.executeQuery(fincasQuery);
        List<Map<String, dynamic>> fincasData = SqlServerService.processQueryResult(result);
        
        for (Map<String, dynamic> fincaData in fincasData) {
          Map<String, dynamic> finca = {
            'nombre': fincaData['nombre'],
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateFinca(finca);
          totalSynced++;
        }
        print('${fincasData.length} fincas sincronizadas');
      } catch (e) {
        print('Error sincronizando fincas: $e');
      }

      return totalSynced;
    } catch (e) {
      print('Error en _syncDropdownData: $e');
      return 0;
    }
  }
}