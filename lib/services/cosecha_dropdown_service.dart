// ==================== COSECHA DROPDOWN SERVICE OPTIMIZADO ====================
import 'dart:convert';
import 'dart:async';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';

import '../models/dropdown_models.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

class CosechaDropdownService {
  
  // Configuración de timeouts y límites
  static const Duration QUERY_TIMEOUT = Duration(seconds: 30);
  static const int MAX_RETRIES = 3;
  static const Duration RETRY_DELAY = Duration(seconds: 2);
  static const int BATCH_SIZE = 50; // Procesar en lotes pequeños
  
  // ==================== FINCAS OPTIMIZADO ====================
  
  static Future<List<Finca>> getFincas() async {
    try {
      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isNotEmpty) {
        print('Fincas cargadas desde SQLite para cosecha: ${fincas.length}');
        return fincas;
      }

      if (await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para cosecha, obteniendo del servidor...');
        return await _getFincasFromServerWithTimeout();
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
        print('Fincas cargadas desde SQLite para cosecha: ${localData.length}');
        return localData.map((item) => Finca.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo fincas locales para cosecha: $e');
      return [];
    }
  }

  static Future<List<Finca>> _getFincasFromServerWithTimeout() async {
    return await _executeWithTimeout(() async {
      String query = '''
        SELECT DISTINCT TOP 100 LOCALIDAD as nombre
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
          AND LEN(LOCALIDAD) > 2
        ORDER BY LOCALIDAD
      ''';

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
        print('${data.length} fincas sincronizadas desde servidor para cosecha');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    });
  }

  // ==================== BLOQUES OPTIMIZADO ====================
  
  static Future<List<Bloque>> getBloquesByFinca(String finca) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBloquesByFinca(finca);
      
      if (localData.isNotEmpty) {
        print('Bloques cargados desde SQLite: ${localData.length} para finca $finca');
        List<Bloque> bloques = localData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo bloques de la finca $finca del servidor...');
        return await _getBloquesByFincaFromServerOptimized(finca);
      }

      print('Sin bloques locales ni conexión para finca $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques por finca: $e');
      return [];
    }
  }

  static Future<List<Bloque>> _getBloquesByFincaFromServerOptimized(String finca) async {
    return await _executeWithTimeout(() async {
      String query = '''
        SELECT DISTINCT TOP 200
          CAST(BLOCK as NVARCHAR(50)) as nombre, 
          LOCALIDAD as finca
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD = '$finca'
          AND BLOCK IS NOT NULL 
          AND BLOCK != ''
          AND LEN(BLOCK) > 0
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      data.sort((a, b) => _compareBlockNames(a['nombre'].toString(), b['nombre'].toString()));
      
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
        print('${data.length} bloques sincronizados desde servidor para finca $finca');
      }
      
      return data.map((item) => Bloque.fromJson(item)).toList();
    });
  }

  // ==================== VARIEDADES OPTIMIZADO ====================
  
  static Future<List<Variedad>> getVariedadesByFincaAndBloque(String finca, String bloque) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getVariedadesByFincaAndBloque(finca, bloque);
      
      if (localData.isNotEmpty) {
        print('Variedades cargadas desde SQLite: ${localData.length} para finca $finca, bloque $bloque');
        return localData.map((item) => Variedad.fromJson(item)).toList();
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo variedades específicas del servidor...');
        return await _getVariedadesByFincaAndBloqueOptimized(finca, bloque);
      }

      print('Sin variedades locales ni conexión para finca $finca, bloque $bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo variedades por finca y bloque: $e');
      return [];
    }
  }

  static Future<List<Variedad>> _getVariedadesByFincaAndBloqueOptimized(String finca, String bloque) async {
    return await _executeWithTimeout(() async {
      String query = '''
        SELECT DISTINCT TOP 50
          PRODUCTO as nombre, 
          LOCALIDAD as finca, 
          CAST(BLOCK as NVARCHAR(50)) as bloque
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD = '$finca'
          AND BLOCK = '$bloque'
          AND PRODUCTO IS NOT NULL 
          AND PRODUCTO != ''
          AND LEN(PRODUCTO) > 1
        ORDER BY PRODUCTO
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
        print('${data.length} variedades sincronizadas desde servidor para finca $finca, bloque $bloque');
      }
      
      return data.map((item) => Variedad.fromJson(item)).toList();
    });
  }

  // ==================== SINCRONIZACIÓN INTELIGENTE ====================
  
  static Future<void> _syncVariedadesIntelligent() async {
    try {
      print('Sincronizando variedades con estrategia inteligente...');
      
      // Obtener lista de combinaciones finca-bloque existentes
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> bloques = await dbHelper.getAllBloques();
      
      if (bloques.isEmpty) {
        print('No hay bloques para sincronizar variedades');
        return;
      }

      int totalVariedadesSynced = 0;
      int processedCount = 0;
      
      // Procesar en lotes pequeños para evitar timeouts
      for (int i = 0; i < bloques.length; i += BATCH_SIZE) {
        try {
          List<Map<String, dynamic>> batch = bloques.skip(i).take(BATCH_SIZE).toList();
          
          for (Map<String, dynamic> bloqueData in batch) {
            try {
              String finca = bloqueData['finca'];
              String bloque = bloqueData['nombre'];
              
              print('Procesando variedades para finca: $finca, bloque: $bloque ($processedCount/${bloques.length})');
              
              List<Variedad> variedades = await _getVariedadesByFincaAndBloqueOptimized(finca, bloque);
              totalVariedadesSynced += variedades.length;
              processedCount++;
              
              // Pausa entre consultas para no sobrecargar el servidor
              await Future.delayed(Duration(milliseconds: 200));
              
            } catch (e) {
              print('Error procesando bloque ${bloqueData['finca']}-${bloqueData['nombre']}: $e');
              continue;
            }
          }
          
          // Pausa más larga entre lotes
          if (i + BATCH_SIZE < bloques.length) {
            print('Procesando lote ${(i / BATCH_SIZE).floor() + 1}/${(bloques.length / BATCH_SIZE).ceil()}');
            await Future.delayed(Duration(seconds: 1));
          }
          
        } catch (e) {
          print('Error procesando lote: $e');
          continue;
        }
      }
      
      print('$totalVariedadesSynced variedades sincronizadas desde servidor (INTELIGENTE)');
    } catch (e) {
      print('Error en sincronización inteligente de variedades: $e');
      rethrow;
    }
  }

  // ==================== UTILIDADES DE TIMEOUT ====================
  
  static Future<T> _executeWithTimeout<T>(Future<T> Function() operation) async {
    int retries = 0;
    
    while (retries < MAX_RETRIES) {
      try {
        return await operation().timeout(QUERY_TIMEOUT);
      } catch (e) {
        retries++;
        print('Intento $retries/$MAX_RETRIES falló: $e');
        
        if (retries >= MAX_RETRIES) {
          throw Exception('Operación falló después de $MAX_RETRIES intentos: $e');
        }
        
        // Esperar antes del siguiente intento
        await Future.delayed(RETRY_DELAY);
      }
    }
    
    throw Exception('No se pudo completar la operación');
  }

  // ==================== MÉTODOS PRINCIPALES OPTIMIZADOS ====================
  
  static Future<Map<String, dynamic>> getCosechaDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos de dropdown para cosecha (forceSync: $forceSync)');
      
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada solicitada para cosecha');
        return await _forceSyncOptimized();
      }

      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isEmpty && await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para cosecha, obteniendo del servidor...');
        fincas = await _getFincasFromServerWithTimeout();
      }
      
      print('Fincas cargadas para cosecha: ${fincas.length}');

      return {
        'success': true,
        'fincas': fincas,
        'message': 'Datos de cosecha cargados correctamente'
      };

    } catch (e) {
      print('Error obteniendo datos de cosecha: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error cargando datos de cosecha: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> _forceSyncOptimized() async {
    try {
      print('Iniciando sincronización forzada optimizada de cosecha...');
      
      // Sincronizar fincas
      List<Finca> fincas = await _getFincasFromServerWithTimeout();
      
      // Sincronizar variedades de forma inteligente (bajo demanda)
      // NO sincronizar todo de una vez
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada optimizada de cosecha exitosa'
      };
      
    } catch (e) {
      print('Error en sincronización forzada optimizada de cosecha: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error en sincronización forzada optimizada de cosecha: $e'
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

  // Método para obtener estadísticas sin timeout
  static Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, int> stats = await dbHelper.getCosechaDatabaseStats();
      
      return {
        'local_data': stats,
        'connection_available': await AuthService.hasInternetConnection(),
        'last_check': DateTime.now().toIso8601String(),
        'status': 'healthy',
      };
    } catch (e) {
      return {
        'local_data': {'fincas': 0, 'bloques': 0, 'variedades': 0},
        'connection_available': false,
        'last_check': DateTime.now().toIso8601String(),
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
}

// ==================== APLICACIONES DROPDOWN SERVICE OPTIMIZADO ====================

class AplicacionesDropdownServiceOptimized {
  
  // Configuración de timeouts y límites
  static const Duration QUERY_TIMEOUT = Duration(seconds: 25);
  static const int MAX_RETRIES = 2;
  static const Duration RETRY_DELAY = Duration(seconds: 1);
  static const int BATCH_SIZE = 30;
  
  // ==================== FINCAS OPTIMIZADO ====================
  
  static Future<List<Finca>> getFincas() async {
    try {
      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isNotEmpty) {
        print('Fincas cargadas desde SQLite para aplicaciones: ${fincas.length}');
        return fincas;
      }

      if (await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para aplicaciones, obteniendo del servidor...');
        return await _getFincasFromServerWithTimeout();
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
        print('Fincas aplicaciones cargadas desde SQLite: ${localData.length}');
        return localData.map((item) => Finca.fromJson(item)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo fincas locales para aplicaciones: $e');
      return [];
    }
  }

  static Future<List<Finca>> _getFincasFromServerWithTimeout() async {
    return await _executeWithTimeout(() async {
      String query = '''
        SELECT DISTINCT TOP 50 FINCA as nombre
        FROM Kontrollers.dbo.base_MIPE 
        WHERE FINCA IS NOT NULL 
          AND FINCA != ''
          AND LEN(FINCA) > 2
        ORDER BY FINCA
      ''';

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
        print('${data.length} fincas sincronizadas desde servidor para aplicaciones');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    });
  }

  // ==================== BLOQUES OPTIMIZADO ====================
  
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
        print('Obteniendo bloques de la finca $finca del servidor...');
        return await _getBloquesByFincaFromServerOptimized(finca);
      }

      print('Sin bloques locales ni conexión para finca aplicaciones $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques por finca aplicaciones: $e');
      return [];
    }
  }

  static Future<List<Bloque>> _getBloquesByFincaFromServerOptimized(String finca) async {
    return await _executeWithTimeout(() async {
      String query = '''
        SELECT DISTINCT TOP 100
          CAST(BLOQUE as NVARCHAR(50)) as nombre, 
          FINCA as finca
        FROM Kontrollers.dbo.base_MIPE 
        WHERE FINCA = '$finca'
          AND BLOQUE IS NOT NULL 
          AND BLOQUE != ''
          AND LEN(BLOQUE) > 0
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      data.sort((a, b) => _compareBlockNames(a['nombre'].toString(), b['nombre'].toString()));
      
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
        print('${data.length} bloques aplicaciones sincronizados desde servidor para finca $finca');
      }
      
      return data.map((item) => Bloque.fromJson(item)).toList();
    });
  }

  // ==================== BOMBAS OPTIMIZADO ====================
  
  static Future<List<Bomba>> getBombasByFincaAndBloque(String finca, String bloque) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBombasByFincaAndBloque(finca, bloque);
      
      if (localData.isNotEmpty) {
        print('Bombas cargadas desde SQLite: ${localData.length} para finca $finca, bloque $bloque');
        return localData.map((item) => Bomba.fromJson(item)).toList();
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo bombas específicas del servidor...');
        return await _getBombasByFincaAndBloqueOptimized(finca, bloque);
      }

      print('Sin bombas locales ni conexión para finca $finca, bloque $bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo bombas por finca y bloque: $e');
      return [];
    }
  }

  static Future<List<Bomba>> _getBombasByFincaAndBloqueOptimized(String finca, String bloque) async {
    return await _executeWithTimeout(() async {
      String query = '''
        SELECT DISTINCT TOP 50
          NUMERO_O_CODIGO_DE_LA_BOMBA as nombre, 
          FINCA as finca, 
          CAST(BLOQUE as NVARCHAR(50)) as bloque
        FROM Kontrollers.dbo.base_MIPE 
        WHERE FINCA = '$finca'
          AND BLOQUE = '$bloque'
          AND NUMERO_O_CODIGO_DE_LA_BOMBA IS NOT NULL 
          AND NUMERO_O_CODIGO_DE_LA_BOMBA != ''
          AND LEN(NUMERO_O_CODIGO_DE_LA_BOMBA) > 0
        ORDER BY NUMERO_O_CODIGO_DE_LA_BOMBA
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
        print('${data.length} bombas sincronizadas desde servidor para finca $finca, bloque $bloque');
      }
      
      return data.map((item) => Bomba.fromJson(item)).toList();
    });
  }

  // ==================== UTILIDADES COMPARTIDAS ====================
  
  static Future<T> _executeWithTimeout<T>(Future<T> Function() operation) async {
    int retries = 0;
    
    while (retries < MAX_RETRIES) {
      try {
        return await operation().timeout(QUERY_TIMEOUT);
      } catch (e) {
        retries++;
        print('Intento $retries/$MAX_RETRIES falló: $e');
        
        if (retries >= MAX_RETRIES) {
          throw Exception('Operación falló después de $MAX_RETRIES intentos: $e');
        }
        
        await Future.delayed(RETRY_DELAY);
      }
    }
    
    throw Exception('No se pudo completar la operación');
  }

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

  // ==================== MÉTODOS PRINCIPALES ====================
  
  static Future<Map<String, dynamic>> getAplicacionesDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos de dropdown para aplicaciones (forceSync: $forceSync)');
      
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada solicitada para aplicaciones');
        return await _forceSyncOptimized();
      }

      List<Finca> fincas = await _getFincasFromLocal();
      
      if (fincas.isEmpty && await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para aplicaciones, obteniendo del servidor...');
        fincas = await _getFincasFromServerWithTimeout();
      }
      
      print('Fincas cargadas para aplicaciones: ${fincas.length}');

      return {
        'success': true,
        'fincas': fincas,
        'message': 'Datos de aplicaciones cargados correctamente'
      };

    } catch (e) {
      print('Error obteniendo datos de aplicaciones: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error cargando datos de aplicaciones: $e'
      };
    }
  }

  static Future<Map<String, dynamic>> _forceSyncOptimized() async {
    try {
      print('Iniciando sincronización forzada optimizada de aplicaciones...');
      
      List<Finca> fincas = await _getFincasFromServerWithTimeout();
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada optimizada de aplicaciones exitosa'
      };
      
    } catch (e) {
      print('Error en sincronización forzada optimizada de aplicaciones: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error en sincronización forzada optimizada de aplicaciones: $e'
      };
    }
  }
}