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

  // Login offline/online
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      // Primero intentar login offline
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? user = await dbHelper.getUser(username, password);
      
      if (user != null) {
        // Verificar si el usuario está activo localmente
        if (user['activo'] != 1) {
          return {
            'success': false,
            'message': 'Usuario desactivado',
            'mode': 'offline'
          };
        }

        // Login exitoso offline
        await _saveUserSession(user);
        return {
          'success': true,
          'user': user,
          'mode': 'offline'
        };
      }

      // Si no hay usuario offline, verificar conectividad
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        return {
          'success': false,
          'message': 'No hay conexión y no se encontraron credenciales offline',
          'mode': 'offline'
        };
      }

      // Intentar login online directo al servidor
      Map<String, dynamic>? serverUser = await SqlServerService.authenticateUser(username, password);
      
      if (serverUser != null) {
        // Verificar si el usuario está activo en el servidor
        if (serverUser['activo'] != 1) {
          return {
            'success': false,
            'message': 'Usuario desactivado en el servidor',
            'mode': 'online'
          };
        }

        // Login exitoso online - guardar usuario localmente con el estado activo
        await dbHelper.insertOrUpdateUser(serverUser);
        await _saveUserSession(serverUser);
        
        // Marcar como validado recientemente
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
        
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

  // Validar usuario activo periódicamente
  static Future<bool> validateActiveUser() async {
    try {
      Map<String, dynamic>? currentUser = await getCurrentUser();
      if (currentUser == null) {
        print('No hay usuario en sesión');
        return false;
      }

      print('Validando usuario activo: ${currentUser['username']} (ID: ${currentUser['id']})');

      // SIEMPRE verificar primero datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localUser = await dbHelper.getUserById(currentUser['id']);
      
      if (localUser == null) {
        print('Usuario no encontrado localmente');
        await logout();
        return false;
      }

      print('Estado del usuario local - activo: ${localUser['activo']}');
      
      // Si el usuario está desactivado localmente, cerrar sesión
      if (localUser['activo'] != 1) {
        print('Usuario desactivado localmente, cerrando sesión');
        await logout();
        return false;
      }

      // Si hay conexión, verificar estado en el servidor y actualizar local
      if (await hasInternetConnection()) {
        print('Hay conexión, verificando en servidor para actualizar...');
        
        try {
          Map<String, dynamic>? serverUser = await SqlServerService.getUserById(currentUser['id']);
          
          if (serverUser != null) {
            print('Estado del usuario en servidor - activo: ${serverUser['activo']}');
            
            // Actualizar usuario local con datos del servidor
            await dbHelper.insertOrUpdateUser(serverUser);
            
            // Si el servidor dice que está desactivado, cerrar sesión
            if (serverUser['activo'] != 1) {
              print('Usuario desactivado en servidor, cerrando sesión');
              await logout();
              return false;
            }
            
            // Actualizar timestamp de validación
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
            
            print('Usuario validado y actualizado desde servidor');
          } else {
            print('Usuario no encontrado en servidor, pero mantener sesión con datos locales');
            // No cerrar sesión si no se encuentra en servidor, mantener estado local
          }
        } catch (e) {
          print('Error consultando servidor, mantener validación local: $e');
          // En caso de error del servidor, confiar en datos locales
        }
      } else {
        print('Sin conexión, validación basada en datos locales exitosa');
      }
      
      return true;
    } catch (e) {
      print('Error validating user: $e');
      // En caso de error, mantener sesión
      return true;
    }
  }

  // Forzar validación inmediata (sin cache de tiempo)
  static Future<bool> forceValidateActiveUser() async {
    try {
      Map<String, dynamic>? currentUser = await getCurrentUser();
      if (currentUser == null) {
        print('No hay usuario en sesión para validación forzada');
        return false;
      }

      print('Validación forzada para usuario: ${currentUser['username']} (ID: ${currentUser['id']})');

      // SIEMPRE verificar primero datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localUser = await dbHelper.getUserById(currentUser['id']);
      
      if (localUser == null) {
        print('Usuario no encontrado localmente durante validación forzada');
        await logout();
        return false;
      }

      print('Validación forzada - Estado local, activo: ${localUser['activo']}');
      
      // Si está desactivado localmente, cerrar sesión inmediatamente
      if (localUser['activo'] != 1) {
        print('Usuario desactivado localmente durante validación forzada');
        await logout();
        return false;
      }

      // Si hay conexión, intentar validar con servidor
      if (await hasInternetConnection()) {
        print('Conexión disponible para validación forzada en servidor');
        
        try {
          Map<String, dynamic>? serverUser = await SqlServerService.getUserById(currentUser['id']);
          
          if (serverUser != null) {
            print('Validación forzada - Estado en servidor, activo: ${serverUser['activo']}');
            
            // Actualizar usuario local con datos más recientes del servidor
            await dbHelper.insertOrUpdateUser(serverUser);
            
            if (serverUser['activo'] != 1) {
              print('Usuario desactivado en servidor durante validación forzada');
              await logout();
              return false;
            }
            
            // Actualizar timestamp
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
            
            print('Validación forzada exitosa con servidor');
          } else {
            print('Usuario no encontrado en servidor durante validación forzada, mantener estado local');
            // Mantener sesión con datos locales si no se encuentra en servidor
          }
        } catch (e) {
          print('Error en validación forzada con servidor: $e');
          // Si hay error del servidor, confiar en validación local
        }
      } else {
        print('Sin conexión para validación forzada, usando datos locales');
      }
      
      return true;
      
    } catch (e) {
      print('Error en validación forzada: $e');
      return true; // En caso de error, mantener sesión
    }
  }

  // Sincronizar datos desde servidor (usuarios + dropdown)
  static Future<Map<String, dynamic>> syncData() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
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

      // Sincronizar datos de dropdown directamente
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

  // Método privado para sincronizar datos de dropdown
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

  // Guardar sesión de usuario
  static Future<void> _saveUserSession(Map<String, dynamic> user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_userIdKey, user['id']);
    await prefs.setString(_usernameKey, user['username']);
    await prefs.setString(_nameKey, user['nombre'] ?? '');
  }

  // Verificar si hay sesión activa
  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Obtener información del usuario logueado
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLogged = prefs.getBool(_isLoggedInKey) ?? false;
    
    if (!isLogged) return null;

    return {
      'id': prefs.getInt(_userIdKey),
      'username': prefs.getString(_usernameKey),
      'nombre': prefs.getString(_nameKey),
    };
  }

  // Cerrar sesión
  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Verificar conectividad
  static Future<bool> hasInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // Verificar si necesita validación con servidor (basado en tiempo)
  static Future<bool> needsServerValidation() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? lastValidation = prefs.getInt(_lastValidationKey);
      
      if (lastValidation == null) {
        return true; // Nunca se ha validado con servidor
      }
      
      DateTime lastValidationDate = DateTime.fromMillisecondsSinceEpoch(lastValidation);
      DateTime now = DateTime.now();
      Duration difference = now.difference(lastValidationDate);
      
      // Necesita validación si han pasado más de 4 horas
      return difference.inHours >= _validationIntervalHours;
    } catch (e) {
      print('Error checking validation time: $e');
      return true; // En caso de error, asumir que necesita validación
    }
  }

  // Obtener información de la última validación
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
      print('Error getting validation info: $e');
      return {
        'hasBeenValidated': false,
        'lastValidation': null,
        'hoursAgo': null,
        'needsValidation': true,
      };
    }
  }
}