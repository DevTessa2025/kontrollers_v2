import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/checklist_data.dart';
import '../models/dropdown_models.dart';
import 'auth_service.dart';

class ChecklistStorageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'checklist_local.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE checklist_bodega (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        finca_nombre TEXT,
        supervisor_id INTEGER,
        supervisor_nombre TEXT,
        pesador_id INTEGER,
        pesador_nombre TEXT,
        usuario_id INTEGER,
        usuario_nombre TEXT,
        fecha_creacion TEXT NOT NULL,
        porcentaje_cumplimiento REAL,
        enviado INTEGER DEFAULT 0,
        
        -- Columnas para cada ítem
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
        item_20_foto_base64 TEXT
      )
    ''');
  }

  // Guardar checklist localmente
  static Future<int> saveChecklistLocal(ChecklistBodega checklist) async {
    try {
      Database db = await database;
      
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      
      Map<String, dynamic> record = {
        'finca_nombre': checklist.finca?.nombre,
        'supervisor_id': checklist.supervisor?.id,
        'supervisor_nombre': checklist.supervisor?.nombre,
        'pesador_id': checklist.pesador?.id,
        'pesador_nombre': checklist.pesador?.nombre,
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

      int id = await db.insert('checklist_bodega', record);
      print('Checklist guardado localmente con ID: $id');
      return id;
    } catch (e) {
      print('Error guardando checklist local: $e');
      rethrow;
    }
  }

  // Obtener todos los checklist locales
  static Future<List<Map<String, dynamic>>> getLocalChecklists() async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> records = await db.query(
        'checklist_bodega',
        orderBy: 'fecha_creacion DESC',
      );
      
      return records;
    } catch (e) {
      print('Error obteniendo checklist locales: $e');
      return [];
    }
  }

  // Obtener checklist por ID
  static Future<ChecklistBodega?> getChecklistById(int id) async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> records = await db.query(
        'checklist_bodega',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (records.isNotEmpty) {
        Map<String, dynamic> record = records.first;
        ChecklistBodega checklist = ChecklistDataBodega.getChecklistBodega();
        
        checklist.finca = record['finca_nombre'] != null ? Finca(nombre: record['finca_nombre']) : null;
        checklist.supervisor = record['supervisor_id'] != null ? Supervisor(id: record['supervisor_id'], nombre: record['supervisor_nombre']) : null;
        checklist.pesador = record['pesador_id'] != null ? Pesador(id: record['pesador_id'], nombre: record['pesador_nombre']) : null;
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
      print('Error obteniendo checklist por ID: $e');
      return null;
    }
  }

  // Marcar checklist como enviado
  static Future<void> markAsEnviado(int id) async {
    try {
      Database db = await database;
      await db.update(
        'checklist_bodega',
        {'enviado': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Checklist $id marcado como enviado');
    } catch (e) {
      print('Error marcando checklist como enviado: $e');
      rethrow;
    }
  }

  // Eliminar checklist local
  static Future<void> deleteLocalChecklist(int id) async {
    try {
      Database db = await database;
      await db.delete(
        'checklist_bodega',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('Checklist $id eliminado localmente');
    } catch (e) {
      print('Error eliminando checklist local: $e');
      rethrow;
    }
  }

  // Obtener estadísticas de checklist locales
  static Future<Map<String, int>> getLocalStats() async {
    try {
      Database db = await database;
      
      List<Map<String, dynamic>> totalResult = await db.rawQuery(
        'SELECT COUNT(*) as total FROM checklist_bodega'
      );
      
      List<Map<String, dynamic>> enviadosResult = await db.rawQuery(
        'SELECT COUNT(*) as enviados FROM checklist_bodega WHERE enviado = 1'
      );
      
      int total = totalResult.first['total'] ?? 0;
      int enviados = enviadosResult.first['enviados'] ?? 0;
      int pendientes = total - enviados;
      
      return {
        'total': total,
        'enviados': enviados,
        'pendientes': pendientes,
      };
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'enviados': 0,
        'pendientes': 0,
      };
    }
  }

  // Limpiar checklist enviados (opcional)
  static Future<void> cleanEnviadosChecklist() async {
    try {
      Database db = await database;
      await db.delete(
        'checklist_bodega',
        where: 'enviado = 1',
      );
      print('Checklist enviados limpiados');
    } catch (e) {
      print('Error limpiando checklist enviados: $e');
      rethrow;
    }
  }
}