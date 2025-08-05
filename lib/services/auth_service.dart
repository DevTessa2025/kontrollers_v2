import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'dropdown_service.dart';
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

        // Login exitoso online - guardar usuario localmente
        await dbHelper.insertUser(serverUser);
        await _saveUserSession(serverUser);
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

      // Si hay conexión, verificar estado en el servidor
      if (await hasInternetConnection()) {
        print('Hay conexión, verificando en servidor...');
        
        Map<String, dynamic>? serverUser = await SqlServerService.getUserById(currentUser['id']);
        
        if (serverUser == null) {
          print('Usuario no encontrado en servidor');
          await logout();
          return false;
        }
        
        print('Estado del usuario en servidor - activo: ${serverUser['activo']}');
        
        if (serverUser['activo'] != 1) {
          print('Usuario desactivado en servidor, cerrando sesión');
          await logout();
          return false;
        }
        
        // Actualizar usuario local con datos del servidor
        DatabaseHelper dbHelper = DatabaseHelper();
        await dbHelper.insertOrUpdateUser(serverUser);
        
        // Actualizar timestamp de validación
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
        
        print('Usuario validado exitosamente en servidor');
      } else {
        print('Sin conexión, verificando datos locales...');
        
        // Sin conexión, verificar solo datos locales
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, dynamic>? localUser = await dbHelper.getUserById(currentUser['id']);
        
        if (localUser == null) {
          print('Usuario no encontrado localmente');
          await logout();
          return false;
        }
        
        print('Estado del usuario local - activo: ${localUser['activo']}');
        
        if (localUser['activo'] != 1) {
          print('Usuario desactivado localmente, cerrando sesión');
          await logout();
          return false;
        }
        
        print('Usuario validado en datos locales');
      }
      
      return true;
    } catch (e) {
      print('Error validating user: $e');
      // En caso de error, mantener sesión pero loggear el problema
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

      // Solo validar si hay conexión a internet
      if (!await hasInternetConnection()) {
        print('Sin conexión para validación forzada');
        return true; // Mantener sesión si no hay conexión
      }

      Map<String, dynamic>? serverUser = await SqlServerService.getUserById(currentUser['id']);
      
      if (serverUser == null) {
        print('Usuario no encontrado en servidor durante validación forzada');
        await logout();
        return false;
      }
      
      print('Validación forzada - Estado en servidor, activo: ${serverUser['activo']}');
      
      if (serverUser['activo'] != 1) {
        print('Usuario desactivado en servidor durante validación forzada');
        await logout();
        return false;
      }
      
      // Actualizar usuario local
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.insertOrUpdateUser(serverUser);
      
      // Actualizar timestamp
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
      
      print('Validación forzada exitosa');
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

      // Sincronizar datos de dropdown
      int dropdownSynced = 0;
      String dropdownMessage = '';
      try {
        Map<String, dynamic> dropdownResult = await DropdownService.syncDropdownData();
        if (dropdownResult['success']) {
          dropdownSynced = dropdownResult['count'] ?? 0;
          dropdownMessage = 'Dropdown sincronizado correctamente.';
        } else {
          dropdownMessage = 'Error en dropdown: ${dropdownResult['message']}';
        }
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
}