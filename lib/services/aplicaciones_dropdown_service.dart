import 'dart:convert';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';

import '../models/dropdown_models.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

class AplicacionesDropdownService {
  
  // ==================== QUERIES OPTIMIZADAS ====================
  
  // Query para obtener fincas desde tabla optimizada
  static String _getFincasQuery() {
    return '''
      SELECT DISTINCT finca as nombre
      FROM aplicaciones_data 
      WHERE activo = 1
      ORDER BY finca
    ''';
  }
  
  // Query CORREGIDA para obtener bloques por finca desde tabla optimizada
  static String _getBloquesByFincaQuery(String finca) {
    String escapedFinca = finca.replaceAll("'", "''");
    return '''
      SELECT DISTINCT 
        bloque as nombre,
        CASE WHEN ISNUMERIC(bloque) = 1 THEN bloque ELSE 999999 END as sort_order
      FROM aplicaciones_data 
      WHERE finca = '$escapedFinca' AND activo = 1
      ORDER BY sort_order, nombre
    ''';
  }
  
  // Query para obtener bombas por finca y bloque desde tabla optimizada
  static String _getBombasByFincaAndBloqueQuery(String finca, String bloque) {
    String escapedFinca = finca.replaceAll("'", "''");
    String escapedBloque = bloque.replaceAll("'", "''");
    return '''
      SELECT bomba as nombre
      FROM aplicaciones_data 
      WHERE finca = '$escapedFinca' AND bloque = '$escapedBloque' AND activo = 1
      ORDER BY 
        CASE WHEN ISNUMERIC(bomba) = 1 THEN bomba ELSE 999999 END,
        bomba
    ''';
  }
  
  // Query para validar combinación desde tabla optimizada
  static String _validateCombinationQuery(String finca, String bloque, String bomba) {
    String escapedFinca = finca.replaceAll("'", "''");
    String escapedBloque = bloque.replaceAll("'", "''");
    String escapedBomba = bomba.replaceAll("'", "''");
    return '''
      SELECT COUNT(*) as count
      FROM aplicaciones_data 
      WHERE finca = '$escapedFinca' 
        AND bloque = '$escapedBloque' 
        AND bomba = '$escapedBomba' 
        AND activo = 1
    ''';
  }

  // ==================== FINCAS ====================
  
  // Obtener fincas (offline first)
  static Future<List<Finca>> getFincas() async {
    try {
      // Primero intentar obtener datos locales
      List<Finca> fincas = await _getFincasFromLocal();
      
      // Si hay datos locales, usarlos
      if (fincas.isNotEmpty) {
        print('Fincas cargadas desde SQLite para aplicaciones: ${fincas.length}');
        return fincas;
      }

      // Si no hay datos locales y hay conexión, intentar obtener del servidor
      if (await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para aplicaciones, obteniendo del servidor...');
        return await _getFincasFromServer();
      }

      // Sin datos locales ni conexión
      print('Sin fincas locales ni conexión para aplicaciones');
      return [];
      
    } catch (e) {
      print('Error obteniendo fincas para aplicaciones: $e');
      return [];
    }
  }

  // Obtener fincas locales
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

  // Obtener fincas del servidor usando tabla optimizada
  static Future<List<Finca>> _getFincasFromServer() async {
    try {
      String query = _getFincasQuery();

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Fincas Aplicaciones Optimizado'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
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
        print('${data.length} fincas sincronizadas desde tabla optimizada');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo fincas del servidor optimizado: $e');
      return [];
    }
  }

  // ==================== BLOQUES (OPTIMIZADO) ====================
  
  // Obtener bloques por finca (offline first)
  static Future<List<Bloque>> getBloquesByFinca(String finca) async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBloquesByFincaAplicaciones(finca);
      
      // Si hay datos locales, usarlos y ordenarlos
      if (localData.isNotEmpty) {
        print('Bloques aplicaciones cargados desde SQLite: ${localData.length} para finca $finca');
        List<Bloque> bloques = localData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      // Si no hay datos locales y hay conexión, cargar desde tabla optimizada
      if (await AuthService.hasInternetConnection()) {
        print('No hay bloques locales aplicaciones, obteniendo desde tabla optimizada...');
        return await _getBloquesByFincaFromServer(finca);
      }

      // Sin datos locales ni conexión
      print('Sin bloques locales ni conexión para finca aplicaciones $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques por finca aplicaciones: $e');
      return [];
    }
  }

  // Obtener bloques desde tabla optimizada
  static Future<List<Bloque>> _getBloquesByFincaFromServer(String finca) async {
    try {
      print('Obteniendo bloques de la finca $finca desde tabla optimizada...');
      
      String query = _getBloquesByFincaQuery(finca);

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Bloques Aplicaciones Optimizado'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> bloqueData in data) {
          Map<String, dynamic> bloque = {
            'nombre': bloqueData['nombre'].toString(),
            'finca': finca,
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateBloqueAplicaciones(bloque);
        }
        print('${data.length} bloques aplicaciones sincronizados desde tabla optimizada para finca $finca');
      }
      
      return data.map((item) => Bloque.fromJson({
        'nombre': item['nombre'],
        'finca': finca,
      })).toList();
    } catch (e) {
      print('Error obteniendo bloques de la finca $finca desde tabla optimizada: $e');
      return [];
    }
  }

  // Sincronizar todos los bloques desde tabla optimizada
  static Future<void> _syncAllBloquesFromServerWithTimeout() async {
    try {
      print('Sincronizando bloques aplicaciones desde tabla optimizada...');
      
      // Obtener todas las fincas primero
      List<Finca> fincas = await _getFincasFromServer();
      
      if (fincas.isEmpty) {
        print('No hay fincas para sincronizar bloques');
        return;
      }

      int totalBloquesSynced = 0;
      DatabaseHelper dbHelper = DatabaseHelper();

      // Procesar finca por finca
      for (Finca finca in fincas) {
        try {
          print('Procesando bloques para finca: ${finca.nombre}');
          
          String query = _getBloquesByFincaQuery(finca.nombre);

          String result = await RobustSqlServerService.executeQueryRobust(
            query, 
            operationName: 'Sync Bloques ${finca.nombre}'
          );
          List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
          
          // Guardar bloques de esta finca
          for (Map<String, dynamic> bloqueData in data) {
            Map<String, dynamic> bloque = {
              'nombre': bloqueData['nombre'].toString(),
              'finca': finca.nombre,
              'activo': 1,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            };
            await dbHelper.insertOrUpdateBloqueAplicaciones(bloque);
            totalBloquesSynced++;
          }
          
          print('${data.length} bloques sincronizados para finca ${finca.nombre}');
          
          // Pequeña pausa entre fincas
          await Future.delayed(Duration(milliseconds: 300));
          
        } catch (e) {
          print('Error procesando finca ${finca.nombre}: $e');
          continue;
        }
      }
      
      print('$totalBloquesSynced bloques aplicaciones sincronizados desde tabla optimizada');
    } catch (e) {
      print('Error sincronizando bloques aplicaciones: $e');
      rethrow;
    }
  }

  // ==================== BOMBAS (OPTIMIZADO) ====================
  
  // Obtener bombas por finca y bloque (offline first)
  static Future<List<Bomba>> getBombasByFincaAndBloque(String finca, String bloque) async {
    try {
      // Primero verificar cache local con timestamp
      return await _getBombasByFincaAndBloqueWithCache(finca, bloque);
    } catch (e) {
      print('Error obteniendo bombas por finca y bloque: $e');
      return [];
    }
  }

  // Método con cache inteligente
  static Future<List<Bomba>> _getBombasByFincaAndBloqueWithCache(String finca, String bloque) async {
    try {
      // Primero verificar cache local con timestamp
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBombasByFincaAndBloque(finca, bloque);
      
      // Si hay datos locales y son recientes (menos de 1 hora), usarlos
      if (localData.isNotEmpty) {
        DateTime? lastUpdate = DateTime.tryParse(localData.first['fecha_actualizacion'] ?? '');
        if (lastUpdate != null && DateTime.now().difference(lastUpdate).inHours < 1) {
          print('Usando cache local de bombas (actualizado hace ${DateTime.now().difference(lastUpdate).inMinutes} minutos)');
          List<Bomba> bombas = localData.map((item) => Bomba.fromJson(item)).toList();
          bombas.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
          return bombas;
        }
      }

      // Si no hay cache válido y hay conexión, obtener desde tabla optimizada
      if (await AuthService.hasInternetConnection()) {
        print('Cache inválido o no existe, obteniendo bombas desde tabla optimizada...');
        return await _getBombasByFincaAndBloqueFromServerOptimized(finca, bloque);
      }

      // Sin datos locales ni conexión
      print('Sin bombas locales ni conexión para finca $finca, bloque $bloque');
      return [];
    } catch (e) {
      print('Error en getBombasByFincaAndBloqueWithCache: $e');
      return [];
    }
  }

  // Obtener bombas desde tabla optimizada (SÚPER RÁPIDO)
  static Future<List<Bomba>> _getBombasByFincaAndBloqueFromServerOptimized(String finca, String bloque) async {
    try {
      print('Obteniendo bombas específicas desde tabla optimizada para finca $finca, bloque $bloque');
      
      String query = _getBombasByFincaAndBloqueQuery(finca, bloque);

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Bombas Optimizado'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite con timestamp actualizado
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> bombaData in data) {
          Map<String, dynamic> bomba = {
            'nombre': bombaData['nombre'],
            'finca': finca,
            'bloque': bloque,
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateBomba(bomba);
        }
        print('${data.length} bombas sincronizadas desde tabla optimizada');
      }
      
      return data.map((item) => Bomba.fromJson({
        'nombre': item['nombre'],
        'finca': finca,
        'bloque': bloque,
      })).toList();
    } catch (e) {
      print('Error obteniendo bombas desde tabla optimizada: $e');
      return [];
    }
  }

  // Sincronizar todas las bombas desde tabla optimizada
  static Future<void> _syncAllBombasFromServerWithTimeout() async {
    try {
      print('Sincronizando bombas aplicaciones desde tabla optimizada...');
      
      // Obtener todas las combinaciones finca-bloque
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> bloques = await dbHelper.getAllBloquesAplicaciones();
      
      if (bloques.isEmpty) {
        print('No hay bloques para sincronizar bombas');
        return;
      }

      int totalBombasSynced = 0;

      // Procesar bloque por bloque
      for (Map<String, dynamic> bloqueData in bloques) {
        try {
          String finca = bloqueData['finca'];
          String bloque = bloqueData['nombre'];
          
          print('Procesando bombas para finca: $finca, bloque: $bloque');
          
          String query = _getBombasByFincaAndBloqueQuery(finca, bloque);

          String result = await RobustSqlServerService.executeQueryRobust(
            query, 
            operationName: 'Sync Bombas $finca-$bloque'
          );
          List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
          
          // Guardar bombas de este bloque
          for (Map<String, dynamic> bombaData in data) {
            Map<String, dynamic> bomba = {
              'nombre': bombaData['nombre'],
              'finca': finca,
              'bloque': bloque,
              'activo': 1,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            };
            await dbHelper.insertOrUpdateBomba(bomba);
            totalBombasSynced++;
          }
          
          print('${data.length} bombas sincronizadas para finca $finca, bloque $bloque');
          
          // Pequeña pausa entre bloques
          await Future.delayed(Duration(milliseconds: 200));
          
        } catch (e) {
          print('Error procesando bloque ${bloqueData['finca']}-${bloqueData['nombre']}: $e');
          continue;
        }
      }
      
      print('$totalBombasSynced bombas aplicaciones sincronizadas desde tabla optimizada');
    } catch (e) {
      print('Error sincronizando bombas aplicaciones: $e');
      rethrow;
    }
  }

  // ==================== MÉTODOS PRINCIPALES (OPTIMIZADOS) ====================

  // Obtener todos los datos necesarios para el checklist de aplicaciones
  static Future<Map<String, dynamic>> getAplicacionesDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos de dropdown para aplicaciones (forceSync: $forceSync)');
      
      // Si se requiere sincronización forzada y hay conexión
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada solicitada para aplicaciones');
        return await _forceSyncOptimized();
      }

      // Obtener fincas (usar método local primero)
      List<Finca> fincas = await _getFincasFromLocal();
      
      // Si no hay fincas locales, intentar obtener del servidor
      if (fincas.isEmpty && await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para aplicaciones, obteniendo del servidor...');
        fincas = await _getFincasFromServer();
        print('Fincas cargadas, bloques y bombas se cargarán bajo demanda');
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

  // Sincronización forzada optimizada
  static Future<Map<String, dynamic>> _forceSyncOptimized() async {
    try {
      print('Iniciando sincronización forzada optimizada desde tabla aplicaciones_data...');
      
      // Sincronizar fincas
      List<Finca> fincas = await _getFincasFromServer();
      
      // Sincronizar bloques desde tabla optimizada
      await _syncAllBloquesFromServerWithTimeout();
      
      // Opcionalmente sincronizar bombas (comentado por defecto para evitar sobrecarga)
      // await _syncAllBombasFromServerWithTimeout();
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada optimizada completada usando tabla aplicaciones_data'
      };
      
    } catch (e) {
      print('Error en sincronización forzada optimizada: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error en sincronización forzada optimizada: $e'
      };
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  // Sincronizar todos los datos de aplicaciones usando tabla optimizada
  static Future<Map<String, dynamic>> syncAplicacionesData() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {
          'success': false,
          'message': 'No hay conexión a internet'
        };
      }

      print('Iniciando sincronización completa desde tabla aplicaciones_data...');

      int totalSynced = 0;
      List<String> errors = [];

      // Sincronizar fincas
      try {
        List<Finca> fincas = await _getFincasFromServer();
        totalSynced += fincas.length;
        print('Fincas sincronizadas: ${fincas.length}');
      } catch (e) {
        errors.add('Fincas aplicaciones: $e');
      }

      // Sincronizar bloques
      try {
        await _syncAllBloquesFromServerWithTimeout();
        
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getAplicacionesDatabaseStats();
        totalSynced += stats['bloques'] ?? 0;
        print('Bloques sincronizados: ${stats['bloques']}');
      } catch (e) {
        errors.add('Bloques aplicaciones: $e');
      }

      // Sincronizar bombas (deshabilitado - ya no se sincronizan las bombas)
      // try {
      //   await _syncAllBombasFromServerWithTimeout();
      //   
      //   DatabaseHelper dbHelper = DatabaseHelper();
      //   Map<String, int> stats = await dbHelper.getAplicacionesDatabaseStats();
      //   totalSynced += stats['bombas'] ?? 0;
      //   print('Bombas sincronizadas: ${stats['bombas']}');
      // } catch (e) {
      //   errors.add('Bombas aplicaciones: $e');
      // }

      if (errors.isEmpty) {
        return {
          'success': true,
          'message': 'Sincronización desde tabla aplicaciones_data exitosa. $totalSynced registros sincronizados.',
          'count': totalSynced
        };
      } else {
        return {
          'success': false,
          'message': 'Sincronización parcial. Errores: ${errors.join(', ')}',
          'count': totalSynced
        };
      }

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante la sincronización: $e'
      };
    }
  }

  // ==================== MÉTODOS HELPER ====================

  // Método helper para comparar nombres numéricamente
  static int _compareBlockNames(String a, String b) {
    int? numA = int.tryParse(a);
    int? numB = int.tryParse(b);
    
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    
    if (numA != null && numB == null) return -1;
    if (numA == null && numB != null) return 1;
    
    return a.compareTo(b);
  }

  // ==================== MÉTODOS DE BÚSQUEDA ====================

  // Buscar finca por nombre (offline first)
  static Future<Finca?> getFincaByNombre(String nombre) async {
    try {
      // Primero buscar localmente
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localData = await dbHelper.getFincaAplicacionesByNombre(nombre);
      
      if (localData != null) {
        return Finca.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Finca> fincas = await _getFincasFromServer();
        return fincas.firstWhere(
          (finca) => finca.nombre == nombre,
          orElse: () => throw Exception('Finca aplicaciones no encontrada'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando finca aplicaciones por nombre: $e');
      return null;
    }
  }

  // Validar si existe una combinación finca-bloque-bomba usando tabla optimizada
  static Future<bool> validateCombination(String finca, String bloque, String bomba) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Verificar si la combinación existe localmente
      Map<String, dynamic>? result = await dbHelper.getBombaByNombre(bomba, finca, bloque);
      
      if (result != null) {
        return true;
      }

      // Si no existe localmente y hay conexión, verificar en tabla optimizada
      if (await AuthService.hasInternetConnection()) {
        String query = _validateCombinationQuery(finca, bloque, bomba);

        String result = await RobustSqlServerService.executeQueryRobust(
          query, 
          operationName: 'Validate Combination Optimizado'
        );
        List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
        
        if (data.isNotEmpty) {
          int count = data.first['count'] ?? 0;
          return count > 0;
        }
      }

      return false;
    } catch (e) {
      print('Error validando combinación finca-bloque-bomba aplicaciones: $e');
      return false;
    }
  }

  // ==================== MÉTODOS DE ESTADÍSTICAS Y LIMPIEZA ====================

  // Obtener estadísticas de datos locales
  static Future<Map<String, int>> getLocalAplicacionesStats() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      return await dbHelper.getAplicacionesDatabaseStats();
    } catch (e) {
      print('Error obteniendo estadísticas de aplicaciones: $e');
      return {
        'fincas': 0,
        'bloques': 0,
        'bombas': 0,
      };
    }
  }

  // Limpiar todos los datos locales de aplicaciones
  static Future<void> clearLocalAplicacionesData() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.clearFincasAplicaciones();
      await dbHelper.clearBloquesAplicaciones();
      await dbHelper.clearBombas();
      print('Datos locales de aplicaciones limpiados');
    } catch (e) {
      print('Error limpiando datos locales de aplicaciones: $e');
      rethrow;
    }
  }

  // ==================== MÉTODOS DE OPTIMIZACIÓN ====================
  
  // Obtener estadísticas de la tabla optimizada en servidor
  static Future<Map<String, dynamic>> getOptimizedTableStats() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {'error': 'Sin conexión a internet'};
      }

      String query = '''
        SELECT 
          COUNT(*) as total_registros,
          COUNT(DISTINCT finca) as total_fincas,
          COUNT(DISTINCT CONCAT(finca, '-', bloque)) as total_bloques,
          MAX(fecha_actualizacion) as ultima_actualizacion
        FROM aplicaciones_data 
        WHERE activo = 1
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Optimized Table Stats'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.isNotEmpty ? data.first : {};
    } catch (e) {
      print('Error obteniendo estadísticas de tabla optimizada: $e');
      return {'error': e.toString()};
    }
  }

  // Actualizar tabla optimizada en servidor (solo para administradores)
  static Future<Map<String, dynamic>> updateOptimizedTable() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {
          'success': false,
          'message': 'Sin conexión a internet'
        };
      }

      String query = 'EXEC sp_update_aplicaciones_data';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Update Optimized Table'
      );
      
      return {
        'success': true,
        'message': 'Tabla aplicaciones_data actualizada exitosamente',
        'result': result
      };
    } catch (e) {
      print('Error actualizando tabla optimizada: $e');
      return {
        'success': false,
        'message': 'Error actualizando tabla optimizada: $e'
      };
    }
  }

  // Método para verificar el estado de sincronización
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, int> stats = await dbHelper.getAplicacionesDatabaseStats();
      
      return {
        'fincas': stats['fincas'] ?? 0,
        'bloques': stats['bloques'] ?? 0,
        'bombas': stats['bombas'] ?? 0,
        'lastSync': DateTime.now().toIso8601String(),
        'optimized': true,
        'source': 'aplicaciones_data table'
      };
    } catch (e) {
      print('Error obteniendo estado de sincronización: $e');
      return {
        'fincas': 0,
        'bloques': 0,
        'bombas': 0,
        'lastSync': null,
        'optimized': false,
        'error': e.toString()
      };
    }
  }

  // ==================== MÉTODOS DE PRECARGA (LAZY LOADING) ====================

  // Precargar datos para una finca específica
  static Future<void> preloadDataForFinca(String finca) async {
    try {
      print('Precargando datos para finca $finca desde tabla optimizada...');
      
      // Cargar bloques de la finca
      await _getBloquesByFincaFromServer(finca);
      
      print('Datos precargados para finca $finca');
    } catch (e) {
      print('Error precargando datos para finca $finca: $e');
    }
  }

  // Precargar bombas para una combinación específica
  static Future<void> preloadBombasForFincaAndBloque(String finca, String bloque) async {
    try {
      print('Precargando bombas para finca $finca, bloque $bloque desde tabla optimizada...');
      
      // Cargar bombas específicas usando la versión optimizada
      await _getBombasByFincaAndBloqueFromServerOptimized(finca, bloque);
      
      print('Bombas precargadas para finca $finca, bloque $bloque');
    } catch (e) {
      print('Error precargando bombas para finca $finca, bloque $bloque: $e');
    }
  }

  // ==================== MÉTODOS DE BÚSQUEDA AVANZADA ====================

  // Buscar fincas por patrón de texto
  static Future<List<Finca>> searchFincasAplicaciones(String searchPattern) async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        // Buscar localmente si no hay conexión
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> localData = await dbHelper.searchFincasAplicaciones(searchPattern);
        return localData.map((item) => Finca.fromJson(item)).toList();
      }

      String escapedPattern = searchPattern.replaceAll("'", "''");
      String query = '''
        SELECT DISTINCT finca as nombre
        FROM aplicaciones_data 
        WHERE finca LIKE '%$escapedPattern%' AND activo = 1
        ORDER BY finca
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Search Fincas'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error buscando fincas: $e');
      return [];
    }
  }

  // Buscar bloques por patrón de texto en una finca
  static Future<List<Bloque>> searchBloquesAplicaciones(String finca, String searchPattern) async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        // Buscar localmente si no hay conexión
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> localData = await dbHelper.searchBloquesAplicaciones(finca, searchPattern);
        return localData.map((item) => Bloque.fromJson(item)).toList();
      }

      String escapedFinca = finca.replaceAll("'", "''");
      String escapedPattern = searchPattern.replaceAll("'", "''");
      String query = '''
        SELECT DISTINCT bloque as nombre
        FROM aplicaciones_data 
        WHERE finca = '$escapedFinca' 
          AND bloque LIKE '%$escapedPattern%' 
          AND activo = 1
        ORDER BY 
          CASE WHEN ISNUMERIC(bloque) = 1 THEN bloque ELSE 999999 END,
          bloque
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Search Bloques'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.map((item) => Bloque.fromJson({
        'nombre': item['nombre'],
        'finca': finca,
      })).toList();
    } catch (e) {
      print('Error buscando bloques: $e');
      return [];
    }
  }

  // Buscar bombas por patrón de texto
  static Future<List<Bomba>> searchBombas(String finca, String bloque, String searchPattern) async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        // Buscar localmente si no hay conexión
        DatabaseHelper dbHelper = DatabaseHelper();
        List<Map<String, dynamic>> localData = await dbHelper.searchBombas(finca, bloque, searchPattern);
        return localData.map((item) => Bomba.fromJson(item)).toList();
      }

      String escapedFinca = finca.replaceAll("'", "''");
      String escapedBloque = bloque.replaceAll("'", "''");
      String escapedPattern = searchPattern.replaceAll("'", "''");
      String query = '''
        SELECT bomba as nombre
        FROM aplicaciones_data 
        WHERE finca = '$escapedFinca' 
          AND bloque = '$escapedBloque' 
          AND bomba LIKE '%$escapedPattern%' 
          AND activo = 1
        ORDER BY 
          CASE WHEN ISNUMERIC(bomba) = 1 THEN bomba ELSE 999999 END,
          bomba
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Search Bombas'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.map((item) => Bomba.fromJson({
        'nombre': item['nombre'],
        'finca': finca,
        'bloque': bloque,
      })).toList();
    } catch (e) {
      print('Error buscando bombas: $e');
      return [];
    }
  }

  // ==================== MÉTODOS DE VALIDACIÓN Y DIAGNÓSTICO ====================

  // Verificar la salud de la tabla optimizada
  static Future<Map<String, dynamic>> checkOptimizedTableHealth() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {
          'healthy': false,
          'error': 'Sin conexión a internet'
        };
      }

      String query = '''
        SELECT 
          COUNT(*) as total_records,
          COUNT(DISTINCT finca) as unique_fincas,
          COUNT(DISTINCT CONCAT(finca, '-', bloque)) as unique_bloques,
          COUNT(DISTINCT CONCAT(finca, '-', bloque, '-', bomba)) as unique_bombas,
          MIN(fecha_actualizacion) as oldest_record,
          MAX(fecha_actualizacion) as newest_record,
          CASE 
            WHEN COUNT(*) > 0 THEN 1 
            ELSE 0 
          END as has_data
        FROM aplicaciones_data 
        WHERE activo = 1
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Check Table Health'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      if (data.isNotEmpty) {
        Map<String, dynamic> stats = data.first;
        return {
          'healthy': stats['has_data'] == 1 && stats['total_records'] > 0,
          'stats': stats,
          'recommendations': _generateHealthRecommendations(stats)
        };
      }

      return {
        'healthy': false,
        'error': 'No se pudieron obtener estadísticas'
      };
    } catch (e) {
      print('Error verificando salud de tabla optimizada: $e');
      return {
        'healthy': false,
        'error': e.toString()
      };
    }
  }

  // Generar recomendaciones basadas en las estadísticas
  static List<String> _generateHealthRecommendations(Map<String, dynamic> stats) {
    List<String> recommendations = [];
    
    int totalRecords = stats['total_records'] ?? 0;
    int uniqueFincas = stats['unique_fincas'] ?? 0;
    int uniqueBloques = stats['unique_bloques'] ?? 0;
    
    if (totalRecords == 0) {
      recommendations.add('La tabla aplicaciones_data está vacía. Ejecutar sp_update_aplicaciones_data.');
    } else if (totalRecords < 100) {
      recommendations.add('Pocos registros en la tabla. Verificar si la sincronización es completa.');
    }
    
    if (uniqueFincas < 5) {
      recommendations.add('Pocas fincas encontradas. Verificar datos de origen en base_MIPE.');
    }
    
    if (uniqueBloques < uniqueFincas) {
      recommendations.add('Posibles fincas sin bloques. Revisar integridad de datos.');
    }
    
    // Verificar edad de los datos
    String? newestRecord = stats['newest_record'];
    if (newestRecord != null) {
      try {
        DateTime newest = DateTime.parse(newestRecord);
        int daysSinceUpdate = DateTime.now().difference(newest).inDays;
        
        if (daysSinceUpdate > 7) {
          recommendations.add('Datos antiguos (${daysSinceUpdate} días). Considerar actualizar la tabla.');
        } else if (daysSinceUpdate > 1) {
          recommendations.add('Datos de hace $daysSinceUpdate días. Actualización opcional.');
        }
      } catch (e) {
        recommendations.add('Error verificando fecha de actualización.');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('La tabla aplicaciones_data está en buen estado.');
    }
    
    return recommendations;
  }

  // ==================== MÉTODOS DE MONITOREO Y PERFORMANCE ====================

  // Medir tiempo de respuesta de queries
  static Future<Map<String, dynamic>> benchmarkQueries() async {
    Map<String, dynamic> results = {
      'timestamp': DateTime.now().toIso8601String(),
      'benchmarks': {}
    };

    try {
      if (!await AuthService.hasInternetConnection()) {
        results['error'] = 'Sin conexión a internet';
        return results;
      }

      // Benchmark query de fincas
      Stopwatch stopwatch = Stopwatch()..start();
      await _getFincasFromServer();
      stopwatch.stop();
      results['benchmarks']['fincas_ms'] = stopwatch.elapsedMilliseconds;

      // Benchmark query de bloques (usando primera finca disponible)
      List<Finca> fincas = await _getFincasFromLocal();
      if (fincas.isNotEmpty) {
        stopwatch.reset();
        stopwatch.start();
        await _getBloquesByFincaFromServer(fincas.first.nombre);
        stopwatch.stop();
        results['benchmarks']['bloques_ms'] = stopwatch.elapsedMilliseconds;

        // Benchmark query de bombas (usando primer bloque disponible)
        List<Bloque> bloques = await getBloquesByFinca(fincas.first.nombre);
        if (bloques.isNotEmpty) {
          stopwatch.reset();
          stopwatch.start();
          await _getBombasByFincaAndBloqueFromServerOptimized(fincas.first.nombre, bloques.first.nombre);
          stopwatch.stop();
          results['benchmarks']['bombas_ms'] = stopwatch.elapsedMilliseconds;
        }
      }

      // Calcular performance score
      int totalTime = (results['benchmarks']['fincas_ms'] ?? 0) +
                     (results['benchmarks']['bloques_ms'] ?? 0) +
                     (results['benchmarks']['bombas_ms'] ?? 0);
      
      String performanceScore;
      if (totalTime < 1000) {
        performanceScore = 'Excelente';
      } else if (totalTime < 3000) {
        performanceScore = 'Bueno';
      } else if (totalTime < 5000) {
        performanceScore = 'Regular';
      } else {
        performanceScore = 'Lento';
      }
      
      results['performance_score'] = performanceScore;
      results['total_time_ms'] = totalTime;

    } catch (e) {
      results['error'] = 'Error durante benchmark: $e';
    }

    return results;
  }

  // ==================== MÉTODOS DE CONFIGURACIÓN ====================

  // Configurar comportamiento del servicio
  static void configureService({
    Duration? cacheExpiration,
    bool? enablePrefetch,
    bool? enableBenchmarking
  }) {
    print('Configurando AplicacionesDropdownService:');
    print('- Cache expiration: ${cacheExpiration ?? "1 hora (default)"}');
    print('- Enable prefetch: ${enablePrefetch ?? "true (default)"}');
    print('- Enable benchmarking: ${enableBenchmarking ?? "false (default)"}');
    
    // Aquí puedes implementar la lógica real de configuración
    // Por ejemplo, guardar en SharedPreferences
  }

  // Obtener información de configuración actual
  static Map<String, dynamic> getServiceInfo() {
    return {
      'service_name': 'AplicacionesDropdownService',
      'version': '2.0.0-optimized',
      'data_source': 'aplicaciones_data table',
      'features': [
        'Tabla optimizada',
        'Cache inteligente',
        'Lazy loading',
        'Búsqueda avanzada',
        'Benchmarking',
        'Health checks'
      ],
      'performance': {
        'cache_duration': '1 hour',
        'offline_support': true,
        'auto_retry': true,
        'timeout_handling': true
      }
    };
  }
}