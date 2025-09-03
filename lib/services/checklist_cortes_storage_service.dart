import 'dart:convert';
import '../database/database_helper.dart';
import '../data/checklist_data_cortes.dart';
import '../models/dropdown_models.dart';
import '../services/sql_server_service.dart';
import '../services/auth_service.dart';

class ChecklistCortesStorageService {
  
  // ==================== OPERACIONES LOCALES (SQLite) ====================
  
  static Future<int> saveChecklist(ChecklistCortes checklist) async {
    final db = await DatabaseHelper().database;
    
    // Calcular métricas antes de guardar
    Map<String, dynamic> metricas = _calcularMetricas(checklist);
    
    Map<String, dynamic> checklistMap = {
      'fecha': checklist.fecha?.toIso8601String(),
      'finca_nombre': checklist.finca?.nombre,
      'supervisor': checklist.supervisor,
      'cuadrantes_json': jsonEncode(checklist.cuadrantes.map((c) => c.toJson()).toList()),
      'items_json': jsonEncode(checklist.items.map((item) => item.toJson()).toList()),
      'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
      'total_evaluaciones': metricas['totalEvaluaciones'],
      'total_conformes': metricas['totalConformes'],
      'total_no_conformes': metricas['totalNoConformes'],
      'fecha_creacion': DateTime.now().toIso8601String(),
      'enviado': 0,
      'activo': 1,
    };

    print('Guardando checklist cortes: ${checklistMap['finca_nombre']} - ${checklistMap['supervisor']}');
    
    return await db.insert('check_cortes', checklistMap);
  }

  static Future<void> updateChecklist(ChecklistCortes checklist) async {
    if (checklist.id == null) throw Exception('ID del checklist es requerido para actualizar');
    
    final db = await DatabaseHelper().database;
    
    // Calcular métricas actualizadas
    Map<String, dynamic> metricas = _calcularMetricas(checklist);
    
    Map<String, dynamic> checklistMap = {
      'fecha': checklist.fecha?.toIso8601String(),
      'finca_nombre': checklist.finca?.nombre,
      'supervisor': checklist.supervisor,
      'cuadrantes_json': jsonEncode(checklist.cuadrantes.map((c) => c.toJson()).toList()),
      'items_json': jsonEncode(checklist.items.map((item) => item.toJson()).toList()),
      'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
      'total_evaluaciones': metricas['totalEvaluaciones'],
      'total_conformes': metricas['totalConformes'],
      'total_no_conformes': metricas['totalNoConformes'],
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    };

    print('Actualizando checklist cortes ID ${checklist.id}');
    
    await db.update(
      'check_cortes',
      checklistMap,
      where: 'id = ?',
      whereArgs: [checklist.id],
    );
  }

  static Future<List<ChecklistCortes>> getAllChecklists() async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_cortes',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'fecha_creacion DESC',
    );

    print('Obtenidos ${maps.length} checklists de cortes desde SQLite');
    
    return maps.map((map) => _mapToChecklistCortes(map)).toList();
  }

  static Future<ChecklistCortes?> getChecklistById(int id) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_cortes',
      where: 'id = ? AND activo = ?',
      whereArgs: [id, 1],
    );

    if (maps.isNotEmpty) {
      return _mapToChecklistCortes(maps.first);
    }
    return null;
  }

  static Future<void> deleteChecklist(int id) async {
    final db = await DatabaseHelper().database;
    
    // Soft delete - marcar como inactivo
    await db.update(
      'check_cortes',
      {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    print('Checklist cortes con ID $id marcado como eliminado');
  }

  // ==================== SINCRONIZACIÓN CON SERVIDOR ====================
  
  static Future<Map<String, dynamic>> syncChecklistsToServer() async {
    try {
      // Primero ejecutar diagnóstico
      Map<String, dynamic> diagnosis = await diagnoseSyncIssues();
      print('Diagnóstico de sincronización: $diagnosis');
      
      if (!diagnosis['can_sync']) {
        return {
          'success': false,
          'message': 'No se puede sincronizar: ${diagnosis['issues'].join(', ')}',
          'synced': 0,
          'failed': 0,
          'diagnosis': diagnosis,
        };
      }
      
      final db = await DatabaseHelper().database;
      
      // Obtener checklists no enviados
      final List<Map<String, dynamic>> unsyncedMaps = await db.query(
        'check_cortes',
        where: 'enviado = ? AND activo = ?',
        whereArgs: [0, 1],
        orderBy: 'fecha_creacion ASC',
      );

      print('Intentando sincronizar ${unsyncedMaps.length} checklists de cortes...');

      if (unsyncedMaps.isEmpty) {
        return {
          'success': true,
          'message': 'No hay checklists de cortes pendientes por sincronizar',
          'synced': 0,
          'failed': 0,
          'diagnosis': diagnosis,
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
          ChecklistCortes checklist = _mapToChecklistCortes(map);
          await _sendChecklistToServer(checklist);
          
          // Marcar como enviado
          await db.update(
            'check_cortes',
            {'enviado': 1, 'fecha_envio': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [map['id']],
          );
          
          syncedCount++;
          print('Checklist cortes ID ${map['id']} sincronizado exitosamente');
          
        } catch (e) {
          failedCount++;
          errors.add('ID ${map['id']}: $e');
          print('Error sincronizando checklist cortes ID ${map['id']}: $e');
        }
      }

      return {
        'success': failedCount == 0,
        'message': syncedCount > 0 
            ? '$syncedCount checklists de cortes sincronizados exitosamente'
            : 'No se pudieron sincronizar los checklists de cortes',
        'synced': syncedCount,
        'failed': failedCount,
        'errors': errors,
        'diagnosis': diagnosis,
      };
    } catch (e) {
      print('Error crítico en sincronización de cortes: $e');
      return {
        'success': false,
        'message': 'Error crítico en sincronización: $e',
        'synced': 0,
        'failed': 0,
        'error': e.toString(),
      };
    }
  }

  static Future<void> _sendChecklistToServer(ChecklistCortes checklist) async {
    if (checklist.id == null) throw Exception('ID del checklist es requerido');

    Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) throw Exception('Usuario no autenticado');
    String username = currentUser['username'] ?? '';

    // Escapar strings para SQL
    String escapedFinca = (checklist.finca?.nombre ?? '').replaceAll("'", "''");
    String escapedSupervisor = (checklist.supervisor ?? '').replaceAll("'", "''");
    String escapedCuadrantes = jsonEncode(checklist.cuadrantes.map((c) => c.toJson()).toList()).replaceAll("'", "''");
    String escapedItems = jsonEncode(checklist.items.map((item) => item.toJson()).toList()).replaceAll("'", "''");
    String escapedUser = username.replaceAll("'", "''");

    // Calcular métricas
    Map<String, dynamic> metricas = _calcularMetricas(checklist);

    // Construir query de inserción
    String query = '''
      INSERT INTO check_cortes (
        id_local, fecha, finca_nombre, supervisor, cuadrantes_json, 
        items_json, porcentaje_cumplimiento, total_evaluaciones, 
        total_conformes, total_no_conformes, usuario_creacion, fecha_creacion
      ) VALUES (
        ${checklist.id},
        '${checklist.fecha?.toIso8601String()}',
        '$escapedFinca',
        '$escapedSupervisor',
        '$escapedCuadrantes',
        '$escapedItems',
        ${checklist.calcularPorcentajeCumplimiento()},
        ${metricas['totalEvaluaciones']},
        ${metricas['totalConformes']},
        ${metricas['totalNoConformes']},
        '$escapedUser',
        '${DateTime.now().toIso8601String()}'
      )
    ''';

    await SqlServerService.executeQuery(query);
    print('Checklist cortes enviado al servidor exitosamente');
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
        SUM(COALESCE(total_evaluaciones, 0)) as total_evaluaciones_suma,
        SUM(COALESCE(total_conformes, 0)) as total_conformes_suma,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes_suma
      FROM check_cortes
      WHERE activo = 1
    ''');

    if (result.isNotEmpty) {
      var row = result.first;
      return {
        'totalChecklists': row['total_checklists'] ?? 0,
        'enviados': row['enviados'] ?? 0,
        'pendientes': row['pendientes'] ?? 0,
        'promedioCumplimiento': (row['promedio_cumplimiento'] as num? ?? 0.0).toDouble(),
        'mejorCumplimiento': (row['mejor_cumplimiento'] as num? ?? 0.0).toDouble(),
        'menorCumplimiento': (row['menor_cumplimiento'] as num? ?? 0.0).toDouble(),
        'fincasEvaluadas': row['fincas_evaluadas'] ?? 0,
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
      'totalEvaluacionesSuma': 0,
      'totalConformesSuma': 0,
      'totalNoConformesSuma': 0,
    };
  }

  static Future<List<Map<String, dynamic>>> getChecklistsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_cortes',
      where: 'date(fecha) BETWEEN date(?) AND date(?) AND activo = ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String(), 1],
      orderBy: 'fecha DESC',
    );

    return maps;
  }

  static Future<List<Map<String, dynamic>>> getChecklistsByFinca(String fincaNombre) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_cortes',
      where: 'finca_nombre = ? AND activo = ?',
      whereArgs: [fincaNombre, 1],
      orderBy: 'fecha DESC',
    );

    return maps;
  }

  static Future<List<Map<String, dynamic>>> getChecklistBySupervisor(String supervisor) async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_cortes',
      where: 'supervisor = ? AND activo = ?',
      whereArgs: [supervisor, 1],
      orderBy: 'fecha DESC',
    );

    return maps;
  }

  // ==================== REPORTES AVANZADOS ====================
  
  static Future<Map<String, dynamic>> getReportePorFinca() async {
    final db = await DatabaseHelper().database;
    
    final result = await db.rawQuery('''
      SELECT 
        finca_nombre,
        COUNT(*) as total_evaluaciones,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as mejor_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as peor_cumplimiento,
        COUNT(DISTINCT supervisor) as supervisores_distintos,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes
      FROM check_cortes
      WHERE activo = 1
      GROUP BY finca_nombre
      ORDER BY promedio_cumplimiento DESC
    ''');

    return {
      'reportePorFinca': result,
      'totalFincas': result.length,
    };
  }

  static Future<Map<String, dynamic>> getReportePorSupervisor() async {
    final db = await DatabaseHelper().database;
    
    final result = await db.rawQuery('''
      SELECT 
        supervisor,
        COUNT(*) as total_evaluaciones,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        MAX(COALESCE(porcentaje_cumplimiento, 0)) as mejor_cumplimiento,
        MIN(COALESCE(porcentaje_cumplimiento, 0)) as peor_cumplimiento,
        COUNT(DISTINCT finca_nombre) as fincas_atendidas,
        SUM(COALESCE(total_conformes, 0)) as total_conformes,
        SUM(COALESCE(total_no_conformes, 0)) as total_no_conformes
      FROM check_cortes
      WHERE activo = 1
      GROUP BY supervisor
      ORDER BY promedio_cumplimiento DESC
    ''');

    return {
      'reportePorSupervisor': result,
      'totalSupervisores': result.length,
    };
  }

  static Future<Map<String, dynamic>> getTendenciaTemporal(int ultimosDias) async {
    final db = await DatabaseHelper().database;
    
    DateTime fechaInicio = DateTime.now().subtract(Duration(days: ultimosDias));
    
    final result = await db.rawQuery('''
      SELECT 
        date(fecha) as fecha_evaluacion,
        COUNT(*) as total_evaluaciones,
        AVG(COALESCE(porcentaje_cumplimiento, 0)) as promedio_cumplimiento,
        SUM(COALESCE(total_conformes, 0)) as conformes_dia,
        SUM(COALESCE(total_no_conformes, 0)) as no_conformes_dia
      FROM check_cortes
      WHERE activo = 1 AND fecha >= ?
      GROUP BY date(fecha)
      ORDER BY fecha_evaluacion DESC
    ''', [fechaInicio.toIso8601String()]);

    return {
      'tendenciaTemporal': result,
      'periodoAnalizado': ultimosDias,
    };
  }

  // ==================== UTILIDADES PRIVADAS ====================
  
  static Map<String, dynamic> _calcularMetricas(ChecklistCortes checklist) {
    int totalEvaluaciones = 0;
    int totalConformes = 0;
    int totalNoConformes = 0;

    for (var item in checklist.items) {
      for (var cuadrante in checklist.cuadrantes) {
        for (int muestra = 1; muestra <= 10; muestra++) {
          String? resultado = item.getResultado(cuadrante.cuadrante, muestra);
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
  
  static ChecklistCortes _mapToChecklistCortes(Map<String, dynamic> map) {
    // Parsear cuadrantes
    List<CuadranteInfo> cuadrantes = [];
    if (map['cuadrantes_json'] != null && map['cuadrantes_json'].toString().isNotEmpty) {
      try {
        List<dynamic> cuadrantesData = jsonDecode(map['cuadrantes_json']);
        cuadrantes = cuadrantesData.map((c) => CuadranteInfo.fromJson(c)).toList();
      } catch (e) {
        print('Error parseando cuadrantes JSON: $e');
      }
    }

    // Parsear items
    List<ChecklistCortesItem> items = [];
    if (map['items_json'] != null && map['items_json'].toString().isNotEmpty) {
      try {
        List<dynamic> itemsData = jsonDecode(map['items_json']);
        items = itemsData.map((item) => ChecklistCortesItem.fromJson(item)).toList();
      } catch (e) {
        print('Error parseando items JSON: $e');
      }
    }

    // Crear finca si existe el nombre
    Finca? finca;
    if (map['finca_nombre'] != null && map['finca_nombre'].toString().isNotEmpty) {
      finca = Finca(nombre: map['finca_nombre'].toString());
    }

    return ChecklistCortes(
      id: map['id'],
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : null,
      finca: finca,
      supervisor: map['supervisor']?.toString(),
      cuadrantes: cuadrantes,
      items: items,
      fechaEnvio: map['fecha_envio'] != null ? DateTime.parse(map['fecha_envio']) : null,
      porcentajeCumplimiento: map['porcentaje_cumplimiento']?.toDouble(),
    );
  }

  // ==================== GENERACIÓN DE DATOS DE PRUEBA ====================
  
  // Método para generar datos de prueba para desarrollo
  static Future<Map<String, dynamic>> generateTestData() async {
    try {
      final db = await DatabaseHelper().database;
      
      // Verificar si ya hay datos
      final existingData = await db.rawQuery("SELECT COUNT(*) as count FROM check_cortes WHERE activo = 1");
      int existingCount = existingData.first['count'] as int? ?? 0;
      
      if (existingCount > 0) {
        return {
          'success': true,
          'message': 'Ya existen $existingCount registros de cortes',
          'count': existingCount,
        };
      }
      
      // Crear datos de prueba
      List<Map<String, dynamic>> testData = [
        {
          'fecha': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          'finca_nombre': 'Finca de Prueba 1',
          'supervisor': 'Supervisor Test',
          'cuadrantes_json': jsonEncode([
            {'cuadrante': 'A1', 'activo': true},
            {'cuadrante': 'A2', 'activo': true},
          ]),
          'items_json': jsonEncode([
            {
              'id': 1,
              'descripcion': 'Control de calidad',
              'resultados': {
                'A1': {'1': 'C', '2': 'C', '3': 'NC', '4': 'C', '5': 'C'},
                'A2': {'1': 'C', '2': 'C', '3': 'C', '4': 'C', '5': 'C'},
              }
            }
          ]),
          'porcentaje_cumplimiento': 85.0,
          'total_evaluaciones': 10,
          'total_conformes': 8,
          'total_no_conformes': 2,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'enviado': 0,
          'activo': 1,
        },
        {
          'fecha': DateTime.now().toIso8601String(),
          'finca_nombre': 'Finca de Prueba 2',
          'supervisor': 'Supervisor Test 2',
          'cuadrantes_json': jsonEncode([
            {'cuadrante': 'B1', 'activo': true},
            {'cuadrante': 'B2', 'activo': true},
          ]),
          'items_json': jsonEncode([
            {
              'id': 1,
              'descripcion': 'Control de calidad',
              'resultados': {
                'B1': {'1': 'C', '2': 'C', '3': 'C', '4': 'C', '5': 'C'},
                'B2': {'1': 'C', '2': 'C', '3': 'C', '4': 'C', '5': 'C'},
              }
            }
          ]),
          'porcentaje_cumplimiento': 100.0,
          'total_evaluaciones': 10,
          'total_conformes': 10,
          'total_no_conformes': 0,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'enviado': 0,
          'activo': 1,
        }
      ];
      
      // Insertar datos de prueba
      int insertedCount = 0;
      for (var data in testData) {
        await db.insert('check_cortes', data);
        insertedCount++;
      }
      
      print('Generados $insertedCount registros de prueba para cortes');
      
      return {
        'success': true,
        'message': 'Generados $insertedCount registros de prueba para cortes',
        'count': insertedCount,
      };
      
    } catch (e) {
      print('Error generando datos de prueba: $e');
      return {
        'success': false,
        'message': 'Error generando datos de prueba: $e',
        'error': e.toString(),
      };
    }
  }
  
  // ==================== UTILIDADES DE LIMPIEZA ====================
  
  static Future<void> cleanOldChecklists({int daysToKeep = 90}) async {
    final db = await DatabaseHelper().database;
    
    DateTime cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    // Soft delete de registros antiguos ya sincronizados
    int deletedCount = await db.update(
      'check_cortes',
      {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'fecha_creacion < ? AND enviado = ? AND activo = ?',
      whereArgs: [cutoffDate.toIso8601String(), 1, 1],
    );

    print('Marcados como eliminados $deletedCount checklists de cortes antiguos (más de $daysToKeep días)');
  }

  static Future<void> hardDeleteInactiveChecklists() async {
    final db = await DatabaseHelper().database;
    
    int deletedCount = await db.delete(
      'check_cortes',
      where: 'activo = ?',
      whereArgs: [0],
    );

    print('Eliminados físicamente $deletedCount checklists de cortes inactivos');
  }

  static Future<Map<String, dynamic>> exportChecklistsToJson() async {
    final db = await DatabaseHelper().database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_cortes',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'fecha_creacion DESC',
    );

    List<ChecklistCortes> checklists = maps.map((map) => _mapToChecklistCortes(map)).toList();
    Map<String, dynamic> stats = await getStatistics();
    
    Map<String, dynamic> exportData = {
      'export_metadata': {
        'export_date': DateTime.now().toIso8601String(),
        'total_records': checklists.length,
        'module': 'cortes_del_dia',
        'version': '1.0',
      },
      'statistics': stats,
      'checklists': checklists.map((c) => c.toJson()).toList(),
    };

    print('Datos de cortes preparados para exportar: ${checklists.length} registros');
    return exportData;
  }

  // ==================== VALIDACIONES Y DIAGNÓSTICOS ====================
  
  // Método de diagnóstico para identificar problemas de sincronización
  static Future<Map<String, dynamic>> diagnoseSyncIssues() async {
    try {
      final db = await DatabaseHelper().database;
      
      // Verificar si la tabla existe
      final tableExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='check_cortes'");
      bool tableExistsBool = tableExists.isNotEmpty;
      
      // Contar registros totales
      final totalRecords = await db.rawQuery("SELECT COUNT(*) as count FROM check_cortes");
      int totalCount = totalRecords.first['count'] as int? ?? 0;
      
      // Contar registros pendientes de sincronización
      final pendingRecords = await db.rawQuery("SELECT COUNT(*) as count FROM check_cortes WHERE enviado = 0 AND activo = 1");
      int pendingCount = pendingRecords.first['count'] as int? ?? 0;
      
      // Contar registros ya sincronizados
      final syncedRecords = await db.rawQuery("SELECT COUNT(*) as count FROM check_cortes WHERE enviado = 1 AND activo = 1");
      int syncedCount = syncedRecords.first['count'] as int? ?? 0;
      
      // Verificar conectividad
      bool hasInternet = await AuthService.hasInternetConnection();
      
      // Verificar autenticación
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      bool isAuthenticated = currentUser != null;
      
      return {
        'table_exists': tableExistsBool,
        'total_records': totalCount,
        'pending_sync': pendingCount,
        'already_synced': syncedCount,
        'has_internet': hasInternet,
        'is_authenticated': isAuthenticated,
        'diagnosis_date': DateTime.now().toIso8601String(),
        'can_sync': tableExistsBool && hasInternet && isAuthenticated && pendingCount > 0,
        'issues': _identifyIssues(tableExistsBool, totalCount, pendingCount, hasInternet, isAuthenticated),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'diagnosis_date': DateTime.now().toIso8601String(),
        'can_sync': false,
      };
    }
  }
  
  static List<String> _identifyIssues(bool tableExists, int totalRecords, int pendingRecords, bool hasInternet, bool isAuthenticated) {
    List<String> issues = [];
    
    if (!tableExists) {
      issues.add('La tabla check_cortes no existe en la base de datos local');
    }
    
    if (totalRecords == 0) {
      issues.add('No hay registros de cortes en la base de datos local');
    }
    
    if (pendingRecords == 0 && totalRecords > 0) {
      issues.add('Todos los registros ya están sincronizados');
    }
    
    if (!hasInternet) {
      issues.add('No hay conexión a internet');
    }
    
    if (!isAuthenticated) {
      issues.add('Usuario no autenticado');
    }
    
    return issues;
  }
  
  static Future<Map<String, dynamic>> validateDataIntegrity() async {
    final db = await DatabaseHelper().database;
    
    List<String> issues = [];
    Map<String, int> counters = {};
    
    // Validar registros con JSON malformado
    final invalidJson = await db.rawQuery('''
      SELECT id, finca_nombre FROM check_cortes 
      WHERE activo = 1 AND (
        cuadrantes_json IS NULL OR cuadrantes_json = '' OR
        items_json IS NULL OR items_json = ''
      )
    ''');
    
    if (invalidJson.isNotEmpty) {
      issues.add('${invalidJson.length} registros con JSON inválido');
      counters['invalid_json'] = invalidJson.length;
    }
    
    // Validar registros sin finca
    final noFinca = await db.rawQuery('''
      SELECT COUNT(*) as count FROM check_cortes 
      WHERE activo = 1 AND (finca_nombre IS NULL OR finca_nombre = '')
    ''');
    
    if (noFinca.isNotEmpty && (noFinca.first['count'] as int?)! > 0) {
      int count = noFinca.first['count'] as int;
      issues.add('$count registros sin finca especificada');
      counters['no_finca'] = count;
    }
    
    // Validar registros sin supervisor
    final noSupervisor = await db.rawQuery('''
      SELECT COUNT(*) as count FROM check_cortes 
      WHERE activo = 1 AND (supervisor IS NULL OR supervisor = '')
    ''');
    
    if (noSupervisor.isNotEmpty && (noSupervisor.first['count'] as int?)! > 0) {
      int count = noSupervisor.first['count'] as int;
      issues.add('$count registros sin supervisor especificado');
      counters['no_supervisor'] = count;
    }
    
    return {
      'is_valid': issues.isEmpty,
      'issues': issues,
      'counters': counters,
      'validation_date': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> repairDataIntegrity() async {
    final db = await DatabaseHelper().database;
    
    print('Iniciando reparación de integridad de datos de cortes...');
    
    // Reparar registros con JSON nulo o vacío
    await db.update(
      'check_cortes',
      {
        'cuadrantes_json': '[]',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'activo = 1 AND (cuadrantes_json IS NULL OR cuadrantes_json = "")',
    );
    
    await db.update(
      'check_cortes',
      {
        'items_json': '[]',
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'activo = 1 AND (items_json IS NULL OR items_json = "")',
    );
    
    // Marcar como inactivos registros sin datos críticos
    await db.update(
      'check_cortes',
      {
        'activo': 0,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      },
      where: 'activo = 1 AND (finca_nombre IS NULL OR finca_nombre = "" OR supervisor IS NULL OR supervisor = "")',
    );
    
    print('Reparación de integridad completada');
  }
}