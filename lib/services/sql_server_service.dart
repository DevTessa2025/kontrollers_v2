// En el archivo lib/services/sql_server_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:mssql_connection/mssql_connection.dart';

class SqlServerService {
  static const String _server = '181.198.42.194';
  static const String _port = '5010';
  static const String _database = 'Kontrollers';
  static const String _username = 'sa';
  static const String _password = '\$DataWareHouse\$';

  static Future<MssqlConnection?> _getConnection() async {
    try {
      MssqlConnection connection = MssqlConnection.getInstance();
      
      bool isConnected = await connection.connect(
        ip: _server,
        port: _port,
        databaseName: _database,
        username: _username,
        password: _password,
        server: _server,
        database: _database,
        timeoutInSeconds: 15,
      );
      
      if (isConnected) {
        print('Conexión exitosa a SQL Server');
        return connection;
      } else {
        print('Failed to connect to SQL Server');
        return null;
      }
    } catch (e) {
      print('Error connecting to SQL Server: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getUsersFromServer() async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        throw Exception('No se pudo conectar a SQL Server');
      }

      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE activo = 1
        ORDER BY id
      ''';

      print('Ejecutando query: $query');
      String result = await connection.getData(query);
      print('Resultado de la query: $result');
      
      List<Map<String, dynamic>> users = _processQueryResult(result);
      
      print('Usuarios procesados: ${users.length}');
      return users;
      
    } catch (e) {
      print('Error fetching users from server: $e');
      rethrow;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
          print('Desconexión exitosa de SQL Server');
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  static Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        throw Exception('No se pudo conectar a SQL Server');
      }

      // Escapar comillas simples en los parámetros para evitar SQL injection
      String escapedUsername = username.replaceAll("'", "''");
      String escapedPassword = password.replaceAll("'", "''");

      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE username = '$escapedUsername' AND password = '$escapedPassword' AND activo = 1
      ''';

      print('Ejecutando autenticación para usuario: $username');
      String result = await connection.getData(query);
      print('Resultado de autenticación: $result');
      
      List<Map<String, dynamic>> users = _processQueryResult(result);
      
      if (users.isNotEmpty) {
        print('Autenticación exitosa para usuario: $username');
        return users.first;
      }
      
      print('Credenciales incorrectas para usuario: $username');
      return null;
      
    } catch (e) {
      print('Error authenticating user: $e');
      return null;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  static Future<Map<String, dynamic>?> getUserById(int userId) async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        throw Exception('No se pudo conectar a SQL Server');
      }

      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE id = $userId
      ''';

      print('Ejecutando query para usuario ID: $userId');
      String result = await connection.getData(query);
      print('Resultado: $result');
      
      List<Map<String, dynamic>> users = _processQueryResult(result);
      
      if (users.isNotEmpty) {
        print('Usuario encontrado por ID: $userId');
        return users.first;
      }
      
      print('Usuario no encontrado por ID: $userId');
      return null;
      
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  static Future<bool> testConnection() async {
    MssqlConnection? connection;
    try {
      print('Iniciando test de conexión...');
      connection = await _getConnection();
      if (connection != null) {
        // Hacer una consulta simple para verificar la conexión
        String testQuery = 'SELECT 1 as test, GETDATE() as server_time';
        String result = await connection.getData(testQuery);
        print('Test de conexión exitoso. Resultado: $result');
        return true;
      }
      print('Test de conexión falló - no se pudo establecer conexión');
      return false;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting during test: $e');
        }
      }
    }
  }

  static Future<bool> checkTableExists() async {
    MssqlConnection? connection;
    try {
      print('Verificando si existe la tabla usuarios_app...');
      connection = await _getConnection();
      if (connection == null) {
        return false;
      }

      String query = '''
        SELECT COUNT(*) as table_count
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'usuarios_app'
      ''';

      String result = await connection.getData(query);
      List<Map<String, dynamic>> queryResult = _processQueryResult(result);
      
      if (queryResult.isNotEmpty) {
        int tableCount = queryResult.first['table_count'] ?? 0;
        bool exists = tableCount > 0;
        print('Tabla usuarios_app ${exists ? 'existe' : 'no existe'}');
        return exists;
      }
      
      return false;
    } catch (e) {
      print('Error checking table existence: $e');
      return false;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  static Future<bool> updateUserStatus(int userId, bool isActive) async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        throw Exception('No se pudo conectar a SQL Server');
      }

      int activeValue = isActive ? 1 : 0;
      String query = '''
        UPDATE usuarios_app 
        SET activo = $activeValue, 
            fecha_actualizacion = GETDATE()
        WHERE id = $userId
      ''';

      print('Actualizando estado del usuario $userId a ${isActive ? "activo" : "inactivo"}');
      String result = await connection.writeData(query);
      print('Resultado de actualización: $result');
      
      return true;
      
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        throw Exception('No se pudo conectar a SQL Server');
      }

      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        ORDER BY id
      ''';

      print('Obteniendo todos los usuarios...');
      String result = await connection.getData(query);
      List<Map<String, dynamic>> users = _processQueryResult(result);
      
      print('Total usuarios obtenidos: ${users.length}');
      return users;
      
    } catch (e) {
      print('Error getting all users: $e');
      rethrow;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  // Procesar el resultado de la consulta que viene como String JSON
  static List<Map<String, dynamic>> _processQueryResult(String result) {
    try {
      if (result.isEmpty || result == '[]' || result == 'null') {
        print('Resultado vacío o null');
        return [];
      }

      print('Procesando resultado: $result');
      
      // La librería mssql_connection normalmente devuelve un JSON string
      // Si es un array JSON, parsearlo directamente
      if (result.startsWith('[')) {
        var jsonList = jsonDecode(result) as List;
        List<Map<String, dynamic>> processedList = jsonList.map((item) {
          Map<String, dynamic> processedItem = {};
          (item as Map<String, dynamic>).forEach((key, value) {
            // Convertir todos los valores a tipos apropiados
            if (value is num) {
              processedItem[key] = value.toInt();
            } else if (value is String) {
              processedItem[key] = value;
            } else if (value is bool) {
              processedItem[key] = value ? 1 : 0;
            } else {
              processedItem[key] = value;
            }
          });
          return processedItem;
        }).toList();
        
        print('Lista procesada: ${processedList.length} elementos');
        return processedList;
      }
      
      // Si es un objeto JSON simple, convertirlo a lista
      if (result.startsWith('{')) {
        var jsonObject = jsonDecode(result) as Map<String, dynamic>;
        Map<String, dynamic> processedObject = {};
        jsonObject.forEach((key, value) {
          if (value is num) {
            processedObject[key] = value.toInt();
          } else if (value is String) {
            processedObject[key] = value;
          } else if (value is bool) {
            processedObject[key] = value ? 1 : 0;
          } else {
            processedObject[key] = value;
          }
        });
        
        print('Objeto procesado: $processedObject');
        return [processedObject];
      }

      // Si no es JSON válido, intentar parsearlo como resultado de consulta simple
      print('Formato de resultado no reconocido: $result');
      return [];
      
    } catch (e) {
      print('Error processing query result: $e');
      print('Raw result: $result');
      return [];
    }
  }

  // Método auxiliar para obtener información del servidor
  static Future<Map<String, dynamic>?> getServerInfo() async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        return null;
      }

      String query = '''
        SELECT 
          @@VERSION as version,
          @@SERVERNAME as server_name,
          DB_NAME() as database_name,
          GETDATE() as server_time,
          USER_NAME() as current_user
      ''';

      String result = await connection.getData(query);
      List<Map<String, dynamic>> queryResult = _processQueryResult(result);
      
      if (queryResult.isNotEmpty) {
        return queryResult.first;
      }
      
      return null;
    } catch (e) {
      print('Error getting server info: $e');
      return null;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  // Verificar conectividad básica
  static Future<bool> isServerReachable() async {
    try {
      final result = await InternetAddress.lookup(_server);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Servidor $_server es alcanzable');
        return true;
      }
      print('Servidor $_server no es alcanzable');
      return false;
    } catch (e) {
      print('Error verificando alcance del servidor: $e');
      return false;
    }
  }

  // Método genérico para ejecutar queries
  static Future<String> executeQuery(String query) async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        throw Exception('No se pudo conectar a SQL Server');
      }

      print('Ejecutando query: $query');
      
      // Determinar si la consulta es de lectura o escritura
      String upperCaseQuery = query.trim().toUpperCase();
      if (upperCaseQuery.startsWith('SELECT')) {
        String result = await connection.getData(query);
        print('Resultado de la query: $result');
        return result;
      } else {
        // Asumimos que es una operación de escritura (INSERT, UPDATE, DELETE, etc.)
        String result = await connection.writeData(query);
        print('Resultado de la query: $result');
        return result;
      }
      
    } catch (e) {
      print('Error executing query: $e');
      rethrow;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
          print('Desconexión exitosa de SQL Server');
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }

  // Método público para procesar resultados
  static List<Map<String, dynamic>> processQueryResult(String result) {
    return _processQueryResult(result);
  }
  // Método para obtener el estado de la base de datos
  static Future<Map<String, dynamic>?> getDatabaseStatus() async {
    MssqlConnection? connection;
    try {
      connection = await _getConnection();
      if (connection == null) {
        return null;
      }

      String query = '''
        SELECT 
          COUNT(*) as total_users,
          SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) as active_users,
          SUM(CASE WHEN activo = 0 THEN 1 ELSE 0 END) as inactive_users,
          MAX(fecha_actualizacion) as last_update
        FROM usuarios_app
      ''';

      String result = await connection.getData(query);
      List<Map<String, dynamic>> queryResult = _processQueryResult(result);
      
      if (queryResult.isNotEmpty) {
        return queryResult.first;
      }
      
      return null;
    } catch (e) {
      print('Error getting database status: $e');
      return null;
    } finally {
      if (connection != null) {
        try {
          await connection.disconnect();
        } catch (e) {
          print('Error disconnecting: $e');
        }
      }
    }
  }
}