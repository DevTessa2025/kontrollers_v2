import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:kontrollers_v2/services/checklist_fertirriego_storage_service.dart';
import 'package:kontrollers_v2/services/PhysicalDeviceOptimizer.dart';
import 'package:mssql_connection/mssql_connection.dart';
import 'date_helper.dart';

class SqlServerService {
  static const String _server = '181.198.42.194';
  static const String _port = '5010';
  static const String _database = 'Kontrollers';
  static const String _username = 'sa';
  static const String _password = '\$DataWareHouse\$';

  // Configuración de timeouts optimizada para dispositivos físicos
  static const int _connectionTimeout = 30;  // Aumentado para dispositivos físicos
  static const int _maxRetries = 3;          // Aumentado para mayor robustez
  
  // ==================== CONEXIÓN BÁSICA ====================
  
  static Future<MssqlConnection?> _getConnection() async {
    return await PhysicalDeviceOptimizer.executeOptimizedOperation(
      () async {
        print('Conectando a SQL Server...');
        
        MssqlConnection connection = MssqlConnection.getInstance();
        
        // Usar timeout optimizado según el tipo de dispositivo
        int timeoutSeconds = PhysicalDeviceOptimizer.getConnectionTimeout().inSeconds;
        
        bool isConnected = (await connection.connect(
          ip: _server,
          port: _port,
          databaseName: _database,
          username: _username,
          password: _password,
          server: _server,
          database: _database,
          timeoutInSeconds: timeoutSeconds,
        ));
        
        if (isConnected) {
          print('Conexión exitosa a SQL Server (timeout: ${timeoutSeconds}s)');
          return connection;
        } else {
          print('No se pudo conectar a SQL Server');
          return null;
        }
      },
      operationName: 'SQL Server Connection',
    );
  }

  // ==================== EJECUCIÓN DE QUERIES ====================
  
  static Future<String> executeQuery(String query, {int maxRetries = 2}) async {
    return await PhysicalDeviceOptimizer.executeOptimizedOperation(
      () async {
        MssqlConnection? connection;
        
        try {
          print('Ejecutando query optimizada');
          print('Query: ${query.substring(0, query.length.clamp(0, 200))}...');
          
          // Debug específico para fechas
          if (query.toUpperCase().contains('INSERT') && query.contains('fecha_creacion')) {
            print('🔍 DEBUG FECHA - Query contiene fecha_creacion');
            // Buscar el patrón de fecha en la query
            RegExp fechaPattern = RegExp(r"'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})'");
            Match? match = fechaPattern.firstMatch(query);
            if (match != null) {
              print('🔍 DEBUG FECHA - Fecha encontrada en query: ${match.group(1)}');
            } else {
              print('🔍 DEBUG FECHA - No se encontró patrón de fecha válido');
              print('🔍 DEBUG FECHA - Fragmento de query con fecha: ${query.substring(query.indexOf('fecha_creacion') - 20, query.indexOf('fecha_creacion') + 50)}');
            }
          }
          
          connection = await _getConnection();
          if (connection == null) {
            throw Exception('No se pudo conectar a SQL Server');
          }

          // Determinar tipo de consulta y ejecutar
          String upperCaseQuery = query.trim().toUpperCase();
          String result;
          
          if (upperCaseQuery.startsWith('SELECT')) {
            result = (await connection.getData(query).timeout(
              PhysicalDeviceOptimizer.getConnectionTimeout(),
              onTimeout: () => throw TimeoutException('SELECT timeout', PhysicalDeviceOptimizer.getConnectionTimeout()),
            ));
          } else {
            result = (await connection.writeData(query).timeout(
              PhysicalDeviceOptimizer.getConnectionTimeout(),
              onTimeout: () => throw TimeoutException('WRITE timeout', PhysicalDeviceOptimizer.getConnectionTimeout()),
            ));
          }
          
          print('Query ejecutada exitosamente');
          return result;
          
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
      },
      operationName: 'SQL Query Execution',
    );
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

  // ==================== SINCRONIZACIÓN DE FERTIRRIEGO ====================
  
  static Future<void> syncFertirriegoChecklists() async {
    try {
      print('Iniciando sincronización de fertirriego...');
      
      // Obtener checklists no sincronizados
      List<Map<String, dynamic>> unsyncedChecklists = 
          await ChecklistFertiriegoStorageService.getUnsyncedChecklists();
      
      if (unsyncedChecklists.isEmpty) {
        print('No hay checklists de fertirriego para sincronizar');
        return;
      }
      
      for (var checklistData in unsyncedChecklists) {
        try {
          // Convertir datos y enviar al servidor
          bool success = await _sendFertiriegoToServer(checklistData);
          
          if (success) {
            await ChecklistFertiriegoStorageService.markAsSynced(checklistData['id']);
            print('Checklist fertirriego ${checklistData['id']} sincronizado');
          }
        } catch (e) {
          print('Error sincronizando checklist fertirriego ${checklistData['id']}: $e');
        }
      }
      
      print('Sincronización de fertirriego completada');
    } catch (e) {
      print('Error en sincronización de fertirriego: $e');
    }
  }

  static Future<bool> _sendFertiriegoToServer(Map<String, dynamic> checklistData) async {
    try {
      String insertQuery = _generateFertiriegoInsertQuery(checklistData);
      
      await executeQuery(insertQuery);
      
      print('Checklist fertirriego enviado al servidor exitosamente');
      return true;
      
    } catch (e) {
      print('Error enviando checklist fertirriego al servidor: $e');
      return false;
    }
  }

  static String _generateFertiriegoInsertQuery(Map<String, dynamic> record) {
    String escapeValue(dynamic value) {
      if (value == null) return 'NULL';
      if (value is String) return "'${value.replaceAll("'", "''")}'";
      return value.toString();
    }

    String formatDate(String? dateString) {
      if (dateString == null) return 'GETDATE()';
      try {
        DateTime date = DateTime.parse(dateString);
        return DateHelper.formatForSqlServer(date);
      } catch (e) {
        print('🔍 DEBUG FECHA - Error en formatDate: $e');
        return 'GETDATE()';
      }
    }

    // Generar un UUID único para este checklist
    String checklistUuid = DateTime.now().millisecondsSinceEpoch.toString();

    List<String> columnNames = [
      'checklist_uuid',
      'finca_nombre', 'bloque_nombre',
      'usuario_id', 'usuario_nombre', 'fecha_creacion', 'porcentaje_cumplimiento', 'fecha_envio'
    ];
    
    List<String> values = [
      escapeValue(checklistUuid),
      escapeValue(record['finca_nombre']),
      escapeValue(record['bloque_nombre']),
      escapeValue(record['usuario_id']),
      escapeValue(record['usuario_nombre']),
      formatDate(record['fecha_creacion']),
      escapeValue(record['porcentaje_cumplimiento']),
      'GETDATE()'
    ];

    // Lista de IDs de items de fertirriego (23 items)
    List<int> fertiriegoItemIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];

    // Agregar datos de cada item (23 items para fertirriego)
    for (int itemId in fertiriegoItemIds) {
      columnNames.add('item_${itemId}_respuesta');
      values.add(escapeValue(record['item_${itemId}_respuesta']));
      columnNames.add('item_${itemId}_valor_numerico');
      values.add(escapeValue(record['item_${itemId}_valor_numerico']));
      columnNames.add('item_${itemId}_observaciones');
      values.add(escapeValue(record['item_${itemId}_observaciones']));
      columnNames.add('item_${itemId}_foto_base64');
      values.add(escapeValue(record['item_${itemId}_foto_base64']));
    }

    return 'INSERT INTO check_fertirriego (${columnNames.join(', ')}) VALUES (${values.join(', ')})';
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN GENERAL ====================
  
  static Future<Map<String, dynamic>> syncAllModules() async {
    Map<String, dynamic> result = {
      'success': false,
      'modules_synced': 0,
      'total_items': 0,
      'errors': [],
      'message': '',
    };

    try {
      print('=== INICIANDO SINCRONIZACIÓN COMPLETA DE TODOS LOS MÓDULOS ===');
      
      List<String> successMessages = [];
      List<String> errors = [];
      int totalItems = 0;

      // Sincronizar Fertirriego
      try {
        print('Sincronizando checklists de fertirriego...');
        await syncFertirriegoChecklists();
        
        // Obtener estadísticas de fertirriego
        Map<String, dynamic> fertiriegoStats = await ChecklistFertiriegoStorageService.getStats();
        int fertiriegoUnsynced = fertiriegoStats['unsynced'] ?? 0;
        int fertiriegoSynced = fertiriegoStats['synced'] ?? 0;
        
        if (fertiriegoUnsynced == 0 && fertiriegoSynced > 0) {
          successMessages.add('Fertirriego: ${fertiriegoSynced} checklists sincronizados');
          totalItems += fertiriegoSynced;
          result['modules_synced'] = (result['modules_synced'] as int) + 1;
        } else if (fertiriegoUnsynced > 0) {
          errors.add('Fertirriego: ${fertiriegoUnsynced} checklists pendientes');
        } else {
          successMessages.add('Fertirriego: Sin datos para sincronizar');
        }
      } catch (e) {
        print('Error sincronizando fertirriego: $e');
        errors.add('Error en fertirriego: $e');
      }

      // Actualizar resultado
      result['total_items'] = totalItems;
      result['errors'] = errors;
      
      if (errors.isEmpty && successMessages.isNotEmpty) {
        result['success'] = true;
        result['message'] = 'Sincronización exitosa: ${successMessages.join(', ')}';
      } else if (successMessages.isNotEmpty && errors.isNotEmpty) {
        result['success'] = true;
        result['message'] = 'Sincronización parcial. Éxitos: ${successMessages.join(', ')}. Errores: ${errors.join(', ')}';
      } else {
        result['success'] = false;
        result['message'] = 'Errores en sincronización: ${errors.join(', ')}';
      }

      print('=== SINCRONIZACIÓN COMPLETA FINALIZADA ===');
      print('Resultado: ${result['message']}');
      
      return result;
      
    } catch (e) {
      print('Error crítico en sincronización completa: $e');
      result['success'] = false;
      result['message'] = 'Error crítico: $e';
      return result;
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
      'fertirriego_table_exists': false,
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
            
            // 4. Verificar existencia de tabla fertirriego
            try {
              String checkTableQuery = '''
                SELECT COUNT(*) as table_exists 
                FROM INFORMATION_SCHEMA.TABLES 
                WHERE TABLE_NAME = 'check_fertirriego'
              ''';
              String tableResult = await executeQuery(checkTableQuery, maxRetries: 1);
              List<Map<String, dynamic>> tableData = processQueryResult(tableResult);
              diagnostic['fertirriego_table_exists'] = tableData.isNotEmpty && 
                  (tableData.first['table_exists'] ?? 0) > 0;
            } catch (e) {
              diagnostic['table_check_error'] = e.toString();
            }
            
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
    if (diagnostic['server_reachable']) healthScore += 25;
    if (diagnostic['connection_successful']) healthScore += 25;
    if (diagnostic['query_successful']) healthScore += 25;
    if (diagnostic['fertirriego_table_exists']) healthScore += 25;
    
    diagnostic['health_score'] = healthScore;
    diagnostic['status'] = healthScore == 100 ? 'excellent' : 
                          healthScore >= 75 ? 'good' : 
                          healthScore >= 50 ? 'fair' :
                          healthScore >= 25 ? 'poor' : 'failed';

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

  // ==================== MÉTODOS DE ESTADÍSTICAS ====================
  
  static Future<Map<String, dynamic>> getFertiriegoStats() async {
    try {
      String query = '''
        SELECT 
          COUNT(*) as total_checklists,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT finca_nombre) as total_fincas,
          COUNT(DISTINCT bloque_nombre) as total_bloques,
          COUNT(DISTINCT usuario_id) as total_usuarios,
          MIN(fecha_creacion) as fecha_primer_checklist,
          MAX(fecha_creacion) as fecha_ultimo_checklist
        FROM check_fertirriego
        WHERE fecha_creacion >= DATEADD(month, -3, GETDATE())
      ''';

      String result = await executeQuery(query, maxRetries: 1);
      List<Map<String, dynamic>> stats = processQueryResult(result);
      
      return stats.isNotEmpty ? stats.first : {};
      
    } catch (e) {
      print('Error obteniendo estadísticas de fertirriego: $e');
      return {};
    }
  }

  // ==================== VALIDACIÓN DE INTEGRIDAD ====================
  
  static Future<bool> validateFertiriegoTable() async {
    try {
      String query = '''
        SELECT 
          COLUMN_NAME,
          DATA_TYPE,
          IS_NULLABLE
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'check_fertirriego'
        ORDER BY ORDINAL_POSITION
      ''';

      String result = await executeQuery(query, maxRetries: 1);
      List<Map<String, dynamic>> columns = processQueryResult(result);
      
      // Verificar que existan las columnas esenciales
      List<String> requiredColumns = [
        'id', 'checklist_uuid', 'finca_nombre', 'bloque_nombre',
        'usuario_id', 'fecha_creacion', 'porcentaje_cumplimiento'
      ];
      
      List<String> existingColumns = columns.map((col) => col['COLUMN_NAME'].toString().toLowerCase()).toList();
      
      for (String requiredCol in requiredColumns) {
        if (!existingColumns.contains(requiredCol.toLowerCase())) {
          print('Columna requerida faltante: $requiredCol');
          return false;
        }
      }
      
      print('Tabla check_fertirriego validada correctamente');
      return true;
      
    } catch (e) {
      print('Error validando tabla check_fertirriego: $e');
      return false;
    }
  }
}