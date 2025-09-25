import 'dart:convert';
import '../database/database_helper.dart';
import '../data/checklist_data_labores_temporales.dart';
import '../models/dropdown_models.dart';
import '../services/sql_server_service.dart';
import '../services/auth_service.dart';
import 'date_helper.dart';

class ChecklistLaboresTemporalesStorageService {
  
  // ==================== OPERACIONES LOCALES (SQLite) ====================
  
  static Future<int> saveChecklist(ChecklistLaboresTemporales checklist) async {
    final db = await DatabaseHelper().database;
    
    // Calcular métricas antes de guardar
    Map<String, dynamic> metricas = _calcularMetricas(checklist);
    
    Map<String, dynamic> checklistMap = {
      'fecha': checklist.fecha?.toIso8601String(),
      'finca_nombre': checklist.finca?.nombre,
      'up': checklist.up,
      'semana': checklist.semana,
      'kontroller': checklist.kontroller,
      'cuadrantes_json': jsonEncode(checklist.cuadrantes.map((c) => c.toJson()).toList()),
      'items_json': jsonEncode(checklist.items.map((item) => item.toJson()).toList()),
      'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
      'total_evaluaciones': metricas['totalEvaluaciones'],
      'total_conformes': metricas['totalConformes'],
      'total_no_conformes': metricas['totalNoConformes'],
      'observaciones_generales': checklist.observacionesGenerales,
      'fecha_creacion': DateTime.now().toIso8601String(),
      'enviado': 0,
      'activo': 1,
    };

    print('Guardando checklist labores temporales: ${checklistMap['finca_nombre']} - ${checklistMap['kontroller']}');
    
    return await db.insert('check_labores_temporales', checklistMap);
  }

  static Future<void> updateChecklist(ChecklistLaboresTemporales checklist) async {
    if (checklist.id == null) throw Exception('ID del checklist es requerido para actualizar');
    
    final db = await DatabaseHelper().database;
    
    // Calcular métricas actualizadas
    Map<String, dynamic> metricas = _calcularMetricas(checklist);
    
    Map<String, dynamic> checklistMap = {
      'fecha': checklist.fecha?.toIso8601String(),
      'finca_nombre': checklist.finca?.nombre,
      'up': checklist.up,
      'semana': checklist.semana,
      'kontroller': checklist.kontroller,
      'cuadrantes_json': jsonEncode(checklist.cuadrantes.map((c) => c.toJson()).toList()),
      'items_json': jsonEncode(checklist.items.map((item) => item.toJson()).toList()),
      'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
      'total_evaluaciones': metricas['totalEvaluaciones'],
      'total_conformes': metricas['totalConformes'],
      'total_no_conformes': metricas['totalNoConformes'],
      'observaciones_generales': checklist.observacionesGenerales,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    };

    print('Actualizando checklist labores temporales ID ${checklist.id}');
    
    await db.update(
      'check_labores_temporales',
      checklistMap,
      where: 'id = ?',
      whereArgs: [checklist.id],
    );
  }

  static Future<List<ChecklistLaboresTemporales>> getAllChecklists() async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_labores_temporales',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'fecha_creacion DESC',
    );

    print('Obtenidos ${maps.length} checklists de labores temporales desde SQLite');
    
    return maps.map((map) => _mapToChecklistLaboresTemporales(map)).toList();
  }

  static Future<ChecklistLaboresTemporales?> getChecklistById(int id) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_labores_temporales',
      where: 'id = ? AND activo = ?',
      whereArgs: [id, 1],
    );

    if (maps.isNotEmpty) {
      return _mapToChecklistLaboresTemporales(maps.first);
    }
    return null;
  }

  static Future<void> deleteChecklist(int id) async {
    final db = await DatabaseHelper().database;
    
    // Soft delete - marcar como inactivo
    await db.update(
      'check_labores_temporales',
      {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    print('Checklist labores temporales con ID $id marcado como eliminado');
  }

  // ==================== SINCRONIZACIÓN CON SERVIDOR ====================
  
  static Future<Map<String, dynamic>> syncChecklistsToServer() async {
    final db = await DatabaseHelper().database;
    
    // Obtener checklists no enviados
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'check_labores_temporales',
      where: 'enviado = ? AND activo = ?',
      whereArgs: [0, 1],
      orderBy: 'fecha_creacion ASC',
    );

    print('Intentando sincronizar ${unsyncedMaps.length} checklists de labores temporales...');

    if (unsyncedMaps.isEmpty) {
      return {
        'success': true,
        'message': 'No hay checklists de labores temporales pendientes por sincronizar',
        'synced': 0,
        'failed': 0,
      };
    }

    if (!await AuthService.hasInternetConnection()) {
      throw Exception('No hay conexión a internet para sincronizar');
    }

    int syncedCount = 0;
    int failedCount = 0;
    List<String> errors = [];

    for (var map in unsyncedMaps) {
      try {
        ChecklistLaboresTemporales checklist = _mapToChecklistLaboresTemporales(map);
        await _sendChecklistToServer(checklist);
        
        // Marcar como enviado
        await db.update(
          'check_labores_temporales',
          {'enviado': 1, 'fecha_envio': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        
        syncedCount++;
        print('Checklist labores temporales ID ${map['id']} sincronizado exitosamente');
        
      } catch (e) {
        failedCount++;
        errors.add('ID ${map['id']}: $e');
        print('Error sincronizando checklist labores temporales ID ${map['id']}: $e');
      }
    }

    return {
      'success': failedCount == 0,
      'message': syncedCount > 0 
          ? '$syncedCount checklists de labores temporales sincronizados exitosamente'
          : 'No se pudieron sincronizar los checklists de labores temporales',
      'synced': syncedCount,
      'failed': failedCount,
      'errors': errors,
    };
  }

  static Future<void> _sendChecklistToServer(ChecklistLaboresTemporales checklist) async {
    if (checklist.id == null) throw Exception('ID del checklist es requerido');

    // Obtener usuario actual desde AuthService
    Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) throw Exception('Usuario no autenticado');
    String username = currentUser['username'] ?? '';

    // Escapar strings para SQL
    String escapedFinca = (checklist.finca?.nombre ?? '').replaceAll("'", "''");
    String escapedUp = (checklist.up ?? '').replaceAll("'", "''");
    String escapedSemana = (checklist.semana ?? '').replaceAll("'", "''");
    String escapedKontroller = (checklist.kontroller ?? '').replaceAll("'", "''");
    String escapedObservaciones = (checklist.observacionesGenerales ?? '').replaceAll("'", "''");
    String escapedCuadrantes = jsonEncode(checklist.cuadrantes.map((c) => c.toJson()).toList()).replaceAll("'", "''");
    String escapedItems = jsonEncode(checklist.items.map((item) => item.toJson()).toList()).replaceAll("'", "''");
    String escapedUser = username.replaceAll("'", "''");

    // Calcular métricas
    Map<String, dynamic> metricas = _calcularMetricas(checklist);

    // Construir query de inserción
    String query = '''
      INSERT INTO check_labores_temporales (
        id_local, fecha, finca_nombre, up_unidad_productiva, semana, kontroller,
        cuadrantes_json, items_json, porcentaje_cumplimiento, total_evaluaciones, 
        total_conformes, total_no_conformes, observaciones_generales, 
        usuario_creacion, fecha_creacion
      ) VALUES (
        ${checklist.id},
        ${DateHelper.formatForSqlServer(checklist.fecha)},
        '$escapedFinca',
        '$escapedUp',
        '$escapedSemana',
        '$escapedKontroller',
        '$escapedCuadrantes',
        '$escapedItems',
        ${checklist.calcularPorcentajeCumplimiento()},
        ${metricas['totalEvaluaciones']},
        ${metricas['totalConformes']},
        ${metricas['totalNoConformes']},
        '$escapedObservaciones',
        '$escapedUser',
        ${DateHelper.getCurrentDateForSqlServer()}
      )
    ''';

    await SqlServerService.executeQuery(query);
    print('Checklist labores temporales enviado al servidor exitosamente');
  }

  // ==================== ESTADÍSTICAS Y REPORTES ====================
  
  static Future<Map<String, dynamic>> getStatistics() async {
    final db = await DatabaseHelper().database;
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_checklists,
        COUNT(CASE WHEN enviado = 1 THEN 1 END) as enviados,
        COUNT(CASE WHEN enviado = 0 THEN 1 END) as pendientes,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as mejor_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as menor_cumplimiento,
        COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
        COUNT(DISTINCT kontroller) as kontrollers_activos,
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones_suma,
        SUM(COALESCE(total_conformes, 0)) as total_conformes_suma,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes_suma
      FROM check_labores_temporales
      WHERE activo = 1
    ''');

    if (result.isNotEmpty) {
      var row = result.first;
      return {
        'totalChecklists': row['total_checklists'] ?? 0,
        'enviados': row['enviados'] ?? 0,
        'pendientes': row['pendientes'] ?? 0,
        'promedioCumplimiento': ((row['promedio_cumplimiento'] as num?) ?? 0.0).toDouble(),
        'mejorCumplimiento': ((row['mejor_cumplimiento'] as num?) ?? 0.0).toDouble(),
        'menorCumplimiento': ((row['menor_cumplimiento'] as num?) ?? 0.0).toDouble(),
        'fincasEvaluadas': row['fincas_evaluadas'] ?? 0,
        'kontrollersActivos': row['kontrollers_activos'] ?? 0,
        'totalEvaluacionesSuma': row['total_evaluaciones_suma'] ?? 0,
        'totalConformesSuma': row['total_conformes_suma'] ?? 0,
        'totalNoConformesSuma': row['total_no_conformes_suma'] ?? 0,
      };
    }

    return {
      'totalChecklists': 0,
      'enviados': 0,
      'pendientes': 0,
      'promedioCumplimiento': 0.0,
      'mejorCumplimiento': 0.0,
      'menorCumplimiento': 0.0,
      'fincasEvaluadas': 0,
      'kontrollersActivos': 0,
      'totalEvaluacionesSuma': 0,
      'totalConformesSuma': 0,
      'totalNoConformesSuma': 0,
    };
  }

  static Future<List<Map<String, dynamic>>> getChecklistsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_labores_temporales',
      where: 'date(fecha) BETWEEN date(?) AND date(?) AND activo = ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String(), 1],
      orderBy: 'fecha DESC',
    );

    return maps;
  }

  static Future<List<Map<String, dynamic>>> getChecklistsByFinca(String fincaNombre) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_labores_temporales',
      where: 'finca_nombre = ? AND activo = ?',
      whereArgs: [fincaNombre, 1],
      orderBy: 'fecha DESC',
    );

    return maps;
  }

  static Future<List<Map<String, dynamic>>> getChecklistsByKontroller(String kontroller) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_labores_temporales',
      where: 'kontroller = ? AND activo = ?',
      whereArgs: [kontroller, 1],
      orderBy: 'fecha DESC',
    );

    return maps;
  }

  static Future<Map<String, dynamic>> getReportePorSemana() async {
    final db = await DatabaseHelper().database;
    
    final result = await db.rawQuery('''
      SELECT 
        semana,
        COUNT(*) as total_evaluaciones,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as mejor_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as peor_cumplimiento,
        COUNT(DISTINCT kontroller) as kontrollers_distintos,
        COUNT(DISTINCT finca_nombre) as fincas_evaluadas,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes
      FROM check_labores_temporales
      WHERE activo = 1 AND semana IS NOT NULL AND semana != ''
      GROUP BY semana
      ORDER BY semana DESC
    ''');

    return {
      'reportePorSemana': result,
      'totalSemanas': result.length,
    };
  }

  static Future<Map<String, dynamic>> getReportePorKontroller() async {
    final db = await DatabaseHelper().database;
    
    final result = await db.rawQuery('''
      SELECT 
        kontroller,
        COUNT(*) as total_evaluaciones,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as mejor_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as peor_cumplimiento,
        COUNT(DISTINCT finca_nombre) as fincas_atendidas,
        COUNT(DISTINCT semana) as semanas_activas,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes
      FROM check_labores_temporales
      WHERE activo = 1 AND kontroller IS NOT NULL AND kontroller != ''
      GROUP BY kontroller
      ORDER BY promedio_cumplimiento DESC
    ''');

    return {
      'reportePorKontroller': result,
      'totalKontrollers': result.length,
    };
  }

  // ==================== UTILIDADES PRIVADAS ====================
  
  static Map<String, dynamic> _calcularMetricas(ChecklistLaboresTemporales checklist) {
    int totalEvaluaciones = 0;
    int totalConformes = 0;
    int totalNoConformes = 0;

    for (var item in checklist.items) {
      for (var cuadrante in checklist.cuadrantes) {
        for (int parada = 1; parada <= 5; parada++) {
          String? resultado = item.getResultado(cuadrante.claveUnica, parada);
          if (resultado != null && resultado.trim().isNotEmpty) {
            totalEvaluaciones++;
            String resultadoLower = resultado.toLowerCase().trim();
            if (resultadoLower == 'c' || resultadoLower == '1') {
              totalConformes++;
            } else if (resultadoLower == 'nc' || resultadoLower == '0') {
              totalNoConformes++;
            }
          }
        }
      }
    }

    return {
      'totalEvaluaciones': totalEvaluaciones,
      'totalConformes': totalConformes,
      'totalNoConformes': totalNoConformes,
    };
  }
  
  static ChecklistLaboresTemporales _mapToChecklistLaboresTemporales(Map<String, dynamic> map) {
    // Parsear cuadrantes
    List<CuadranteLaboresTemporalesInfo> cuadrantes = [];
    if (map['cuadrantes_json'] != null && map['cuadrantes_json'].toString().isNotEmpty) {
      try {
        List<dynamic> cuadrantesData = jsonDecode(map['cuadrantes_json']);
        cuadrantes = cuadrantesData.map((c) => CuadranteLaboresTemporalesInfo.fromJson(c)).toList();
      } catch (e) {
        print('Error parseando cuadrantes JSON: $e');
      }
    }

    // Parsear items
    List<ChecklistLaboresTemporalesItem> items = [];
    if (map['items_json'] != null && map['items_json'].toString().isNotEmpty) {
      try {
        List<dynamic> itemsData = jsonDecode(map['items_json']);
        items = itemsData.map((item) => ChecklistLaboresTemporalesItem.fromJson(item)).toList();
      } catch (e) {
        print('Error parseando items JSON: $e');
      }
    }

    // Crear finca si existe el nombre
    Finca? finca;
    if (map['finca_nombre'] != null && map['finca_nombre'].toString().isNotEmpty) {
      finca = Finca(nombre: map['finca_nombre'].toString());
    }

    return ChecklistLaboresTemporales(
      id: map['id'],
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : null,
      finca: finca,
      up: map['up']?.toString(),
      semana: map['semana']?.toString(),
      kontroller: map['kontroller']?.toString(),
      cuadrantes: cuadrantes,
      items: items,
      fechaEnvio: map['fecha_envio'] != null ? DateTime.parse(map['fecha_envio']) : null,
      porcentajeCumplimiento: map['porcentaje_cumplimiento']?.toDouble(),
      observacionesGenerales: map['observaciones_generales']?.toString(),
    );
  }

  // ==================== UTILIDADES DE LIMPIEZA ====================
  
  static Future<void> cleanOldChecklists({int daysToKeep = 120}) async {
    final db = await DatabaseHelper().database;
    
    DateTime cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    // Soft delete de registros antiguos ya sincronizados
    int deletedCount = await db.update(
      'check_labores_temporales',
      {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'fecha_creacion < ? AND enviado = ? AND activo = ?',
      whereArgs: [cutoffDate.toIso8601String(), 1, 1],
    );

    print('Marcados como eliminados $deletedCount checklists de labores temporales antiguos (más de $daysToKeep días)');
  }

  static Future<Map<String, dynamic>> exportChecklistsToJson() async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_labores_temporales',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'fecha_creacion DESC',
    );

    List<ChecklistLaboresTemporales> checklists = maps.map((map) => _mapToChecklistLaboresTemporales(map)).toList();
    Map<String, dynamic> stats = await getStatistics();
    
    Map<String, dynamic> exportData = {
      'export_metadata': {
        'export_date': DateTime.now().toIso8601String(),
        'total_records': checklists.length,
        'module': 'labores_temporales',
        'version': '1.0',
      },
      'statistics': stats,
      'checklists': checklists.map((c) => c.toJson()).toList(),
    };

    print('Datos de labores temporales preparados para exportar: ${checklists.length} registros');
    return exportData;
  }
}
