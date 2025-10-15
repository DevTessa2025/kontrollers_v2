import '../data/checklist_data_fertirriego.dart';
import '../models/dropdown_models.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';

class ChecklistFertiriegoStorageService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Crear tabla si no existe (método auxiliar)
  static Future<void> _ensureTableExists() async {
    print('Verificando existencia de tabla checklist_fertirriego...');
    final db = await _databaseHelper.database;
    
    // Verificar si la tabla existe
    var result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='checklist_fertirriego'"
    );
    
    print('Resultado de verificación de tabla: $result');
    
    if (result.isEmpty) {
      print('Tabla no existe, creándola...');
      await _createTable(db);
      print('Tabla creada exitosamente');
    } else {
      print('Tabla ya existe');
    }
  }

  // Alias para compatibilidad con código existente
  static Future<void> markAsSynced(int id) async {
    return await markAsEnviado(id);
  }

  static Future<void> _createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_fertirriego (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        finca_nombre TEXT,
        bloque_nombre TEXT,
        usuario_id INTEGER,
        usuario_nombre TEXT,
        fecha_creacion TEXT NOT NULL,
        porcentaje_cumplimiento REAL,
        enviado INTEGER DEFAULT 0,
        fecha_envio TEXT,
        
        -- Columnas para cada ítem (IDs específicos de fertirriego)
        item_1_respuesta TEXT,
        item_1_valor_numerico REAL,
        item_1_observaciones TEXT,
        item_1_foto_base64 TEXT,
        
        item_2_respuesta TEXT,
        item_2_valor_numerico REAL,
        item_2_observaciones TEXT,
        item_2_foto_base64 TEXT,
        
        item_3_respuesta TEXT,
        item_3_valor_numerico REAL,
        item_3_observaciones TEXT,
        item_3_foto_base64 TEXT,
        
        item_4_respuesta TEXT,
        item_4_valor_numerico REAL,
        item_4_observaciones TEXT,
        item_4_foto_base64 TEXT,
        
        item_5_respuesta TEXT,
        item_5_valor_numerico REAL,
        item_5_observaciones TEXT,
        item_5_foto_base64 TEXT,
        
        item_6_respuesta TEXT,
        item_6_valor_numerico REAL,
        item_6_observaciones TEXT,
        item_6_foto_base64 TEXT,
        
        item_7_respuesta TEXT,
        item_7_valor_numerico REAL,
        item_7_observaciones TEXT,
        item_7_foto_base64 TEXT,
        
        item_8_respuesta TEXT,
        item_8_valor_numerico REAL,
        item_8_observaciones TEXT,
        item_8_foto_base64 TEXT,
        
        item_9_respuesta TEXT,
        item_9_valor_numerico REAL,
        item_9_observaciones TEXT,
        item_9_foto_base64 TEXT,
        
        item_10_respuesta TEXT,
        item_10_valor_numerico REAL,
        item_10_observaciones TEXT,
        item_10_foto_base64 TEXT,
        
        item_11_respuesta TEXT,
        item_11_valor_numerico REAL,
        item_11_observaciones TEXT,
        item_11_foto_base64 TEXT,
        
        item_13_respuesta TEXT,
        item_13_valor_numerico REAL,
        item_13_observaciones TEXT,
        item_13_foto_base64 TEXT,
        
        item_14_respuesta TEXT,
        item_14_valor_numerico REAL,
        item_14_observaciones TEXT,
        item_14_foto_base64 TEXT,
        
        item_15_respuesta TEXT,
        item_15_valor_numerico REAL,
        item_15_observaciones TEXT,
        item_15_foto_base64 TEXT,
        
        item_16_respuesta TEXT,
        item_16_valor_numerico REAL,
        item_16_observaciones TEXT,
        item_16_foto_base64 TEXT,
        
        item_17_respuesta TEXT,
        item_17_valor_numerico REAL,
        item_17_observaciones TEXT,
        item_17_foto_base64 TEXT,
        
        item_18_respuesta TEXT,
        item_18_valor_numerico REAL,
        item_18_observaciones TEXT,
        item_18_foto_base64 TEXT,
        
        item_20_respuesta TEXT,
        item_20_valor_numerico REAL,
        item_20_observaciones TEXT,
        item_20_foto_base64 TEXT,
        
        item_21_respuesta TEXT,
        item_21_valor_numerico REAL,
        item_21_observaciones TEXT,
        item_21_foto_base64 TEXT,
        
        item_22_respuesta TEXT,
        item_22_valor_numerico REAL,
        item_22_observaciones TEXT,
        item_22_foto_base64 TEXT,
        
        item_23_respuesta TEXT,
        item_23_valor_numerico REAL,
        item_23_observaciones TEXT,
        item_23_foto_base64 TEXT,
        
        item_24_respuesta TEXT,
        item_24_valor_numerico REAL,
        item_24_observaciones TEXT,
        item_24_foto_base64 TEXT,
        
        item_25_respuesta TEXT,
        item_25_valor_numerico REAL,
        item_25_observaciones TEXT,
        item_25_foto_base64 TEXT
      )
    ''');
    
    // Crear índices para mejorar performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fertirriego_fecha_creacion 
      ON checklist_fertirriego(fecha_creacion)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fertirriego_enviado 
      ON checklist_fertirriego(enviado)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fertirriego_finca_bloque 
      ON checklist_fertirriego(finca_nombre, bloque_nombre)
    ''');
    
    print('Tabla checklist_fertirriego creada exitosamente');
  }

  // Guardar checklist completo
  static Future<int> saveChecklist(ChecklistFertirriego checklist) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      final user = await AuthService.getCurrentUser();
      
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      Map<String, dynamic> data = {
        'finca_nombre': checklist.finca?.nombre,
        'bloque_nombre': checklist.bloque?.nombre,
        'usuario_id': user['id'],
        'usuario_nombre': user['nombre'],
        'fecha_creacion': (checklist.fecha ?? DateTime.now()).toIso8601String(),
        'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
        'enviado': 0,
      };

      // Agregar datos de cada ítem usando los IDs específicos de fertirriego
      List<int> validIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];
      
      for (var seccion in checklist.secciones) {
        for (var item in seccion.items) {
          if (validIds.contains(item.id)) {
            String prefix = 'item_${item.id}';
            data['${prefix}_respuesta'] = item.respuesta;
            data['${prefix}_valor_numerico'] = item.valorNumerico;
            data['${prefix}_observaciones'] = item.observaciones;
            data['${prefix}_foto_base64'] = item.fotoBase64;
          }
        }
      }

      int id = await db.insert('checklist_fertirriego', data);
      print('Checklist fertirriego guardado localmente con ID: $id');
      return id;
      
    } catch (e) {
      print('Error guardando checklist fertirriego: $e');
      rethrow;
    }
  }

  // Actualizar checklist existente
  static Future<void> updateChecklist(int id, ChecklistFertirriego checklist) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      final user = await AuthService.getCurrentUser();
      
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      Map<String, dynamic> data = {
        'finca_nombre': checklist.finca?.nombre,
        'bloque_nombre': checklist.bloque?.nombre,
        'usuario_id': user['id'],
        'usuario_nombre': user['nombre'],
        'fecha_creacion': (checklist.fecha ?? DateTime.now()).toIso8601String(),
        'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
        // No cambiar el estado enviado al actualizar
      };

      // Agregar datos de cada ítem
      List<int> validIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];
      
      for (var seccion in checklist.secciones) {
        for (var item in seccion.items) {
          if (validIds.contains(item.id)) {
            String prefix = 'item_${item.id}';
            data['${prefix}_respuesta'] = item.respuesta;
            data['${prefix}_valor_numerico'] = item.valorNumerico;
            data['${prefix}_observaciones'] = item.observaciones;
            data['${prefix}_foto_base64'] = item.fotoBase64;
          }
        }
      }

      int rowsUpdated = await db.update(
        'checklist_fertirriego',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (rowsUpdated > 0) {
        print('Checklist fertirriego $id actualizado correctamente');
      } else {
        throw Exception('No se pudo actualizar el checklist fertirriego con ID $id');
      }
      
    } catch (e) {
      print('Error actualizando checklist fertirriego: $e');
      rethrow;
    }
  }

  // Obtener checklists no enviados
  static Future<List<Map<String, dynamic>>> getUnsyncedChecklists() async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      final results = await db.query(
        'checklist_fertirriego',
        where: 'enviado = ?',
        whereArgs: [0],
        orderBy: 'fecha_creacion DESC',
      );
      
      print('Checklists fertirriego no sincronizados: ${results.length}');
      return results;
      
    } catch (e) {
      print('Error obteniendo checklists fertirriego no sincronizados: $e');
      return [];
    }
  }

  // Marcar como enviado (también disponible como markAsSynced para compatibilidad)
  static Future<void> markAsEnviado(int id) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      await db.update(
        'checklist_fertirriego',
        {
          'enviado': 1,
          'fecha_envio': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('Checklist fertirriego $id marcado como enviado');
      
    } catch (e) {
      print('Error marcando checklist fertirriego como enviado: $e');
      rethrow;
    }
  }

  // Obtener todos los checklists
  static Future<List<Map<String, dynamic>>> getAllChecklists() async {
    try {
      print('Iniciando getAllChecklists...');
      await _ensureTableExists();
      print('Tabla verificada/creada');
      final db = await _databaseHelper.database;
      print('Base de datos obtenida');
      
      final results = await db.query(
        'checklist_fertirriego',
        orderBy: 'fecha_creacion DESC',
      );
      
      print('Consulta ejecutada - Resultados: ${results.length}');
      if (results.isNotEmpty) {
        print('Primer registro: ${results.first}');
      }
      
      return results;
      
    } catch (e) {
      print('Error obteniendo todos los checklists fertirriego: $e');
      return [];
    }
  }

  // Obtener checklist por ID (devuelve Map para ser usado en la UI)
  static Future<Map<String, dynamic>?> getChecklistById(int id) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      final results = await db.query(
        'checklist_fertirriego',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (results.isNotEmpty) {
        return results.first;
      }
      
      return null;
      
    } catch (e) {
      print('Error obteniendo checklist fertirriego por ID: $e');
      return null;
    }
  }

  // Obtener checklist por ID como objeto ChecklistFertirriego
  static Future<ChecklistFertirriego?> getChecklistAsObjectById(int id) async {
    try {
      Map<String, dynamic>? data = await getChecklistById(id);
      if (data != null) {
        return fromDatabaseMap(data);
      }
      return null;
    } catch (e) {
      print('Error obteniendo checklist fertirriego como objeto: $e');
      return null;
    }
  }

  // Eliminar checklist
  static Future<void> deleteChecklist(int id) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      await db.delete(
        'checklist_fertirriego',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('Checklist fertirriego $id eliminado');
      
    } catch (e) {
      print('Error eliminando checklist fertirriego: $e');
      rethrow;
    }
  }

  // Convertir datos de BD a objeto ChecklistFertirriego
  static ChecklistFertirriego fromDatabaseMap(Map<String, dynamic> map) {
    ChecklistFertirriego checklist = ChecklistDataFertirriego.getChecklistFertirriego();
    
    // Asignar datos básicos
    if (map['finca_nombre'] != null) {
      checklist.finca = Finca(nombre: map['finca_nombre']);
    }
    if (map['bloque_nombre'] != null) {
      checklist.bloque = Bloque(nombre: map['bloque_nombre']);
    }
    if (map['fecha_creacion'] != null) {
      checklist.fecha = DateTime.parse(map['fecha_creacion']);
    }

    // Asignar datos de ítems usando los IDs específicos de fertirriego
    List<int> validIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];
    
    for (var seccion in checklist.secciones) {
      for (var item in seccion.items) {
        if (validIds.contains(item.id)) {
          String prefix = 'item_${item.id}';
          item.respuesta = map['${prefix}_respuesta'];
          item.valorNumerico = map['${prefix}_valor_numerico']?.toDouble();
          item.observaciones = map['${prefix}_observaciones'];
          item.fotoBase64 = map['${prefix}_foto_base64'];
        }
      }
    }

    return checklist;
  }

  // Verificar si un checklist está completo
  static Future<bool> isChecklistComplete(int id) async {
    try {
      Map<String, dynamic>? data = await getChecklistById(id);
      if (data == null) return false;
      
      // Los IDs válidos para fertirriego según la data class
      List<int> validIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];
      
      for (int itemId in validIds) {
        if (data['item_${itemId}_respuesta'] == null) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('Error verificando si checklist fertirriego está completo: $e');
      return false;
    }
  }

  // Obtener checklists por finca y bloque
  static Future<List<Map<String, dynamic>>> getChecklistsByFincaAndBloque(
    String finca, String bloque) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      final results = await db.query(
        'checklist_fertirriego',
        where: 'finca_nombre = ? AND bloque_nombre = ?',
        whereArgs: [finca, bloque],
        orderBy: 'fecha_creacion DESC',
      );
      
      return results;
      
    } catch (e) {
      print('Error obteniendo checklists fertirriego por finca y bloque: $e');
      return [];
    }
  }

  // Obtener checklists por usuario
  static Future<List<Map<String, dynamic>>> getChecklistsByUsuario(int usuarioId) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      final results = await db.query(
        'checklist_fertirriego',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
        orderBy: 'fecha_creacion DESC',
      );
      
      return results;
      
    } catch (e) {
      print('Error obteniendo checklists fertirriego por usuario: $e');
      return [];
    }
  }

  // Limpiar base de datos
  static Future<void> clearDatabase() async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      await db.delete('checklist_fertirriego');
      print('Base de datos fertirriego limpiada');
      
    } catch (e) {
      print('Error limpiando base de datos fertirriego: $e');
      rethrow;
    }
  }

  // Obtener estadísticas
  static Future<Map<String, dynamic>> getStats() async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checklist_fertirriego'
      );
      final unsyncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checklist_fertirriego WHERE enviado = 0'
      );
      final syncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checklist_fertirriego WHERE enviado = 1'
      );
      
      // Estadísticas adicionales
      final completedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checklist_fertirriego WHERE porcentaje_cumplimiento = 100'
      );
      
      final avgComplianceResult = await db.rawQuery(
        'SELECT AVG(porcentaje_cumplimiento) as avg FROM checklist_fertirriego'
      );
      
      return {
        'total': totalResult.first['count'] ?? 0,
        'unsynced': unsyncedResult.first['count'] ?? 0,
        'synced': syncedResult.first['count'] ?? 0,
        'completed': completedResult.first['count'] ?? 0,
        'avg_compliance': (avgComplianceResult.first['avg'] as double?)?.toDouble() ?? 0.0,
      };
      
    } catch (e) {
      print('Error obteniendo estadísticas fertirriego: $e');
      return {
        'total': 0,
        'unsynced': 0,
        'synced': 0,
        'completed': 0,
        'avg_compliance': 0.0,
      };
    }
  }

  // Obtener estadísticas por período
  static Future<Map<String, dynamic>> getStatsByPeriod({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (startDate != null && endDate != null) {
        whereClause = 'WHERE fecha_creacion >= ? AND fecha_creacion <= ?';
        whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
      } else if (startDate != null) {
        whereClause = 'WHERE fecha_creacion >= ?';
        whereArgs = [startDate.toIso8601String()];
      } else if (endDate != null) {
        whereClause = 'WHERE fecha_creacion <= ?';
        whereArgs = [endDate.toIso8601String()];
      }
      
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM checklist_fertirriego $whereClause',
        whereArgs
      );
      
      final avgResult = await db.rawQuery(
        'SELECT AVG(porcentaje_cumplimiento) as avg FROM checklist_fertirriego $whereClause',
        whereArgs
      );
      
      return {
        'total': totalResult.first['count'] ?? 0,
        'avg_compliance': (avgResult.first['avg'] as double?)?.toDouble() ?? 0.0,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      };
      
    } catch (e) {
      print('Error obteniendo estadísticas por período: $e');
      return {
        'total': 0,
        'avg_compliance': 0.0,
        'start_date': null,
        'end_date': null,
      };
    }
  }

  // Exportar datos para backup
  static Future<List<Map<String, dynamic>>> exportData() async {
    try {
      return await getAllChecklists();
    } catch (e) {
      print('Error exportando datos fertirriego: $e');
      return [];
    }
  }

  // Importar datos desde backup (usado para restauración)
  static Future<bool> importData(List<Map<String, dynamic>> data) async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      
      // Limpiar datos existentes
      await db.delete('checklist_fertirriego');
      
      // Insertar datos del backup
      for (Map<String, dynamic> record in data) {
        // Remover el ID para que se autogenere
        Map<String, dynamic> insertData = Map.from(record);
        insertData.remove('id');
        
        await db.insert('checklist_fertirriego', insertData);
      }
      
      print('Datos fertirriego importados exitosamente: ${data.length} registros');
      return true;
      
    } catch (e) {
      print('Error importando datos fertirriego: $e');
      return false;
    }
  }

  // Verificar integridad de datos
  static Future<Map<String, dynamic>> checkDataIntegrity() async {
    try {
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      
      // Verificar registros huérfanos (sin finca o bloque)
      final orphanedResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM checklist_fertirriego 
        WHERE finca_nombre IS NULL OR bloque_nombre IS NULL
      ''');
      
      // Verificar registros con datos inconsistentes
      final inconsistentResult = await db.rawQuery('''
        SELECT COUNT(*) as count FROM checklist_fertirriego 
        WHERE porcentaje_cumplimiento < 0 OR porcentaje_cumplimiento > 100
      ''');
      
      return {
        'orphaned_records': orphanedResult.first['count'] ?? 0,
        'inconsistent_records': inconsistentResult.first['count'] ?? 0,
        'healthy': (orphanedResult.first['count'] ?? 0) == 0 && 
                   (inconsistentResult.first['count'] ?? 0) == 0,
      };
      
    } catch (e) {
      print('Error verificando integridad de datos fertirriego: $e');
      return {
        'orphaned_records': 0,
        'inconsistent_records': 0,
        'healthy': false,
        'error': e.toString(),
      };
    }
  }

  // Obtener estadísticas locales (compatible con la UI modernizada)
  static Future<Map<String, int>> getLocalStats() async {
    try {
      print('Obteniendo estadísticas locales...');
      await _ensureTableExists();
      final db = await _databaseHelper.database;
      
      // Obtener estadísticas básicas
      List<Map<String, dynamic>> totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM checklist_fertirriego'
      );
      print('Total registros: ${totalResult.first['total']}');
      
      List<Map<String, dynamic>> enviadosResult = await db.rawQuery(
        'SELECT COUNT(*) as enviados FROM checklist_fertirriego WHERE enviado = 1'
      );
      print('Registros enviados: ${enviadosResult.first['enviados']}');
      
      // Obtener todos los registros para calcular completos/incompletos
      List<Map<String, dynamic>> allRecords = await db.query('checklist_fertirriego');
      print('Registros para análisis: ${allRecords.length}');
      
      int completos = 0;
      int incompletos = 0;
      
      // IDs válidos específicos del fertirriego
      List<int> validIds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];
      
      for (var record in allRecords) {
        bool isComplete = true;
        
        // Verificar si todos los items válidos tienen respuesta
        for (int id in validIds) {
          if (record['item_${id}_respuesta'] == null) {
            isComplete = false;
            break;
          }
        }
        
        if (isComplete) {
          completos++;
        } else {
          incompletos++;
        }
      }
      
      Map<String, int> stats = {
        'total': totalResult.first['total'] ?? 0,
        'completos': completos,
        'incompletos': incompletos,
        'enviados': enviadosResult.first['enviados'] ?? 0,
      };
      
      print('Estadísticas calculadas: $stats');
      return stats;
      
    } catch (e) {
      print('Error obteniendo estadísticas locales de fertirriego: $e');
      return {
        'total': 0,
        'completos': 0,
        'incompletos': 0,
        'enviados': 0,
      };
    }
  }
}