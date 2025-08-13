import 'dart:convert';
import '../models/dropdown_models.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

class CosechaDropdownService {
  
  // ==================== FINCAS ====================
  
  // Obtener fincas (offline first)
  static Future<List<Finca>> getFincas() async {
    try {
      // Primero intentar obtener datos locales
      List<Finca> fincas = await _getFincasFromLocal();
      
      // Si hay datos locales, usarlos
      if (fincas.isNotEmpty) {
        print('Fincas cargadas desde SQLite para cosecha: ${fincas.length}');
        return fincas;
      }

      // Si no hay datos locales y hay conexión, intentar obtener del servidor
      if (await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para cosecha, obteniendo del servidor...');
        return await _getFincasFromServer();
      }

      // Sin datos locales ni conexión
      print('Sin fincas locales ni conexión para cosecha');
      return [];
      
    } catch (e) {
      print('Error obteniendo fincas para cosecha: $e');
      return [];
    }
  }

  // Obtener fincas locales
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

  // Obtener fincas del servidor y guardar localmente
  static Future<List<Finca>> _getFincasFromServer() async {
    try {
      String query = '''
        SELECT DISTINCT LOCALIDAD as nombre
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
        ORDER BY LOCALIDAD
      ''';

      String result = await SqlServerService.executeQuery(query);
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
          await dbHelper.insertOrUpdateFinca(finca);
        }
        print('${data.length} fincas sincronizadas desde servidor para cosecha');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo fincas del servidor para cosecha: $e');
      return [];
    }
  }

  // ==================== BLOQUES ====================
  
  // Obtener bloques por finca (offline first)
  static Future<List<Bloque>> getBloquesByFinca(String finca) async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getBloquesByFinca(finca);
      
      // Si hay datos locales, usarlos y ordenarlos
      if (localData.isNotEmpty) {
        print('Bloques cargados desde SQLite: ${localData.length} para finca $finca');
        List<Bloque> bloques = localData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      // Si no hay datos locales y hay conexión, intentar sincronizar todos los bloques primero
      if (await AuthService.hasInternetConnection()) {
        print('No hay bloques locales, sincronizando todos los bloques del servidor...');
        await _syncAllBloquesFromServer();
        
        // Ahora obtener los bloques de la finca específica
        List<Map<String, dynamic>> reloadedData = await dbHelper.getBloquesByFinca(finca);
        List<Bloque> bloques = reloadedData.map((item) => Bloque.fromJson(item)).toList();
        bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
        return bloques;
      }

      // Sin datos locales ni conexión
      print('Sin bloques locales ni conexión para finca $finca');
      return [];
      
    } catch (e) {
      print('Error obteniendo bloques por finca: $e');
      return [];
    }
  }

  // Sincronizar TODOS los bloques del servidor de una vez (versión simplificada)
  static Future<void> _syncAllBloquesFromServer() async {
    try {
      print('Sincronizando TODOS los bloques desde el servidor...');
      
      // Query simplificado - sin ORDER BY para evitar errores SQL
      String query = '''
        SELECT DISTINCT 
          CAST(BLOCK as NVARCHAR(50)) as nombre, 
          LOCALIDAD as finca
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
          AND BLOCK IS NOT NULL 
          AND BLOCK != ''
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Ordenar en memoria por finca y luego por bloque
      data.sort((a, b) {
        // Primero ordenar por finca
        int fincaComparison = a['finca'].toString().compareTo(b['finca'].toString());
        if (fincaComparison != 0) return fincaComparison;
        
        // Luego ordenar por bloque numéricamente
        return _compareBlockNames(a['nombre'].toString(), b['nombre'].toString());
      });
      
      // Guardar TODOS los bloques en SQLite
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
        print('${data.length} bloques sincronizados desde servidor (TODOS)');
      }
    } catch (e) {
      print('Error sincronizando todos los bloques del servidor: $e');
      rethrow;
    }
  }

  // Obtener bloques de una finca específica del servidor (versión simplificada)
  static Future<List<Bloque>> _getBloquesByFincaFromServer(String finca) async {
    try {
      // Query simplificado - sin ORDER BY problemático
      String query = '''
        SELECT DISTINCT 
          CAST(BLOCK as NVARCHAR(50)) as nombre, 
          LOCALIDAD as finca
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD = '$finca'
          AND BLOCK IS NOT NULL 
          AND BLOCK != ''
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
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
          await dbHelper.insertOrUpdateBloque(bloque);
        }
        print('${data.length} bloques sincronizados desde servidor para finca $finca');
      }
      
      // Convertir a objetos Bloque y ordenar
      List<Bloque> bloques = data.map((item) => Bloque.fromJson(item)).toList();
      bloques.sort((a, b) => _compareBlockNames(a.nombre, b.nombre));
      return bloques;
    } catch (e) {
      print('Error obteniendo bloques del servidor para finca $finca: $e');
      return [];
    }
  }

  // ==================== VARIEDADES (MEJORADO) ====================
  
  // Obtener variedades por finca y bloque (offline first MEJORADO)
  static Future<List<Variedad>> getVariedadesByFincaAndBloque(String finca, String bloque) async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getVariedadesByFincaAndBloque(finca, bloque);
      
      // Si hay datos locales, usarlos
      if (localData.isNotEmpty) {
        print('Variedades cargadas desde SQLite: ${localData.length} para finca $finca, bloque $bloque');
        return localData.map((item) => Variedad.fromJson(item)).toList();
      }

      // Si no hay datos locales y hay conexión, intentar sincronizar TODAS las variedades primero
      if (await AuthService.hasInternetConnection()) {
        print('No hay variedades locales, sincronizando todas las variedades del servidor...');
        await _syncAllVariedadesFromServer();
        
        // Ahora obtener las variedades de la finca y bloque específicos
        List<Map<String, dynamic>> reloadedData = await dbHelper.getVariedadesByFincaAndBloque(finca, bloque);
        print('Variedades cargadas después de sincronización: ${reloadedData.length} para finca $finca, bloque $bloque');
        return reloadedData.map((item) => Variedad.fromJson(item)).toList();
      }

      // Sin datos locales ni conexión
      print('Sin variedades locales ni conexión para finca $finca, bloque $bloque');
      return [];
      
    } catch (e) {
      print('Error obteniendo variedades por finca y bloque: $e');
      return [];
    }
  }

  // NUEVO: Sincronizar TODAS las variedades del servidor de una vez
  static Future<void> _syncAllVariedadesFromServer() async {
    try {
      print('Sincronizando TODAS las variedades desde el servidor...');
      
      // Query para obtener TODAS las variedades
      String query = '''
        SELECT DISTINCT 
          PRODUCTO as nombre, 
          LOCALIDAD as finca, 
          CAST(BLOCK as NVARCHAR(50)) as bloque
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
          AND BLOCK IS NOT NULL 
          AND BLOCK != ''
          AND PRODUCTO IS NOT NULL 
          AND PRODUCTO != ''
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Ordenar en memoria por finca, bloque y variedad
      data.sort((a, b) {
        // Primero ordenar por finca
        int fincaComparison = a['finca'].toString().compareTo(b['finca'].toString());
        if (fincaComparison != 0) return fincaComparison;
        
        // Luego ordenar por bloque
        int bloqueComparison = _compareBlockNames(a['bloque'].toString(), b['bloque'].toString());
        if (bloqueComparison != 0) return bloqueComparison;
        
        // Finalmente ordenar por variedad
        return a['nombre'].toString().compareTo(b['nombre'].toString());
      });
      
      // Guardar TODAS las variedades en SQLite
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
        print('${data.length} variedades sincronizadas desde servidor (TODAS)');
      }
    } catch (e) {
      print('Error sincronizando todas las variedades del servidor: $e');
      rethrow;
    }
  }

  // Obtener variedades de una finca y bloque del servidor y guardar localmente (método legacy)
  static Future<List<Variedad>> _getVariedadesByFincaAndBloqueFromServer(String finca, String bloque) async {
    try {
      String query = '''
        SELECT DISTINCT 
          PRODUCTO as nombre, 
          LOCALIDAD as finca, 
          CAST(BLOCK as NVARCHAR(50)) as bloque
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD = '$finca'
          AND BLOCK = '$bloque'
          AND PRODUCTO IS NOT NULL 
          AND PRODUCTO != ''
        ORDER BY PRODUCTO
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
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
    } catch (e) {
      print('Error obteniendo variedades del servidor: $e');
      return [];
    }
  }

  // ==================== MÉTODOS PRINCIPALES ====================

  // Obtener todos los datos necesarios para el checklist de cosecha
  static Future<Map<String, dynamic>> getCosechaDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos de dropdown para cosecha (forceSync: $forceSync)');
      
      // Si se requiere sincronización forzada y hay conexión
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada solicitada para cosecha');
        return await _forceSync();
      }

      // Obtener fincas (usar método local primero)
      List<Finca> fincas = await _getFincasFromLocal();
      
      // Si no hay fincas locales, intentar obtener del servidor
      if (fincas.isEmpty && await AuthService.hasInternetConnection()) {
        print('No hay fincas locales para cosecha, obteniendo del servidor...');
        fincas = await _getFincasFromServer();
        
        // También sincronizar todos los bloques y variedades de una vez
        try {
          await _syncAllBloquesFromServer();
          await _syncAllVariedadesFromServer(); // NUEVO: Sincronizar todas las variedades
        } catch (e) {
          print('Error sincronizando bloques/variedades durante carga inicial: $e');
        }
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

  // Sincronización forzada
  static Future<Map<String, dynamic>> _forceSync() async {
    try {
      print('Iniciando sincronización forzada de cosecha...');
      
      // Sincronizar fincas
      List<Finca> fincas = await _getFincasFromServer();
      
      // Sincronizar TODOS los bloques
      await _syncAllBloquesFromServer();
      
      // Sincronizar TODAS las variedades
      await _syncAllVariedadesFromServer();
      
      return {
        'success': true,
        'fincas': fincas,
        'message': 'Sincronización forzada de cosecha exitosa'
      };
      
    } catch (e) {
      print('Error en sincronización forzada de cosecha: $e');
      return {
        'success': false,
        'fincas': <Finca>[],
        'message': 'Error en sincronización forzada de cosecha: $e'
      };
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  // Sincronizar todos los datos de cosecha
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

      // Sincronizar fincas
      try {
        List<Finca> fincas = await _getFincasFromServer();
        totalSynced += fincas.length;
        print('Fincas sincronizadas para cosecha: ${fincas.length}');
      } catch (e) {
        errors.add('Fincas: $e');
      }

      // Sincronizar TODOS los bloques
      try {
        await _syncAllBloquesFromServer();
        
        // Contar cuántos bloques tenemos ahora
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getCosechaDatabaseStats();
        totalSynced += stats['bloques'] ?? 0;
        print('Bloques sincronizados para cosecha: ${stats['bloques']}');
      } catch (e) {
        errors.add('Bloques: $e');
      }

      // Sincronizar TODAS las variedades
      try {
        await _syncAllVariedadesFromServer();
        
        // Contar cuántas variedades tenemos ahora
        DatabaseHelper dbHelper = DatabaseHelper();
        Map<String, int> stats = await dbHelper.getCosechaDatabaseStats();
        totalSynced += stats['variedades'] ?? 0;
        print('Variedades sincronizadas para cosecha: ${stats['variedades']}');
      } catch (e) {
        errors.add('Variedades: $e');
      }

      if (errors.isEmpty) {
        return {
          'success': true,
          'message': 'Sincronización de cosecha exitosa. $totalSynced registros sincronizados.',
          'count': totalSynced
        };
      } else {
        return {
          'success': false,
          'message': 'Sincronización de cosecha parcial. Errores: ${errors.join(', ')}',
          'count': totalSynced
        };
      }

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante la sincronización de cosecha: $e'
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
      Map<String, dynamic>? localData = await dbHelper.getFincaByNombre(nombre);
      
      if (localData != null) {
        return Finca.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Finca> fincas = await _getFincasFromServer();
        return fincas.firstWhere(
          (finca) => finca.nombre == nombre,
          orElse: () => throw Exception('Finca no encontrada'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando finca por nombre: $e');
      return null;
    }
  }

  // Buscar bloque por nombre y finca (offline first)
  static Future<Bloque?> getBloqueByNombre(String nombre, String finca) async {
    try {
      // Primero buscar localmente
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localData = await dbHelper.getBloqueByNombre(nombre, finca);
      
      if (localData != null) {
        return Bloque.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Bloque> bloques = await _getBloquesByFincaFromServer(finca);
        return bloques.firstWhere(
          (bloque) => bloque.nombre == nombre,
          orElse: () => throw Exception('Bloque no encontrado'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando bloque por nombre: $e');
      return null;
    }
  }

  // Buscar variedad por nombre, finca y bloque (offline first)
  static Future<Variedad?> getVariedadByNombre(String nombre, String finca, String bloque) async {
    try {
      // Primero buscar localmente
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localData = await dbHelper.getVariedadByNombre(nombre, finca, bloque);
      
      if (localData != null) {
        return Variedad.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Variedad> variedades = await _getVariedadesByFincaAndBloqueFromServer(finca, bloque);
        return variedades.firstWhere(
          (variedad) => variedad.nombre == nombre,
          orElse: () => throw Exception('Variedad no encontrada'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando variedad por nombre: $e');
      return null;
    }
  }

  // ==================== MÉTODOS DE VALIDACIÓN ====================

  // Validar si existe una combinación finca-bloque-variedad
  static Future<bool> validateCombination(String finca, String bloque, String variedad) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      
      // Verificar si la combinación existe localmente
      Map<String, dynamic>? result = await dbHelper.getVariedadByNombre(variedad, finca, bloque);
      
      if (result != null) {
        return true;
      }

      // Si no existe localmente y hay conexión, verificar en servidor
      if (await AuthService.hasInternetConnection()) {
        String query = '''
          SELECT COUNT(*) as count
          FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
          WHERE LOCALIDAD = '$finca'
            AND BLOCK = '$bloque'
            AND PRODUCTO = '$variedad'
        ''';

        String result = await SqlServerService.executeQuery(query);
        List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
        
        if (data.isNotEmpty) {
          int count = data.first['count'] ?? 0;
          return count > 0;
        }
      }

      return false;
    } catch (e) {
      print('Error validando combinación finca-bloque-variedad: $e');
      return false;
    }
  }

  // ==================== MÉTODOS DE ESTADÍSTICAS Y LIMPIEZA ====================

  // Obtener estadísticas de datos locales de cosecha
  static Future<Map<String, int>> getLocalCosechaStats() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      return await dbHelper.getCosechaDatabaseStats();
    } catch (e) {
      print('Error obteniendo estadísticas de cosecha: $e');
      return {
        'fincas': 0,
        'bloques': 0,
        'variedades': 0,
      };
    }
  }

  // Limpiar todos los datos locales de cosecha
  static Future<void> clearLocalCosechaData() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.clearBloques();
      await dbHelper.clearVariedades();
      print('Datos locales de cosecha limpiados');
    } catch (e) {
      print('Error limpiando datos locales de cosecha: $e');
      rethrow;
    }
  }

  // ==================== MÉTODOS LEGACY PARA COMPATIBILIDAD ====================

  // Precargar bloques para una finca específica
  static Future<void> preloadBloquesForFinca(String finca) async {
    try {
      if (await AuthService.hasInternetConnection()) {
        await _getBloquesByFincaFromServer(finca);
        print('Bloques precargados para finca: $finca');
      }
    } catch (e) {
      print('Error precargando bloques para finca $finca: $e');
    }
  }

  // Precargar variedades para una finca y bloque específicos
  static Future<void> preloadVariedadesForFincaAndBloque(String finca, String bloque) async {
    try {
      if (await AuthService.hasInternetConnection()) {
        await _getVariedadesByFincaAndBloqueFromServer(finca, bloque);
        print('Variedades precargadas para finca: $finca, bloque: $bloque');
      }
    } catch (e) {
      print('Error precargando variedades para finca $finca, bloque $bloque: $e');
    }
  }
}