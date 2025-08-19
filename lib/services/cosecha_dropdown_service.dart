// ==================== COSECHA DROPDOWN SERVICE CORREGIDO ====================
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
        print('Fincas cosecha cargadas desde SQLite: ${localData.length}');
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
        SELECT LOCALIDAD as nombre
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
          AND LEN(LOCALIDAD) > 2
        GROUP BY LOCALIDAD
        ORDER BY LOCALIDAD
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Fincas Cosecha'
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
        print('${data.length} fincas cosecha sincronizadas desde servidor');
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
        print('Bloques cosecha cargados desde SQLite: ${localData.length} para finca $finca');
        List<Bloque> bloques = localData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo bloques cosecha de la finca $finca del servidor...');
        return await _getBloquesByFincaFromServerOptimized(finca);
      }

      print('Sin bloques cosecha locales ni conexión para finca $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques cosecha por finca: $e');
      return [];
    }
  }

  static Future<List<Bloque>> _getBloquesByFincaFromServerOptimized(String finca) async {
    return await _executeWithTimeout(() async {
      String escapedFinca = finca.replaceAll("'", "''");
      String query = '''
        SELECT 
          BLOCK as nombre, 
          LOCALIDAD as finca
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD = '$escapedFinca'
          AND BLOCK IS NOT NULL 
          AND BLOCK != ''
          AND LEN(BLOCK) > 0
        GROUP BY BLOCK, LOCALIDAD
        ORDER BY BLOCK
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Bloques Cosecha'
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
        print('${data.length} bloques cosecha sincronizados desde servidor para finca $finca');
      }
      
      return data.map((item) => Bloque.fromJson(item)).toList();
    });
  }

  // Sincronizar todos los bloques para todas las fincas de cosecha
  static Future<void> syncAllBloquesCosecha() async {
    try {
      print('Sincronizando todos los bloques de cosecha...');
      
      // Obtener todas las fincas de cosecha primero
      List<Finca> fincas = await _getFincasFromServerWithTimeout();
      
      if (fincas.isEmpty) {
        print('No hay fincas de cosecha para sincronizar bloques');
        return;
      }

      int totalBloquesSynced = 0;

      // Procesar finca por finca
      for (Finca finca in fincas) {
        try {
          print('Procesando bloques cosecha para finca: ${finca.nombre}');
          
          List<Bloque> bloques = await _getBloquesByFincaFromServerOptimized(finca.nombre);
          totalBloquesSynced += bloques.length;
          
          print('${bloques.length} bloques cosecha sincronizados para finca ${finca.nombre}');

          // Pausa pequeña entre fincas
          await Future.delayed(Duration(milliseconds: 100));
          
        } catch (e) {
          print('Error sincronizando bloques cosecha para finca ${finca.nombre}: $e');
          continue;
        }
      }

      print('Total de bloques cosecha sincronizados: $totalBloquesSynced');
    } catch (e) {
      print('Error en sincronización masiva de bloques cosecha: $e');
      rethrow;
    }
  }

  // ==================== VARIEDADES OPTIMIZADO ====================
  
  static Future<List<Variedad>> getVariedadesByFincaAndBloque(String finca, String bloque) async {
    try {
      print('=== INICIO getVariedadesByFincaAndBloque ===');
      print('Finca: $finca, Bloque: $bloque');
      
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getVariedadesByFincaAndBloque(finca, bloque);
      
      print('Datos locales encontrados: ${localData.length}');
      if (localData.isNotEmpty) {
        print('Variedades cosecha cargadas desde SQLite: ${localData.length} para finca $finca, bloque $bloque');
        List<Variedad> variedadesFromLocal = localData.map((item) => Variedad.fromJson(item)).toList();
        print('Nombres de variedades locales: ${variedadesFromLocal.map((v) => v.nombre).join(', ')}');
        return variedadesFromLocal;
      }

      print('No se encontraron variedades locales para $finca-$bloque, intentando servidor...');

      if (await AuthService.hasInternetConnection()) {
        print('Obteniendo variedades cosecha específicas del servidor...');
        List<Variedad> variedadesFromServer = await _getVariedadesByFincaAndBloqueOptimized(finca, bloque);
        
        if (variedadesFromServer.isNotEmpty) {
          print('${variedadesFromServer.length} variedades obtenidas del servidor y guardadas localmente');
          print('Nombres de variedades del servidor: ${variedadesFromServer.map((v) => v.nombre).join(', ')}');
          return variedadesFromServer;
        } else {
          print('No se encontraron variedades en el servidor para $finca-$bloque');
        }
      } else {
        print('No hay conexión a internet para obtener variedades del servidor');
      }

      print('Sin variedades cosecha locales ni conexión para finca $finca, bloque $bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo variedades cosecha por finca y bloque: $e');
      return [];
    }
  }

  static Future<List<Variedad>> _getVariedadesByFincaAndBloqueOptimized(String finca, String bloque) async {
  return await _executeWithTimeout(() async {
    String escapedFinca = finca.replaceAll("'", "''");
    String escapedBloque = bloque.replaceAll("'", "''");
    
    print('Obteniendo variedades cosecha para $finca-$bloque usando consulta directa...');
    
    String query = '''
      SELECT DISTINCT
        PRODUCTO as nombre, 
        LOCALIDAD as finca, 
        BLOCK as bloque
      FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
      WHERE LOCALIDAD = '$escapedFinca'
        AND BLOCK = '$escapedBloque'
        AND PRODUCTO IS NOT NULL 
        AND PRODUCTO != ''
        AND LEN(PRODUCTO) > 1
        -- ==================== NUEVA CONDICIÓN ====================
        -- Filtra para obtener solo los registros de la fecha más reciente (MAX DT_LOAD)
        -- para la finca y bloque especificados.
        AND DT_LOAD = (
          SELECT MAX(DT_LOAD) 
          FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
          WHERE LOCALIDAD = '$escapedFinca' AND BLOCK = '$escapedBloque'
        )
        -- ==========================================================
      ORDER BY PRODUCTO
    ''';

    print('Query ejecutándose: $query');

    String result = await RobustSqlServerService.executeQueryRobust(
      query, 
      operationName: 'Get Variedades Cosecha Direct'
    );
    
    print('Resultado del servidor recibido, procesando...');
    List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
    
    print('Datos procesados del servidor: ${data.length} registros');
    
    if (data.isNotEmpty) {
      print('Variedades encontradas en el servidor (solo de la última carga):');
      for (var item in data) {
        print('  - ${item['nombre']} (finca: ${item['finca']}, bloque: ${item['bloque']})');
      }
      
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
      print('${data.length} variedades cosecha sincronizadas y guardadas localmente para finca $finca, bloque $bloque');
    } else {
      print('No se encontraron variedades para finca $finca, bloque $bloque en el servidor');
    }
    
    List<Variedad> variedades = data.map((item) => Variedad.fromJson(item)).toList();
    print('=== FIN getVariedadesByFincaAndBloque - Retornando ${variedades.length} variedades ===');
    return variedades;
  });
}

  // ==================== SINCRONIZACIÓN INTELIGENTE DE VARIEDADES ====================
  
  // static Future<void> syncVariedadesIntelligent() async {
  //   try {
  //     print('Sincronizando variedades cosecha con estrategia inteligente...');
      
  //     // Obtener lista de combinaciones finca-bloque existentes
  //     DatabaseHelper dbHelper = DatabaseHelper();
  //     List<Map<String, dynamic>> bloques = await dbHelper.getAllBloques();
      
  //     if (bloques.isEmpty) {
  //       print('No hay bloques para sincronizar variedades cosecha');
  //       return;
  //     }

  //     int totalVariedadesSynced = 0;
  //     int processedCount = 0;
      
  //     // Procesar en lotes pequeños para evitar timeouts
  //     for (int i = 0; i < bloques.length; i += BATCH_SIZE) {
  //       try {
  //         List<Map<String, dynamic>> batch = bloques.skip(i).take(BATCH_SIZE).toList();
          
  //         for (Map<String, dynamic> bloqueData in batch) {
  //           try {
  //             String finca = bloqueData['finca'];
  //             String bloque = bloqueData['nombre'];
              
  //             print('Procesando variedades cosecha para finca: $finca, bloque: $bloque ($processedCount/${bloques.length})');
              
  //             List<Variedad> variedades = await _getVariedadesByFincaAndBloqueOptimized(finca, bloque);
  //             totalVariedadesSynced += variedades.length;
  //             processedCount++;
              
  //             // Pausa entre consultas para no sobrecargar el servidor
  //             await Future.delayed(Duration(milliseconds: 200));
              
  //           } catch (e) {
  //             print('Error procesando bloque cosecha ${bloqueData['finca']}-${bloqueData['nombre']}: $e');
  //             continue;
  //           }
  //         }
          
  //         // Pausa más larga entre lotes
  //         if (i + BATCH_SIZE < bloques.length) {
  //           print('Procesando lote cosecha ${(i / BATCH_SIZE).floor() + 1}/${(bloques.length / BATCH_SIZE).ceil()}');
  //           await Future.delayed(Duration(seconds: 1));
  //         }
          
  //       } catch (e) {
  //         print('Error procesando lote cosecha: $e');
  //         continue;
  //       }
  //     }
      
  //     print('$totalVariedadesSynced variedades cosecha sincronizadas desde servidor (INTELIGENTE)');
  //   } catch (e) {
  //     print('Error en sincronización inteligente de variedades cosecha: $e');
  //     rethrow;
  //   }
  // }

  // ==================== SINCRONIZACIÓN COMPLETA DE COSECHA ====================
  
  static Future<Map<String, dynamic>> syncCosechaData() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {
          'success': false,
          'message': 'No hay conexión a internet'
        };
      }

      print('Iniciando sincronización completa de datos de cosecha...');

      int totalSynced = 0;
      List<String> errors = [];

      // Sincronizar fincas de cosecha
      try {
        List<Finca> fincas = await _getFincasFromServerWithTimeout();
        totalSynced += fincas.length;
        print('Fincas cosecha sincronizadas: ${fincas.length}');
      } catch (e) {
        errors.add('Fincas cosecha: $e');
      }

      // Sincronizar bloques de cosecha
      try {
        await syncAllBloquesCosecha();
        
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getCosechaDatabaseStats();
        totalSynced += stats['bloques'] ?? 0;
        print('Bloques cosecha sincronizados: ${stats['bloques']}');
      } catch (e) {
        errors.add('Bloques cosecha: $e');
      }

      // Sincronizar variedades para fincas principales
      try {
        await _syncVariedadesForMainFincas();
        
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getCosechaDatabaseStats();
        totalSynced += stats['variedades'] ?? 0;
        print('Variedades cosecha sincronizadas: ${stats['variedades']}');
      } catch (e) {
        errors.add('Variedades cosecha: $e');
      }

      if (errors.isEmpty) {
        return {
          'success': true,
          'message': 'Sincronización de datos de cosecha exitosa. $totalSynced registros sincronizados.',
          'count': totalSynced
        };
      } else {
        return {
          'success': false,
          'message': 'Sincronización parcial de cosecha. Errores: ${errors.join(', ')}',
          'count': totalSynced
        };
      }

    } catch (e) {
      print('Error en sincronización completa de cosecha: $e');
      return {
        'success': false,
        'message': 'Error durante la sincronización de cosecha: $e'
      };
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
      
      // Sincronizar fincas de cosecha
      List<Finca> fincas = await _getFincasFromServerWithTimeout();
      
      // Sincronizar bloques de cosecha
      await syncAllBloquesCosecha();
      
      // Sincronizar variedades para las primeras fincas principales
      await _syncVariedadesForMainFincas();
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada optimizada de cosecha exitosa con variedades'
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

  // Sincronizar variedades para las fincas principales
  static Future<void> _syncVariedadesForMainFincas() async {
    try {
      print('Sincronizando variedades para TODAS las fincas principales...');
      
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> bloques = await dbHelper.getAllBloques();
      
      if (bloques.isEmpty) {
        print('No hay bloques para sincronizar variedades');
        return;
      }

      // EN LUGAR DE LIMITAR A 20, sincronizar TODOS los bloques
      // pero con un timeout más agresivo por bloque
      print('Sincronizando variedades para TODOS los ${bloques.length} bloques...');
      
      int totalSynced = 0;
      int errors = 0;
      
      for (int i = 0; i < bloques.length; i++) {
        try {
          Map<String, dynamic> bloqueData = bloques[i];
          String finca = bloqueData['finca'];
          String bloque = bloqueData['nombre'];
          
          print('Sincronizando variedades [$i/${bloques.length}]: $finca-$bloque');
          
          // Usar timeout más corto por bloque individual
          List<Variedad> variedades = await _getVariedadesByFincaAndBloqueOptimized(finca, bloque)
              .timeout(Duration(seconds: 10)); // Timeout de 10 segundos por bloque
          
          totalSynced += variedades.length;
          
          if (variedades.isNotEmpty) {
            print('  -> ${variedades.length} variedades sincronizadas');
          }
          
          // Pausa más corta entre consultas
          await Future.delayed(Duration(milliseconds: 100));
          
        } catch (e) {
          print('Error sincronizando variedades para ${bloques[i]['finca']}-${bloques[i]['nombre']}: $e');
          errors++;
          continue;
        }
      }
      
      print('Sincronización de variedades completada:');
      print('  - Total variedades sincronizadas: $totalSynced');
      print('  - Bloques procesados: ${bloques.length - errors}/${bloques.length}');
      print('  - Errores: $errors');
      
    } catch (e) {
      print('Error en sincronización de variedades principales: $e');
      // No relanzar la excepción para no bloquear toda la sincronización
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

  // Métodos de búsqueda para cosecha (corregidos)
  static Future<List<Finca>> searchFincas(String searchPattern) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.searchFincas(searchPattern);
      return localData.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error buscando fincas cosecha: $e');
      return [];
    }
  }

  static Future<List<Bloque>> searchBloques(String finca, String searchPattern) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.searchBloques(finca, searchPattern);
      return localData.map((item) => Bloque.fromJson(item)).toList();
    } catch (e) {
      print('Error buscando bloques cosecha: $e');
      return [];
    }
  }

  static Future<List<Variedad>> searchVariedades(String finca, String bloque, String searchPattern) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.searchVariedades(finca, bloque, searchPattern);
      return localData.map((item) => Variedad.fromJson(item)).toList();
    } catch (e) {
      print('Error buscando variedades cosecha: $e');
      return [];
    }
  }
  // Agregar este método al final de la clase CosechaDropdownService

// ==================== MÉTODO PÚBLICO PARA SINCRONIZAR TODAS LAS VARIEDADES ====================

static Future<void> syncVariedadesIntelligent() async {
  try {
    print('=== INICIO SINCRONIZACIÓN COMPLETA DE VARIEDADES ===');
    
    // Obtener lista de TODOS los bloques disponibles
    DatabaseHelper dbHelper = DatabaseHelper();
    List<Map<String, dynamic>> bloques = await dbHelper.getAllBloques();
    
    if (bloques.isEmpty) {
      print('No hay bloques para sincronizar variedades');
      return;
    }

    print('Sincronizando variedades para ${bloques.length} bloques...');
    
    int totalVariedadesSynced = 0;
    int processedCount = 0;
    int errorCount = 0;
    
    // Procesar en lotes pequeños para evitar timeouts
    for (int i = 0; i < bloques.length; i += BATCH_SIZE) {
      try {
        List<Map<String, dynamic>> batch = bloques.skip(i).take(BATCH_SIZE).toList();
        
        print('Procesando lote ${(i / BATCH_SIZE).floor() + 1}/${(bloques.length / BATCH_SIZE).ceil()}');
        
        for (Map<String, dynamic> bloqueData in batch) {
          try {
            String finca = bloqueData['finca'];
            String bloque = bloqueData['nombre'];
            
            print('Procesando variedades para finca: $finca, bloque: $bloque ($processedCount/${bloques.length})');
            
            // Usar el método optimizado que ya existe
            List<Variedad> variedades = await _getVariedadesByFincaAndBloqueOptimized(finca, bloque);
            totalVariedadesSynced += variedades.length;
            processedCount++;
            
            if (variedades.isNotEmpty) {
              print('  -> ${variedades.length} variedades sincronizadas para $finca-$bloque');
            } else {
              print('  -> No hay variedades para $finca-$bloque');
            }
            
            // Pausa pequeña entre consultas para no sobrecargar el servidor
            await Future.delayed(Duration(milliseconds: 200));
            
          } catch (e) {
            print('Error procesando bloque ${bloqueData['finca']}-${bloqueData['nombre']}: $e');
            errorCount++;
            continue;
          }
        }
        
        // Pausa más larga entre lotes
        if (i + BATCH_SIZE < bloques.length) {
          print('Esperando antes del siguiente lote...');
          await Future.delayed(Duration(seconds: 1));
        }
        
      } catch (e) {
        print('Error procesando lote: $e');
        errorCount++;
        continue;
      }
    }
    
    print('=== SINCRONIZACIÓN DE VARIEDADES COMPLETADA ===');
    print('Bloques procesados: $processedCount/${bloques.length}');
    print('Total variedades sincronizadas: $totalVariedadesSynced');
    print('Errores encontrados: $errorCount');
    
    if (errorCount > 0) {
      print('ADVERTENCIA: Se encontraron $errorCount errores durante la sincronización');
    }
    
  } catch (e) {
    print('Error en sincronización completa de variedades: $e');
    rethrow;
  }
}

// ==================== MÉTODO ADICIONAL PARA VERIFICAR PROGRESO ====================

static Future<Map<String, dynamic>> getVariedadesSyncStatus() async {
  try {
    DatabaseHelper dbHelper = DatabaseHelper();
    
    // Obtener estadísticas actuales
    List<Map<String, dynamic>> bloques = await dbHelper.getAllBloques();
    Map<String, int> stats = await dbHelper.getCosechaDatabaseStats();
    
    // Calcular cobertura
    int totalBloques = bloques.length;
    int variedadesTotal = stats['variedades'] ?? 0;
    
    // Obtener bloques sin variedades
    List<Map<String, dynamic>> bloquesSinVariedades = [];
    
    for (Map<String, dynamic> bloqueData in bloques) {
      String finca = bloqueData['finca'];
      String bloque = bloqueData['nombre'];
      
      List<Map<String, dynamic>> variedadesBloque = await dbHelper.getVariedadesByFincaAndBloque(finca, bloque);
      
      if (variedadesBloque.isEmpty) {
        bloquesSinVariedades.add({
          'finca': finca,
          'bloque': bloque,
        });
      }
    }
    
    double cobertura = totalBloques > 0 ? (totalBloques - bloquesSinVariedades.length) / totalBloques : 0.0;
    
    return {
      'total_bloques': totalBloques,
      'total_variedades': variedadesTotal,
      'bloques_sin_variedades': bloquesSinVariedades.length,
      'cobertura_porcentaje': (cobertura * 100).toInt(),
      'bloques_faltantes': bloquesSinVariedades,
      'sync_completo': bloquesSinVariedades.isEmpty,
    };
    
  } catch (e) {
    print('Error obteniendo status de sincronización: $e');
    return {
      'error': e.toString(),
      'sync_completo': false,
    };
  }
}
}