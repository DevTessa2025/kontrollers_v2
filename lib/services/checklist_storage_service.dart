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
        titulo TEXT NOT NULL,
        subtitulo TEXT NOT NULL,
        finca_nombre TEXT,
        supervisor_id INTEGER,
        supervisor_nombre TEXT,
        pesador_id INTEGER,
        pesador_nombre TEXT,
        usuario_id INTEGER,
        usuario_nombre TEXT,
        fecha_creacion TEXT NOT NULL,
        porcentaje_cumplimiento REAL,
        checklist_data TEXT NOT NULL,
        enviado INTEGER DEFAULT 0
      )
    ''');
  }

  // Guardar checklist localmente
  static Future<int> saveChecklistLocal(ChecklistBodega checklist) async {
    try {
      Database db = await database;
      
      // Obtener información del usuario actual
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      
      Map<String, dynamic> record = {
        'titulo': checklist.titulo,
        'subtitulo': checklist.subtitulo,
        'finca_nombre': checklist.finca?.nombre,
        'supervisor_id': checklist.supervisor?.id,
        'supervisor_nombre': checklist.supervisor?.nombre,
        'pesador_id': checklist.pesador?.id,
        'pesador_nombre': checklist.pesador?.nombre,
        'usuario_id': currentUser?['id'],
        'usuario_nombre': currentUser?['nombre'] ?? currentUser?['username'],
        'fecha_creacion': DateTime.now().toIso8601String(),
        'porcentaje_cumplimiento': checklist.calcularPorcentajeCumplimiento(),
        'checklist_data': jsonEncode(checklist.toJson()),
        'enviado': 0,
      };

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
        String checklistData = records.first['checklist_data'];
        Map<String, dynamic> json = jsonDecode(checklistData);
        return ChecklistBodega.fromJson(json);
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