// ==================== SERVICIO DE CONEXIÓN OPTIMIZADO ====================
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';

import '../models/dropdown_models.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

class OptimizedConnectionService {
  // Pool de conexiones y configuración
  static const int MAX_CONCURRENT_CONNECTIONS = 3;
  static const Duration CONNECTION_TIMEOUT = Duration(seconds: 20);
  static const Duration RETRY_DELAY = Duration(seconds: 1);
  static const int MAX_RETRIES = 2;
  
  static int _activeConnections = 0;
  static final List<Completer<void>> _connectionQueue = [];
  
  // Semáforo para controlar conexiones concurrentes
  static Future<void> _acquireConnection() async {
    if (_activeConnections >= MAX_CONCURRENT_CONNECTIONS) {
      final completer = Completer<void>();
      _connectionQueue.add(completer);
      await completer.future;
    }
    _activeConnections++;
  }
  
  static void _releaseConnection() {
    _activeConnections--;
    if (_connectionQueue.isNotEmpty) {
      final completer = _connectionQueue.removeAt(0);
      completer.complete();
    }
  }
  
  // Ejecutar query con pool de conexiones y reintentos
  static Future<T> executeWithPool<T>(Future<T> Function() operation) async {
    int retries = 0;
    
    while (retries < MAX_RETRIES) {
      try {
        await _acquireConnection();
        
        return await operation().timeout(CONNECTION_TIMEOUT);
        
      } catch (e) {
        retries++;
        print('Intento $retries/$MAX_RETRIES falló: $e');
        
        if (retries >= MAX_RETRIES) {
          throw Exception('Operación falló después de $MAX_RETRIES intentos: $e');
        }
        
        // Esperar un tiempo aleatorio para evitar thundering herd
        final delay = Duration(milliseconds: 1000 + Random().nextInt(1000));
        await Future.delayed(delay);
        
      } finally {
        _releaseConnection();
      }
    }
    
    throw Exception('No se pudo completar la operación');
  }
}

// ==================== APLICACIONES DROPDOWN SERVICE ULTRA OPTIMIZADO ====================

class AplicacionesDropdownServiceUltra {
  
  // ==================== FINCAS OPTIMIZADAS ====================
  
  static Future<List<Finca>> getFincas() async {
    try {
      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isNotEmpty) {
        print('Fincas aplicaciones cargadas desde SQLite: ${fincas.length}');
        return fincas;
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo fincas aplicaciones del servidor con vista optimizada...');
        return await _getFincasFromServerOptimized();
      }

      print('Sin fincas locales ni conexión para aplicaciones');
      return [];
      
    } catch (e) {
      print('Error obteniendo fincas para aplicaciones: $e');
      return [];
    }
  }

  static Future<List<Finca>> _getFincasFromLocal() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getAllFincasAplicaciones();
      
      if (localData.isNotEmpty) {
        return localData.map((item) => Finca.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo fincas locales para aplicaciones: $e');
      return [];
    }
  }

  static Future<List<Finca>> _getFincasFromServerOptimized() async {
    return await OptimizedConnectionService.executeWithPool(() async {
      // Usar procedimiento almacenado optimizado
      String query = 'EXEC sp_get_aplicaciones_fincas @Limite = 50';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> fincaData in data) {
          Map<String, dynamic> finca = {
            'nombre': fincaData['nombre'],
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateFincaAplicaciones(finca);
        }
        print('${data.length} fincas aplicaciones sincronizadas desde servidor (OPTIMIZADO)');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    });
  }

  // ==================== BLOQUES ULTRA OPTIMIZADOS ====================
  
  static Future<List<Bloque>> getBloquesByFinca(String finca) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBloquesByFincaAplicaciones(finca);
      
      if (localData.isNotEmpty) {
        print('Bloques aplicaciones cargados desde SQLite: ${localData.length} para finca $finca');
        List<Bloque> bloques = localData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo bloques de $finca desde servidor con procedimiento optimizado...');
        return await _getBloquesByFincaOptimized(finca);
      }

      print('Sin bloques locales ni conexión para finca aplicaciones $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques por finca aplicaciones: $e');
      return [];
    }
  }

  static Future<List<Bloque>> _getBloquesByFincaOptimized(String finca) async {
    return await OptimizedConnectionService.executeWithPool(() async {
      // Usar procedimiento almacenado con parámetros
      String query = '''
        EXEC sp_get_aplicaciones_bloques 
        @Finca = '$finca', 
        @Limite = 100
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> bloqueData in data) {
          Map<String, dynamic> bloque = {
            'nombre': bloqueData['nombre'].toString(),
            'finca': bloqueData['finca'],
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateBloqueAplicaciones(bloque);
        }
        print('${data.length} bloques aplicaciones sincronizados con procedimiento optimizado');
      }
      
      List<Bloque> bloques = data.map((item) => Bloque.fromJson(item)).toList();
      bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
      return bloques;
    });
  }

  // ==================== BOMBAS ULTRA OPTIMIZADAS ====================
  
  static Future<List<Bomba>> getBombasByFincaAndBloque(String finca, String bloque) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBombasByFincaAndBloque(finca, bloque);
      
      if (localData.isNotEmpty) {
        print('Bombas cargadas desde SQLite: ${localData.length} para $finca-$bloque');
        return localData.map((item) => Bomba.fromJson(item)).toList();
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo bombas de $finca-$bloque desde servidor con procedimiento optimizado...');
        return await _getBombasByFincaAndBloqueOptimized(finca, bloque);
      }

      print('Sin bombas locales ni conexión para $finca-$bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo bombas por finca y bloque: $e');
      return [];
    }
  }

  static Future<List<Bomba>> _getBombasByFincaAndBloqueOptimized(String finca, String bloque) async {
    return await OptimizedConnectionService.executeWithPool(() async {
      // Usar procedimiento almacenado específico
      String query = '''
        EXEC sp_get_aplicaciones_bombas 
        @Finca = '$finca', 
        @Bloque = '$bloque', 
        @Limite = 50
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> bombaData in data) {
          Map<String, dynamic> bomba = {
            'nombre': bombaData['nombre'],
            'finca': bombaData['finca'],
            'bloque': bombaData['bloque'].toString(),
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateBomba(bomba);
        }
        print('${data.length} bombas sincronizadas con procedimiento optimizado');
      }
      
      return data.map((item) => Bomba.fromJson(item)).toList();
    });
  }

  // ==================== MÉTODOS PRINCIPALES ====================
  
  static Future<Map<String, dynamic>> getAplicacionesDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos aplicaciones con optimización ULTRA (forceSync: $forceSync)');
      
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada optimizada para aplicaciones');
        return await _forceSyncUltraOptimized();
      }

      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isEmpty && await AuthService.hasInternetConnection()) {
        print('Cargando fincas aplicaciones con vista optimizada...');
        fincas = await _getFincasFromServerOptimized();
      }
      
      print('Fincas aplicaciones cargadas: ${fincas.length}');

      return {
        'success': true,
        'fincas': fincas,
        'message': 'Datos aplicaciones cargados con optimización ULTRA'
      };

    } catch (e) {
      print('Error obteniendo datos aplicaciones: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error cargando datos aplicaciones: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> _forceSyncUltraOptimized() async {
    try {
      print('Iniciando sincronización forzada ULTRA optimizada de aplicaciones...');
      
      List<Finca> fincas = await _getFincasFromServerOptimized();
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada ULTRA de aplicaciones exitosa'
      };
      
    } catch (e) {
      print('Error en sincronización forzada ULTRA de aplicaciones: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error en sincronización forzada ULTRA de aplicaciones: $e'
      };
    }
  }

  // ==================== HELPER METHODS ====================
  
  static int _compareBlockNames(String a, String b) {
    int? numA = int.tryParse(a);
    int? numB = int.tryParse(b);
    
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    
    if (numA != null && numB == null) {
      return -1;
    }
    if (numA == null && numB != null) {
      return 1;
    }
    
    return a.compareTo(b);
  }
}

// ==================== COSECHA DROPDOWN SERVICE ULTRA OPTIMIZADO ====================

class CosechaDropdownServiceUltra {
  
  // ==================== FINCAS OPTIMIZADAS ====================
  
  static Future<List<Finca>> getFincas() async {
    try {
      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isNotEmpty) {
        print('Fincas cosecha cargadas desde SQLite: ${fincas.length}');
        return fincas;
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo fincas cosecha del servidor con vista optimizada...');
        return await _getFincasFromServerOptimized();
      }

      print('Sin fincas locales ni conexión para cosecha');
      return [];
      
    } catch (e) {
      print('Error obteniendo fincas para cosecha: $e');
      return [];
    }
  }

  static Future<List<Finca>> _getFincasFromLocal() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getAllFincas();
      
      if (localData.isNotEmpty) {
        return localData.map((item) => Finca.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo fincas locales para cosecha: $e');
      return [];
    }
  }

  static Future<List<Finca>> _getFincasFromServerOptimized() async {
    return await OptimizedConnectionService.executeWithPool(() async {
      // Usar procedimiento almacenado optimizado para cosecha
      String query = 'EXEC sp_get_cosecha_fincas @Limite = 100';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
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
        print('${data.length} fincas cosecha sincronizadas desde servidor (ULTRA OPTIMIZADO)');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    });
  }

  // ==================== BLOQUES ULTRA OPTIMIZADOS ====================
  
  static Future<List<Bloque>> getBloquesByFinca(String finca) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBloquesByFinca(finca);
      
      if (localData.isNotEmpty) {
        print('Bloques cosecha cargados desde SQLite: ${localData.length} para finca $finca');
        List<Bloque> bloques = localData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo bloques cosecha de $finca desde servidor con procedimiento optimizado...');
        return await _getBloquesByFincaOptimized(finca);
      }

      print('Sin bloques locales ni conexión para finca cosecha $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques por finca cosecha: $e');
      return [];
    }
  }

  static Future<List<Bloque>> _getBloquesByFincaOptimized(String finca) async {
    return await OptimizedConnectionService.executeWithPool(() async {
      // Usar procedimiento almacenado con parámetros
      String query = '''
        EXEC sp_get_cosecha_bloques 
        @Finca = '$finca', 
        @Limite = 200
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> bloqueData in data) {
          Map<String, dynamic> bloque = {
            'nombre': bloqueData['nombre'].toString(),
            'finca': bloqueData['finca'],
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateBloque(bloque);
        }
        print('${data.length} bloques cosecha sincronizados con procedimiento optimizado');
      }
      
      List<Bloque> bloques = data.map((item) => Bloque.fromJson(item)).toList();
      bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
      return bloques;
    });
  }

  // ==================== VARIEDADES ULTRA OPTIMIZADAS ====================
  
  static Future<List<Variedad>> getVariedadesByFincaAndBloque(String finca, String bloque) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getVariedadesByFincaAndBloque(finca, bloque);
      
      if (localData.isNotEmpty) {
        print('Variedades cargadas desde SQLite: ${localData.length} para $finca-$bloque');
        return localData.map((item) => Variedad.fromJson(item)).toList();
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo variedades de $finca-$bloque desde servidor con procedimiento optimizado...');
        return await _getVariedadesByFincaAndBloqueOptimized(finca, bloque);
      }

      print('Sin variedades locales ni conexión para $finca-$bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo variedades por finca y bloque: $e');
      return [];
    }
  }

  static Future<List<Variedad>> _getVariedadesByFincaAndBloqueOptimized(String finca, String bloque) async {
    return await OptimizedConnectionService.executeWithPool(() async {
      // Usar procedimiento almacenado específico
      String query = '''
        EXEC sp_get_cosecha_variedades 
        @Finca = '$finca', 
        @Bloque = '$bloque', 
        @Limite = 50
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> variedadData in data) {
          Map<String, dynamic> variedad = {
            'nombre': variedadData['nombre'],
            'finca': variedadData['finca'],
            'bloque': variedadData['bloque'].toString(),
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateVariedad(variedad);
        }
        print('${data.length} variedades sincronizadas con procedimiento optimizado');
      }
      
      return data.map((item) => Variedad.fromJson(item)).toList();
    });
  }

  // ==================== MÉTODOS PRINCIPALES ====================
  
  static Future<Map<String, dynamic>> getCosechaDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos cosecha con optimización ULTRA (forceSync: $forceSync)');
      
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada optimizada para cosecha');
        return await _forceSyncUltraOptimized();
      }

      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isEmpty && await AuthService.hasInternetConnection()) {
        print('Cargando fincas cosecha con vista optimizada...');
        fincas = await _getFincasFromServerOptimized();
      }
      
      print('Fincas cosecha cargadas: ${fincas.length}');

      return {
        'success': true,
        'fincas': fincas,
        'message': 'Datos cosecha cargados con optimización ULTRA'
      };

    } catch (e) {
      print('Error obteniendo datos cosecha: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error cargando datos cosecha: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> _forceSyncUltraOptimized() async {
    try {
      print('Iniciando sincronización forzada ULTRA optimizada de cosecha...');
      
      List<Finca> fincas = await _getFincasFromServerOptimized();
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada ULTRA de cosecha exitosa'
      };
      
    } catch (e) {
      print('Error en sincronización forzada ULTRA de cosecha: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error en sincronización forzada ULTRA de cosecha: $e'
      };
    }
  }

  // ==================== HELPER METHODS ====================
  
  static int _compareBlockNames(String a, String b) {
    int? numA = int.tryParse(a);
    int? numB = int.tryParse(b);
    
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    
    if (numA != null && numB == null) {
      return -1;
    }
    if (numA == null && numB != null) {
      return 1;
    }
    
    return a.compareTo(b);
  }

  // ==================== MÉTODOS DE DIAGNÓSTICO ====================
  
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      return {
        'active_connections': OptimizedConnectionService._activeConnections,
        'queue_length': OptimizedConnectionService._connectionQueue.length,
        'max_connections': OptimizedConnectionService.MAX_CONCURRENT_CONNECTIONS,
        'connection_timeout_seconds': OptimizedConnectionService.CONNECTION_TIMEOUT.inSeconds,
        'internet_available': await AuthService.hasInternetConnection(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

// ==================== SERVICIO DE MONITOREO ====================

class DatabaseMonitoringService {
  
  static Future<Map<String, dynamic>> checkDatabaseHealth() async {
    try {
      return await OptimizedConnectionService.executeWithPool(() async {
        // Verificar estado de las vistas y procedimientos
        String query = 'EXEC sp_verificar_indices';
        
        String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
        
        return {
          'status': 'healthy',
          'timestamp': DateTime.now().toIso8601String(),
          'optimization_status': 'active',
          'connection_pool': 'operational',
        };
      });
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'optimization_status': 'unknown',
        'connection_pool': 'error',
      };
    }
  }

  static Future<void> performMaintenance() async {
    try {
      await OptimizedConnectionService.executeWithPool(() async {
        // Ejecutar mantenimiento de índices
        String query = 'EXEC sp_mantenimiento_indices';
        await SqlServerService.executeQuery(query);
        print('Mantenimiento de base de datos completado');
      });
    } catch (e) {
      print('Error en mantenimiento de base de datos: $e');
    }
  }
}

// ==================== EJEMPLO DE USO ====================

/*
// Para usar en tu aplicación, reemplaza tus servicios actuales:

// En lugar de AplicacionesDropdownService.getBloquesByFinca(finca)
List<Bloque> bloques = await AplicacionesDropdownServiceUltra.getBloquesByFinca(finca);

// En lugar de CosechaDropdownService.getVariedadesByFincaAndBloque(finca, bloque)
List<Variedad> variedades = await CosechaDropdownServiceUltra.getVariedadesByFincaAndBloque(finca, bloque);

// Para monitorear el estado
Map<String, dynamic> diagnostics = await CosechaDropdownServiceUltra.getDiagnosticInfo();
print('Estado del pool de conexiones: $diagnostics');

// Para verificar salud de la base de datos
Map<String, dynamic> health = await DatabaseMonitoringService.checkDatabaseHealth();
print('Salud de la base de datos: $health');

// Para ejecutar mantenimiento periódico
await DatabaseMonitoringService.performMaintenance();
*/