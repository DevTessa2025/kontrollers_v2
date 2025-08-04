import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'kontrollers_local.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios_local (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        nombre TEXT,
        email TEXT,
        activo INTEGER DEFAULT 1,
        fecha_creacion TEXT,
        fecha_actualizacion TEXT
      )
    ''');
  }

  // Insertar usuario
  Future<int> insertUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.insert('usuarios_local', user);
  }

  // Obtener usuario por username y password
  Future<Map<String, dynamic>?> getUser(String username, String password) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'usuarios_local',
      where: 'username = ? AND password = ? AND activo = 1',
      whereArgs: [username, password],
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Obtener usuario por ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'usuarios_local',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Actualizar usuario
  Future<int> updateUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.update(
      'usuarios_local',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  // Insertar o actualizar usuario (upsert)
  Future<void> insertOrUpdateUser(Map<String, dynamic> user) async {
    Database db = await database;
    
    // Verificar si el usuario ya existe
    List<Map<String, dynamic>> existing = await db.query(
      'usuarios_local',
      where: 'id = ?',
      whereArgs: [user['id']],
    );
    
    if (existing.isNotEmpty) {
      // Actualizar
      await db.update(
        'usuarios_local',
        user,
        where: 'id = ?',
        whereArgs: [user['id']],
      );
    } else {
      // Insertar
      await db.insert('usuarios_local', user);
    }
  }

  // Limpiar todos los usuarios (para sincronización)
  Future<void> clearUsers() async {
    Database db = await database;
    await db.delete('usuarios_local');
  }

  // Obtener todos los usuarios
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    Database db = await database;
    return await db.query('usuarios_local');
  }

  // Cerrar base de datos
  Future<void> close() async {
    Database db = await database;
    db.close();
  }
}