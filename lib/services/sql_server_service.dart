import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mssql_connection/mssql_connection.dart';

class SqlServerService {
  static const String _server = '181.198.42.194';
  static const String _port = '5010';
  static const String _database = 'Kontrollers';
  static const String _username = 'sa';
  static const String _password = '\$DataWareHouse\$';

  // Configuración de timeouts
  static const int _connectionTimeout = 15;  // Reducido de 30 a 15 segundos
  static const int _maxRetries = 2;          // Reducido de 3 a 2 reintentos
  
  // ==================== CONEXIÓN BÁSICA ====================
  
  static Future<MssqlConnection?> _getConnection() async {
    try {
      print('Conectando a SQL Server...');
      
      MssqlConnection connection = MssqlConnection.getInstance();
      
      bool isConnected = (await connection.connect(
        ip: _server,
        port: _port,
        databaseName: _database,
        username: _username,
        password: _password,
        server: _server,
        database: _database,
        timeoutInSeconds: _connectionTimeout,
      ).timeout(
        Duration(seconds: _connectionTimeout + 5),
        onTimeout: () {
          print('Timeout de conexión después de ${_connectionTimeout + 5} segundos');
          return false;
        },
      ));
      
      if (isConnected) {
        print('Conexión exitosa a SQL Server');
        return connection;
      } else {
        print('No se pudo conectar a SQL Server');
        return null;
      }
    } catch (e) {
      print('Error conectando a SQL Server: $e');
      return null;
    }
  }

  // ==================== EJECUCIÓN DE QUERIES ====================
  
  static Future<String> executeQuery(String query, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      MssqlConnection? connection;
      
      try {
        print('Ejecutando query - Intento $attempt/$maxRetries');
        print('Query: ${query.substring(0, query.length.clamp(0, 100))}...');
        
        connection = await _getConnection();
        if (connection == null) {
          throw Exception('No se pudo conectar a SQL Server');
        }

        // Determinar tipo de consulta y ejecutar
        String upperCaseQuery = query.trim().toUpperCase();
        String result;
        
        if (upperCaseQuery.startsWith('SELECT')) {
          result = (await connection.getData(query).timeout(
            Duration(seconds: 30), // Timeout para SELECT
            onTimeout: () => throw TimeoutException('SELECT timeout', Duration(seconds: 30)),
          ));
        } else {
          result = (await connection.writeData(query).timeout(
            Duration(seconds: 20), // Timeout para INSERT/UPDATE/DELETE
            onTimeout: () => throw TimeoutException('WRITE timeout', Duration(seconds: 20)),
          ));
        }
        
        print('Query ejecutada exitosamente en intento $attempt');
        return result;
        
      } catch (e) {
        print('Error en intento $attempt: $e');
        
        // Si es el último intento, lanzar la excepción
        if (attempt == maxRetries) {
          print('Query falló después de $maxRetries intentos');
          rethrow;
        }
        
        // Esperar antes del siguiente intento
        await Future.delayed(Duration(seconds: attempt));
        
      } finally {
        // Siempre cerrar la conexión
        if (connection != null) {
          try {
            await connection.disconnect();
          } catch (e) {
            print('Error cerrando conexión: $e');
          }
        }
      }
    }
    
    throw Exception('Error inesperado en executeQuery');
  }

  // ==================== MÉTODOS ESPECÍFICOS ====================
  
  // Autenticación de usuarios
  static Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      // Escapar caracteres especiales
      String escapedUsername = username.replaceAll("'", "''");
      String escapedPassword = password.replaceAll("'", "''");

      String query = '''
        SELECT TOP 1 id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE username = '$escapedUsername' AND password = '$escapedPassword' AND activo = 1
      ''';

      String result = await executeQuery(query, maxRetries: 1); // Solo 1 intento para login
      List<Map<String, dynamic>> users = processQueryResult(result);
      
      if (users.isNotEmpty) {
        print('Autenticación exitosa para usuario: $username');
        return users.first;
      }
      
      print('Credenciales incorrectas para usuario: $username');
      return null;
      
    } catch (e) {
      print('Error autenticando usuario: $e');
      return null;
    }
  }

  // Obtener usuarios del servidor
  static Future<List<Map<String, dynamic>>> getUsersFromServer() async {
    try {
      String query = '''
        SELECT id, username, password, nombre, email, activo, 
               CONVERT(VARCHAR(23), fecha_creacion, 126) as fecha_creacion,
               CONVERT(VARCHAR(23), fecha_actualizacion, 126) as fecha_actualizacion
        FROM usuarios_app 
        WHERE activo = 1
        ORDER BY id
      ''';

      String result = await executeQuery(query);
      List<Map<String, dynamic>> users = processQueryResult(result);
      
      print('${users.length} usuarios obtenidos del servidor');
      return users;
      
    } catch (e) {
      print('Error obteniendo usuarios del servidor: $e');
      rethrow;
    }
  }

  // ==================== TEST DE CONEXIÓN ====================
  
  static Future<bool> testConnection() async {
    try {
      print('Iniciando test de conexión rápido...');
      
      String result = await executeQuery('SELECT 1 as test', maxRetries: 1);
      
      if (result.isNotEmpty) {
        print('Test de conexión exitoso');
        return true;
      }
      
      print('Test falló: respuesta vacía');
      return false;
      
    } catch (e) {
      print('Test de conexión falló: $e');
      return false;
    }
  }

  // ==================== VERIFICACIONES DE RED ====================
  
  static Future<bool> isServerReachable() async {
    try {
      final result = await InternetAddress.lookup(_server)
          .timeout(Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Servidor $_server es alcanzable');
        return true;
      }
      print('Servidor $_server no es alcanzable');
      return false;
    } catch (e) {
      print('Error verificando servidor: $e');
      return false;
    }
  }

  // ==================== PROCESAMIENTO DE RESULTADOS ====================
  
  static List<Map<String, dynamic>> processQueryResult(String result) {
    return _processQueryResult(result);
  }
  
  static List<Map<String, dynamic>> _processQueryResult(String result) {
    try {
      if (result.isEmpty || result == '[]' || result == 'null') {
        print('Resultado vacío o null');
        return [];
      }

      print('Procesando resultado (${result.length} caracteres)');
      
      // Verificar si es un array JSON válido
      if (result.startsWith('[')) {
        var jsonList = jsonDecode(result) as List;
        return jsonList.map((item) {
          Map<String, dynamic> processedItem = {};
          (item as Map<String, dynamic>).forEach((key, value) {
            // Convertir valores a tipos apropiados
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
      }
      
      // Si no es un array, intentar convertir a objeto único
      if (result.startsWith('{')) {
        var jsonObject = jsonDecode(result) as Map<String, dynamic>;
        return [jsonObject];
      }
      
      print('Formato de resultado no reconocido, longitud: ${result.length}');
      return [];
      
    } catch (e) {
      print('Error procesando resultado: $e');
      print('Resultado problemático: ${result.substring(0, result.length.clamp(0, 200))}...');
      return [];
    }
  }

  // ==================== INFORMACIÓN DEL SERVIDOR ====================
  
  static Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      String query = '''
        SELECT 
          @@VERSION as version,
          @@SERVERNAME as server_name,
          DB_NAME() as database_name,
          GETDATE() as server_time,
          USER_NAME() as current_user
      ''';

      String result = await executeQuery(query, maxRetries: 1);
      List<Map<String, dynamic>> queryResult = processQueryResult(result);
      
      return queryResult.isNotEmpty ? queryResult.first : null;
    } catch (e) {
      print('Error obteniendo información del servidor: $e');
      return null;
    }
  }

  // ==================== DIAGNÓSTICOS RÁPIDOS ====================
  
  static Future<Map<String, dynamic>> quickDiagnostic() async {
    Map<String, dynamic> diagnostic = {
      'timestamp': DateTime.now().toIso8601String(),
      'server_reachable': false,
      'connection_successful': false,
      'query_successful': false,
      'total_time_ms': 0,
    };

    Stopwatch stopwatch = Stopwatch()..start();

    try {
      // 1. Test de conectividad del servidor
      diagnostic['server_reachable'] = await isServerReachable();
      
      if (diagnostic['server_reachable']) {
        // 2. Test de conexión SQL
        try {
          MssqlConnection? connection = await _getConnection();
          diagnostic['connection_successful'] = connection != null;
          if (connection != null) {
            await connection.disconnect();
          }
        } catch (e) {
          diagnostic['connection_error'] = e.toString();
        }
        
        // 3. Test de query si la conexión fue exitosa
        if (diagnostic['connection_successful']) {
          try {
            await executeQuery('SELECT 1', maxRetries: 1);
            diagnostic['query_successful'] = true;
          } catch (e) {
            diagnostic['query_error'] = e.toString();
          }
        }
      }
      
    } catch (e) {
      diagnostic['general_error'] = e.toString();
    }

    stopwatch.stop();
    diagnostic['total_time_ms'] = stopwatch.elapsedMilliseconds;
    
    // Generar score de salud
    int healthScore = 0;
    if (diagnostic['server_reachable']) healthScore += 33;
    if (diagnostic['connection_successful']) healthScore += 33;
    if (diagnostic['query_successful']) healthScore += 34;
    
    diagnostic['health_score'] = healthScore;
    diagnostic['status'] = healthScore == 100 ? 'excellent' : 
                          healthScore >= 66 ? 'good' : 
                          healthScore >= 33 ? 'poor' : 'failed';

    return diagnostic;
  }

  // ==================== CONFIGURACIÓN ====================
  
  static Map<String, dynamic> getConnectionConfig() {
    return {
      'server': _server,
      'port': _port,
      'database': _database,
      'username': _username,
      'connection_timeout': _connectionTimeout,
      'max_retries': _maxRetries,
    };
  }

  static void printConnectionInfo() {
    print('=== SQL Server Configuration ===');
    print('Server: $_server:$_port');
    print('Database: $_database');
    print('Username: $_username');
    print('Connection Timeout: ${_connectionTimeout}s');
    print('Max Retries: $_maxRetries');
    print('================================');
  }
}