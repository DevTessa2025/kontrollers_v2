import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../services/sql_server_service.dart';
import '../services/cosecha_dropdown_service.dart';

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userIdKey = 'userId';
  static const String _usernameKey = 'username';
  static const String _nameKey = 'name';
  static const String _lastValidationKey = 'lastValidation';

  // Login del usuario (offline first)
  static Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      // Primero intentar login offline
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localUser = await dbHelper.getUser(username, password);
      
      if (localUser != null) {
        print('Login offline exitoso para usuario: $username');
        await _saveUserSession(localUser);
        
        // Si hay conexión, validar con servidor
        if (await hasInternetConnection()) {
          try {
            Map<String, dynamic>? serverUser = await SqlServerService.authenticateUser(username, password);
            if (serverUser != null && serverUser['activo'] == 1) {
              // Actualizar datos locales con datos del servidor
              await dbHelper.insertOrUpdateUser(serverUser);
              await _saveUserSession(serverUser);
              print('Login validado con servidor para usuario: $username');
              return {
                'success': true,
                'mode': 'online',
                'user': serverUser
              };
            } else if (serverUser != null && serverUser['activo'] != 1) {
              await logout();
              return {
                'success': false,
                'message': 'Usuario desactivado en el servidor'
              };
            }
          } catch (e) {
            print('Error validando con servidor, usando datos locales: $e');
          }
        }
        
        return {
          'success': true,
          'mode': 'offline',
          'user': localUser
        };
      }

      // Si no hay usuario local y hay conexión, intentar login con servidor
      if (await hasInternetConnection()) {
        try {
          Map<String, dynamic>? serverUser = await SqlServerService.authenticateUser(username, password);
          if (serverUser != null && serverUser['activo'] == 1) {
            // Guardar usuario en base local
            await dbHelper.insertOrUpdateUser(serverUser);
            await _saveUserSession(serverUser);
            print('Login online exitoso para usuario: $username');
            return {
              'success': true,
              'mode': 'online',
              'user': serverUser
            };
          }
        } catch (e) {
          print('Error en login online: $e');
        }
      }

      return {
        'success': false,
        'message': 'Credenciales inválidas o sin conexión'
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante el login: $e'
      };
    }
  }

  // Validar usuario de forma silenciosa (para mantener sesión)
  static Future<bool> validateUserQuietly() async {
    try {
      Map<String, dynamic>? currentUser = await getCurrentUser();
      if (currentUser == null) return false;

      // Verificar si necesita validación con servidor
      if (!await needsServerValidation()) {
        return true;
      }

      // Si hay conexión, validar con servidor
      if (await hasInternetConnection()) {
        try {
          Map<String, dynamic>? serverUser = await SqlServerService.getUserById(currentUser['id']);
          
          if (serverUser != null) {
            DatabaseHelper dbHelper = DatabaseHelper();
            await dbHelper.insertOrUpdateUser(serverUser);
            
            if (serverUser['activo'] != 1) {
              print('Usuario desactivado en servidor durante validación silenciosa');
              await logout();
              return false;
            }
            
            // Actualizar timestamp
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_lastValidationKey, DateTime.now().millisecondsSinceEpoch);
            
            print('Validación silenciosa exitosa con servidor');
          }
        } catch (e) {
          print('Error en validación silenciosa con servidor: $e');
        }
      }
      
      return true;
      
    } catch (e) {
      print('Error en validación silenciosa: $e');
      return true; // En caso de error, mantener sesión
    }
  }

  // Validar usuario de forma forzada
  static Future<bool> validateUserForced() async {
    try {
      Map<String, dynamic>? currentUser = await getCurrentUser();
      if (currentUser == null) return false;

      // Si hay conexión, validar con servidor obligatoriamente
      if (await hasInternetConnection()) {
        try {
          DatabaseHelper dbHelper = DatabaseHelper();
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

      // Sincronizar datos de dropdown de BODEGA
      int bodegaDropdownSynced = 0;
      String bodegaDropdownMessage = '';
      try {
        bodegaDropdownSynced = await _syncBodegaDropdownData();
        bodegaDropdownMessage = 'Datos de bodega sincronizados correctamente.';
      } catch (e) {
        bodegaDropdownMessage = 'Error sincronizando datos de bodega: $e';
        print('Error sincronizando datos de bodega: $e');
      }

      // Sincronizar datos de dropdown de COSECHA
      int cosechaDropdownSynced = 0;
      String cosechaDropdownMessage = '';
      try {
        Map<String, dynamic> cosechaResult = await CosechaDropdownService.syncCosechaData();
        if (cosechaResult['success']) {
          cosechaDropdownSynced = cosechaResult['count'] ?? 0;
          cosechaDropdownMessage = 'Datos de cosecha sincronizados correctamente.';
        } else {
          cosechaDropdownMessage = 'Error sincronizando datos de cosecha: ${cosechaResult['message']}';
        }
      } catch (e) {
        cosechaDropdownMessage = 'Error sincronizando datos de cosecha: $e';
        print('Error sincronizando datos de cosecha: $e');
      }

      int totalDropdown = bodegaDropdownSynced + cosechaDropdownSynced;

      return {
        'success': true,
        'message': 'Sincronización exitosa. $usersSynced usuarios, $bodegaDropdownSynced datos de bodega y $cosechaDropdownSynced datos de cosecha sincronizados. $bodegaDropdownMessage $cosechaDropdownMessage',
        'count': usersSynced + totalDropdown,
        'usersSynced': usersSynced,
        'dropdownSynced': totalDropdown,
        'bodegaDropdownSynced': bodegaDropdownSynced,
        'cosechaDropdownSynced': cosechaDropdownSynced
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante la sincronización: $e'
      };
    }
  }

  // Método privado para sincronizar datos de dropdown de bodega
  static Future<int> _syncBodegaDropdownData() async {
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
      print('Error en _syncBodegaDropdownData: $e');
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
      
      if (lastValidation == null) return true;
      
      DateTime lastValidationDate = DateTime.fromMillisecondsSinceEpoch(lastValidation);
      DateTime now = DateTime.now();
      Duration difference = now.difference(lastValidationDate);
      
      // Validar cada 2 horas
      return difference.inHours >= 2;
    } catch (e) {
      return true;
    }
  }

  // Obtener información de validación para mostrar en UI
  static Future<Map<String, dynamic>> getValidationInfo() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? lastValidation = prefs.getInt(_lastValidationKey);
      
      if (lastValidation == null) {
        return {
          'hasBeenValidated': false,
          'needsValidation': true,
          'hoursAgo': null,
        };
      }
      
      DateTime lastValidationDate = DateTime.fromMillisecondsSinceEpoch(lastValidation);
      DateTime now = DateTime.now();
      Duration difference = now.difference(lastValidationDate);
      
      return {
        'hasBeenValidated': true,
        'needsValidation': difference.inHours >= 2,
        'hoursAgo': difference.inHours,
      };
    } catch (e) {
      return {
        'hasBeenValidated': false,
        'needsValidation': true,
        'hoursAgo': null,
      };
    }
  }
  static Future<bool> forceValidateActiveUser() async {
  return await validateUserForced();
}
}