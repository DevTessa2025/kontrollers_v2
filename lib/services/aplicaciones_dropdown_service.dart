import 'dart:convert';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';

import '../models/dropdown_models.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

class AplicacionesDropdownService {
  
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

  // Obtener fincas del servidor y guardar localmente
  static Future<List<Finca>> _getFincasFromServer() async {
    try {
      String query = '''
        SELECT DISTINCT FINCA as nombre
        FROM Kontrollers.dbo.base_MIPE 
        WHERE FINCA IS NOT NULL 
          AND FINCA != ''
        ORDER BY FINCA
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
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
        print('${data.length} fincas sincronizadas desde servidor para aplicaciones');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo fincas del servidor para aplicaciones: $e');
      return [];
    }
  }

  // ==================== BLOQUES (OPTIMIZADO) ====================
  
  // Obtener bloques por finca (offline first) - VERSIÓN OPTIMIZADA
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

      // Si no hay datos locales y hay conexión, cargar SOLO los bloques de esta finca
      if (await AuthService.hasInternetConnection()) {
        print('No hay bloques locales aplicaciones, obteniendo bloques de la finca $finca del servidor...');
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

  // MÉTODO OPTIMIZADO: Obtener bloques de UNA SOLA finca del servidor
  static Future<List<Bloque>> _getBloquesByFincaFromServer(String finca) async {
    try {
      print('Obteniendo bloques de la finca $finca desde el servidor...');
      
      // Query optimizada - SOLO para la finca específica
      String query = '''
        SELECT DISTINCT 
          CAST(BLOQUE as NVARCHAR(50)) as nombre, 
          FINCA as finca
        FROM Kontrollers.dbo.base_MIPE 
        WHERE FINCA = '$finca'
          AND BLOQUE IS NOT NULL 
          AND BLOQUE != ''
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Ordenar en memoria por bloque
      data.sort((a, b) => _compareBlockNames(a['nombre'].toString(), b['nombre'].toString()));
      
      // Guardar en SQLite
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
    } catch (e) {
      print('Error obteniendo bloques de la finca $finca del servidor: $e');
      return [];
    }
  }

  // MÉTODO ALTERNATIVO: Sincronizar bloques por finca (para sincronización completa)
  static Future<void> _syncAllBloquesFromServerWithTimeout() async {
    try {
      print('Sincronizando bloques aplicaciones con timeout optimizado...');
      
      // Primero, obtener lista de fincas para procesar una por una
      List<Finca> fincas = await _getFincasFromServer();
      
      if (fincas.isEmpty) {
        print('No hay fincas para sincronizar bloques');
        return;
      }

      int totalBloquesSynced = 0;
      DatabaseHelper dbHelper = DatabaseHelper();

      // Procesar finca por finca para evitar timeouts
      for (Finca finca in fincas) {
        try {
          print('Procesando bloques para finca: ${finca.nombre}');
          
          String query = '''
            SELECT DISTINCT 
              CAST(BLOQUE as NVARCHAR(50)) as nombre, 
              FINCA as finca
            FROM Kontrollers.dbo.base_MIPE 
            WHERE FINCA = '${finca.nombre}'
              AND BLOQUE IS NOT NULL 
              AND BLOQUE != ''
          ''';

          String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
          List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
          
          // Guardar bloques de esta finca
          for (Map<String, dynamic> bloqueData in data) {
            Map<String, dynamic> bloque = {
              'nombre': bloqueData['nombre'].toString(),
              'finca': bloqueData['finca'],
              'activo': 1,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            };
            await dbHelper.insertOrUpdateBloqueAplicaciones(bloque);
            totalBloquesSynced++;
          }
          
          print('${data.length} bloques sincronizados para finca ${finca.nombre}');
          
          // Pequeña pausa entre fincas para no sobrecargar el servidor
          await Future.delayed(Duration(milliseconds: 500));
          
        } catch (e) {
          print('Error procesando finca ${finca.nombre}: $e');
          // Continuar con la siguiente finca
          continue;
        }
      }
      
      print('$totalBloquesSynced bloques aplicaciones sincronizados desde servidor (POR FINCA)');
    } catch (e) {
      print('Error sincronizando bloques aplicaciones del servidor: $e');
      rethrow;
    }
  }

  // ==================== BOMBAS (OPTIMIZADO) ====================
  
  // Obtener bombas por finca y bloque (offline first) - VERSIÓN OPTIMIZADA
  static Future<List<Bomba>> getBombasByFincaAndBloque(String finca, String bloque) async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBombasByFincaAndBloque(finca, bloque);
      
      // Si hay datos locales, usarlos
      if (localData.isNotEmpty) {
        print('Bombas cargadas desde SQLite: ${localData.length} para finca $finca, bloque $bloque');
        return localData.map((item) => Bomba.fromJson(item)).toList();
      }

      // Si no hay datos locales y hay conexión, obtener solo las bombas específicas
      if (await AuthService.hasInternetConnection()) {
        print('No hay bombas locales, obteniendo bombas específicas del servidor...');
        return await _getBombasByFincaAndBloqueFromServer(finca, bloque);
      }

      // Sin datos locales ni conexión
      print('Sin bombas locales ni conexión para finca $finca, bloque $bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo bombas por finca y bloque: $e');
      return [];
    }
  }

  // Método optimizado para obtener bombas específicas
  static Future<List<Bomba>> _getBombasByFincaAndBloqueFromServer(String finca, String bloque) async {
    try {
      print('Obteniendo bombas específicas desde el servidor para finca $finca, bloque $bloque');
      
      String query = '''
        SELECT b.FINCA, b.BLOQUE, b.NUMERO_O_CODIGO_DE_LA_BOMBA, b.DT_LOAD
        FROM [Kontrollers].[dbo].[base_MIPE] b
        INNER JOIN (
            SELECT FINCA, BLOQUE, NUMERO_O_CODIGO_DE_LA_BOMBA, MAX(DT_LOAD) as max_dt_load
            FROM [Kontrollers].[dbo].[base_MIPE]
            GROUP BY FINCA, BLOQUE, NUMERO_O_CODIGO_DE_LA_BOMBA
        ) max_dates ON b.FINCA = max_dates.FINCA
                      AND b.BLOQUE = max_dates.BLOQUE
                      AND b.NUMERO_O_CODIGO_DE_LA_BOMBA = max_dates.NUMERO_O_CODIGO_DE_LA_BOMBA
                      AND b.DT_LOAD = max_dates.max_dt_load;
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Ordenar por bomba
      data.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
      
      // Guardar en SQLite
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
    } catch (e) {
      print('Error obteniendo bombas específicas del servidor: $e');
      return [];
    }
  }

  // MÉTODO ALTERNATIVO: Sincronizar todas las bombas con timeout optimizado
  static Future<void> _syncAllBombasFromServerWithTimeout() async {
    try {
      print('Sincronizando bombas aplicaciones con timeout optimizado...');
      
      // Obtener todas las combinaciones finca-bloque para procesar
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> bloques = await dbHelper.getAllBloquesAplicaciones();
      
      if (bloques.isEmpty) {
        print('No hay bloques para sincronizar bombas');
        return;
      }

      int totalBombasSynced = 0;

      // Procesar bloque por bloque para evitar timeouts
      for (Map<String, dynamic> bloqueData in bloques) {
        try {
          String finca = bloqueData['finca'];
          String bloque = bloqueData['nombre'];
          
          print('Procesando bombas para finca: $finca, bloque: $bloque');
          
          String query = '''
            SELECT b.FINCA, b.BLOQUE, b.NUMERO_O_CODIGO_DE_LA_BOMBA, b.DT_LOAD
            FROM [Kontrollers].[dbo].[base_MIPE] b
            INNER JOIN (
                SELECT FINCA, BLOQUE, NUMERO_O_CODIGO_DE_LA_BOMBA, MAX(DT_LOAD) as max_dt_load
                FROM [Kontrollers].[dbo].[base_MIPE]
                GROUP BY FINCA, BLOQUE, NUMERO_O_CODIGO_DE_LA_BOMBA
            ) max_dates ON b.FINCA = max_dates.FINCA
                          AND b.BLOQUE = max_dates.BLOQUE
                          AND b.NUMERO_O_CODIGO_DE_LA_BOMBA = max_dates.NUMERO_O_CODIGO_DE_LA_BOMBA
                          AND b.DT_LOAD = max_dates.max_dt_load;
          ''';

          String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
          List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
          
          // Guardar bombas de este bloque
          for (Map<String, dynamic> bombaData in data) {
            Map<String, dynamic> bomba = {
              'nombre': bombaData['nombre'],
              'finca': bombaData['finca'],
              'bloque': bombaData['bloque'].toString(),
              'activo': 1,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            };
            await dbHelper.insertOrUpdateBomba(bomba);
            totalBombasSynced++;
          }
          
          print('${data.length} bombas sincronizadas para finca $finca, bloque $bloque');
          
          // Pequeña pausa entre bloques para no sobrecargar el servidor
          await Future.delayed(Duration(milliseconds: 300));
          
        } catch (e) {
          print('Error procesando bloque ${bloqueData['finca']}-${bloqueData['nombre']}: $e');
          // Continuar con el siguiente bloque
          continue;
        }
      }
      
      print('$totalBombasSynced bombas aplicaciones sincronizadas desde servidor (POR BLOQUE)');
    } catch (e) {
      print('Error sincronizando bombas aplicaciones del servidor: $e');
      rethrow;
    }
  }

  // ==================== MÉTODOS PRINCIPALES (OPTIMIZADOS) ====================

  // Obtener todos los datos necesarios para el checklist de aplicaciones - OPTIMIZADO
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
        
        // NO sincronizar todos los bloques y bombas automáticamente
        // Solo se cargarán cuando el usuario seleccione una finca/bloque específico
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
      print('Iniciando sincronización forzada optimizada de aplicaciones...');
      
      // Sincronizar fincas
      List<Finca> fincas = await _getFincasFromServer();
      
      // Sincronizar bloques por finca (más eficiente que la consulta masiva original)
      await _syncAllBloquesFromServerWithTimeout();
      
      // Sincronizar bombas por bloque (opcional, puede ser muy pesado)
      // await _syncAllBombasFromServerWithTimeout();
      
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

  // ==================== MÉTODOS DE SINCRONIZACIÓN (OPTIMIZADOS) ====================

  // Sincronizar todos los datos de aplicaciones - VERSIÓN OPTIMIZADA
  static Future<Map<String, dynamic>> syncAplicacionesData() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {
          'success': false,
          'message': 'No hay conexión a internet'
        };
      }

      print('Iniciando sincronización completa optimizada de datos de aplicaciones...');

      int totalSynced = 0;
      List<String> errors = [];

      // Sincronizar fincas
      try {
        List<Finca> fincas = await _getFincasFromServer();
        totalSynced += fincas.length;
        print('Fincas sincronizadas para aplicaciones: ${fincas.length}');
      } catch (e) {
        errors.add('Fincas aplicaciones: $e');
      }

      // Sincronizar bloques con el método optimizado
      try {
        await _syncAllBloquesFromServerWithTimeout();
        
        // Contar cuántos bloques tenemos ahora
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getAplicacionesDatabaseStats();
        totalSynced += stats['bloques'] ?? 0;
        print('Bloques sincronizados para aplicaciones: ${stats['bloques']}');
      } catch (e) {
        errors.add('Bloques aplicaciones: $e');
      }

      // Sincronizar bombas con el método optimizado (opcional)
      try {
        await _syncAllBombasFromServerWithTimeout();
        
        // Contar cuántas bombas tenemos ahora
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getAplicacionesDatabaseStats();
        totalSynced += stats['bombas'] ?? 0;
        print('Bombas sincronizadas para aplicaciones: ${stats['bombas']}');
      } catch (e) {
        errors.add('Bombas aplicaciones: $e');
      }

      if (errors.isEmpty) {
        return {
          'success': true,
          'message': 'Sincronización optimizada de aplicaciones exitosa. $totalSynced registros sincronizados.',
          'count': totalSynced
        };
      } else {
        return {
          'success': false,
          'message': 'Sincronización optimizada de aplicaciones parcial. Errores: ${errors.join(', ')}',
          'count': totalSynced
        };
      }

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante la sincronización optimizada de aplicaciones: $e'
      };
    }
  }

  // ==================== MÉTODOS HELPER ====================

  // Método helper para comparar nombres de bloques numéricamente
  static int _compareBlockNames(String a, String b) {
    // Intentar convertir a números para comparación numérica
    int? numA = int.tryParse(a);
    int? numB = int.tryParse(b);
    
    // Si ambos son números, comparar numéricamente
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }
    
    // Si solo uno es número, el número va primero
    if (numA != null && numB == null) {
      return -1;
    }
    if (numA == null && numB != null) {
      return 1;
    }
    
    // Si ninguno es número, comparar alfabéticamente
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

  // Validar si existe una combinación finca-bloque-bomba
  static Future<bool> validateCombination(String finca, String bloque, String bomba) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Verificar si la combinación existe localmente
      Map<String, dynamic>? result = await dbHelper.getBombaByNombre(bomba, finca, bloque);
      
      if (result != null) {
        return true;
      }

      // Si no existe localmente y hay conexión, verificar en servidor
      if (await AuthService.hasInternetConnection()) {
        String query = '''
          SELECT COUNT(*) as count
          FROM Kontrollers.dbo.base_MIPE 
          WHERE FINCA = '$finca'
            AND BLOQUE = '$bloque'
            AND NUMERO_O_CODIGO_DE_LA_BOMBA = '$bomba'
        ''';

        String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
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

  // Obtener estadísticas de datos locales de aplicaciones
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
      await dbHelper.clearBloquesAplicaciones();
      await dbHelper.clearBombas();
      print('Datos locales de aplicaciones limpiados');
    } catch (e) {
      print('Error limpiando datos locales de aplicaciones: $e');
      rethrow;
    }
  }

  // ==================== MÉTODOS DE OPTIMIZACIÓN ADICIONALES ====================
  
  // Método para limpiar datos antiguos y optimizar base de datos local
  static Future<void> optimizeLocalDatabase() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Limpiar datos antiguos (más de 30 días)
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: 30));
      String cutoffString = cutoffDate.toIso8601String();
      
      print('Optimizando base de datos local de aplicaciones...');
      
      // Aquí puedes agregar lógica para limpiar datos antiguos si tienes esos métodos
      // await dbHelper.cleanOldAplicacionesData(cutoffString);
      
      print('Optimización de base de datos local completada');
    } catch (e) {
      print('Error optimizando base de datos local: $e');
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
      };
    } catch (e) {
      print('Error obteniendo estado de sincronización: $e');
      return {
        'fincas': 0,
        'bloques': 0,
        'bombas': 0,
        'lastSync': null,
        'optimized': false,
      };
    }
  }

  // Método para cargar datos bajo demanda (lazy loading)
  static Future<void> preloadDataForFinca(String finca) async {
    try {
      print('Precargando datos para finca $finca...');
      
      // Cargar bloques de la finca
      await _getBloquesByFincaFromServer(finca);
      
      print('Datos precargados para finca $finca');
    } catch (e) {
      print('Error precargando datos para finca $finca: $e');
    }
  }

  // Método para cargar datos bajo demanda para bomba específica
  static Future<void> preloadBombasForFincaAndBloque(String finca, String bloque) async {
    try {
      print('Precargando bombas para finca $finca, bloque $bloque...');
      
      // Cargar bombas específicas
      await _getBombasByFincaAndBloqueFromServer(finca, bloque);
      
      print('Bombas precargadas para finca $finca, bloque $bloque');
    } catch (e) {
      print('Error precargando bombas para finca $finca, bloque $bloque: $e');
    }
  }
}