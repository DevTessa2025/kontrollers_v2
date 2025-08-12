import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/checklist_data_cosecha.dart';
import '../models/dropdown_models.dart';
import '../services/auth_service.dart';

class ChecklistCosechaStorageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'checklist_cosecha_local.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE checklist_cosecha (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        finca_nombre TEXT,
        bloque_nombre TEXT,
        variedad_nombre TEXT,
        usuario_id INTEGER,
        usuario_nombre TEXT,
        fecha_creacion TEXT NOT NULL,
        porcentaje_cumplimiento REAL,
        enviado INTEGER DEFAULT 0,
        
        -- Columnas para cada ítem (25 items para cosecha)
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
        
        item_12_respuesta TEXT,
        item_12_valor_numerico REAL,
        item_12_observaciones TEXT,
        item_12_foto_base64 TEXT,
        
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
        
        item_19_respuesta TEXT,
        item_19_valor_numerico REAL,
        item_19_observaciones TEXT,
        item_19_foto_base64 TEXT,
        
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
  }

  // Guardar checklist de cosecha localmente
  static Future<int> saveChecklistLocal(ChecklistCosecha checklist) async {
    try {
      Database db = await database;
      
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      
      Map<String, dynamic> record = {
        'finca_nombre': checklist.finca?.nombre,
        'bloque_nombre': checklist.bloque?.nombre,
        'variedad_nombre': checklist.variedad?.nombre,
        'usuario_id': currentUser?['id'],
        'usuario_nombre': currentUser?['nombre'] ?? currentUser?['username'],
        'fecha_creacion': DateTime.now().toIso8601String(),
        'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
        'enviado': 0,
      };

      for (var seccion in checklist.secciones) {
        for (var item in seccion.items) {
          record['item_${item.id}_respuesta'] = item.respuesta;
          record['item_${item.id}_valor_numerico'] = item.valorNumerico;
          record['item_${item.id}_observaciones'] = item.observaciones;
          record['item_${item.id}_foto_base64'] = item.fotoBase64;
        }
      }

      int id = await db.insert('checklist_cosecha', record);
      print('Checklist cosecha guardado localmente con ID: $id');
      return id;
    } catch (e) {
      print('Error guardando checklist cosecha local: $e');
      rethrow;
    }
  }

  // Actualizar checklist de cosecha existente
  static Future<void> updateChecklistLocal(int id, ChecklistCosecha checklist) async {
    try {
      Database db = await database;
      
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      
      Map<String, dynamic> record = {
        'finca_nombre': checklist.finca?.nombre,
        'bloque_nombre': checklist.bloque?.nombre,
        'variedad_nombre': checklist.variedad?.nombre,
        'usuario_id': currentUser?['id'],
        'usuario_nombre': currentUser?['nombre'] ?? currentUser?['username'],
        'fecha_creacion': checklist.fecha?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
        'enviado': 0, // Reiniciar estado de enviado al actualizar
      };

      for (var seccion in checklist.secciones) {
        for (var item in seccion.items) {
          record['item_${item.id}_respuesta'] = item.respuesta;
          record['item_${item.id}_valor_numerico'] = item.valorNumerico;
          record['item_${item.id}_observaciones'] = item.observaciones;
          record['item_${item.id}_foto_base64'] = item.fotoBase64;
        }
      }

      int rowsUpdated = await db.update(
        'checklist_cosecha',
        record,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (rowsUpdated > 0) {
        print('Checklist cosecha $id actualizado correctamente');
      } else {
        throw Exception('No se pudo actualizar el checklist cosecha con ID $id');
      }
    } catch (e) {
      print('Error actualizando checklist cosecha: $e');
      rethrow;
    }
  }

  // Obtener todos los checklist de cosecha locales
  static Future<List<Map<String, dynamic>>> getLocalChecklists() async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> records = await db.query(
        'checklist_cosecha',
        orderBy: 'fecha_creacion DESC',
      );
      
      return records;
    } catch (e) {
      print('Error obteniendo checklist cosecha locales: $e');
      return [];
    }
  }

  // Obtener checklist de cosecha por ID
  static Future<ChecklistCosecha?> getChecklistById(int id) async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> records = await db.query(
        'checklist_cosecha',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (records.isNotEmpty) {
        Map<String, dynamic> record = records.first;
        ChecklistCosecha checklist = ChecklistDataCosecha.getChecklistCosecha();
        
        checklist.finca = record['finca_nombre'] != null ? Finca(nombre: record['finca_nombre']) : null;
        checklist.bloque = record['bloque_nombre'] != null ? Bloque(nombre: record['bloque_nombre'], finca: record['finca_nombre']) : null;
        checklist.variedad = record['variedad_nombre'] != null ? Variedad(nombre: record['variedad_nombre'], finca: record['finca_nombre'], bloque: record['bloque_nombre']) : null;
        checklist.fecha = record['fecha_creacion'] != null ? DateTime.parse(record['fecha_creacion']) : null;

        for (var seccion in checklist.secciones) {
          for (var item in seccion.items) {
            int itemId = item.id;
            item.respuesta = record['item_${itemId}_respuesta'];
            item.valorNumerico = record['item_${itemId}_valor_numerico'];
            item.observaciones = record['item_${itemId}_observaciones'];
            item.fotoBase64 = record['item_${itemId}_foto_base64'];
          }
        }
        
        return checklist;
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo checklist cosecha por ID: $e');
      return null;
    }
  }

  // Verificar si un checklist de cosecha está completo
  static Future<bool> isChecklistComplete(int id) async {
    try {
      ChecklistCosecha? checklist = await getChecklistById(id);
      if (checklist == null) return false;
      
      for (var seccion in checklist.secciones) {
        for (var item in seccion.items) {
          if (item.respuesta == null) {
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('Error verificando completitud del checklist cosecha: $e');
      return false;
    }
  }

  // Marcar checklist de cosecha como enviado
  static Future<void> markAsEnviado(int id) async {
    try {
      Database db = await database;
      await db.update(
        'checklist_cosecha',
        {'enviado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Checklist cosecha $id marcado como enviado');
    } catch (e) {
      print('Error marcando checklist cosecha como enviado: $e');
      rethrow;
    }
  }

  // Eliminar checklist de cosecha local
  static Future<void> deleteLocalChecklist(int id) async {
    try {
      Database db = await database;
      await db.delete(
        'checklist_cosecha',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Checklist cosecha $id eliminado localmente');
    } catch (e) {
      print('Error eliminando checklist cosecha local: $e');
      rethrow;
    }
  }

  // Obtener estadísticas de checklist de cosecha locales
  static Future<Map<String, int>> getLocalStats() async {
    try {
      Database db = await database;
      
      List<Map<String, dynamic>> totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM checklist_cosecha'
      );
      
      List<Map<String, dynamic>> enviadosResult = await db.rawQuery(
        'SELECT COUNT(*) as enviados FROM checklist_cosecha WHERE enviado = 1'
      );
      
      int total = totalResult.first['total'] ?? 0;
      int enviados = enviadosResult.first['enviados'] ?? 0;
      int pendientes = total - enviados;
      
      // Calcular completos e incompletos
      List<Map<String, dynamic>> allRecords = await db.query('checklist_cosecha');
      int completos = 0;
      int incompletos = 0;
      
      for (Map<String, dynamic> record in allRecords) {
        bool isComplete = true;
        for (int i = 1; i <= 25; i++) { // 25 items en cosecha
          if (record['item_${i}_respuesta'] == null) {
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
      
      return {
        'total': total,
        'enviados': enviados,
        'pendientes': pendientes,
        'completos': completos,
        'incompletos': incompletos,
      };
    } catch (e) {
      print('Error obteniendo estadísticas cosecha: $e');
      return {
        'total': 0,
        'enviados': 0,
        'pendientes': 0,
        'completos': 0,
        'incompletos': 0,
      };
    }
  }

  // Limpiar checklist de cosecha enviados (opcional)
  static Future<void> cleanEnviadosChecklist() async {
    try {
      Database db = await database;
      await db.delete(
        'checklist_cosecha',
        where: 'enviado = 1',
      );
      print('Checklist cosecha enviados limpiados');
    } catch (e) {
      print('Error limpiando checklist cosecha enviados: $e');
      rethrow;
    }
  }
}