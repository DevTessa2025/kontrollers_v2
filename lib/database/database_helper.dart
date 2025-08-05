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
      version: 2, // Incrementar versión para agregar nuevas tablas
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de usuarios (existente)
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

    // Tabla de supervisores
    await db.execute('''
      CREATE TABLE supervisores_local (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        cedula TEXT,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT
      )
    ''');

    // Tabla de pesadores
    await db.execute('''
      CREATE TABLE pesadores_local (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        cedula TEXT,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT
      )
    ''');

    // Tabla de fincas
    await db.execute('''
      CREATE TABLE fincas_local (
        nombre TEXT PRIMARY KEY,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar las nuevas tablas en la actualización
      await db.execute('''
        CREATE TABLE supervisores_local (
          id INTEGER PRIMARY KEY,
          nombre TEXT NOT NULL,
          cedula TEXT,
          activo INTEGER DEFAULT 1,
          fecha_actualizacion TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE pesadores_local (
          id INTEGER PRIMARY KEY,
          nombre TEXT NOT NULL,
          cedula TEXT,
          activo INTEGER DEFAULT 1,
          fecha_actualizacion TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE fincas_local (
          nombre TEXT PRIMARY KEY,
          activo INTEGER DEFAULT 1,
          fecha_actualizacion TEXT
        )
      ''');
    }
  }

  // ==================== MÉTODOS USUARIOS (existentes) ====================
  
  Future<int> insertUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.insert('usuarios_local', user);
  }

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

  Future<int> updateUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.update(
      'usuarios_local',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  Future<void> insertOrUpdateUser(Map<String, dynamic> user) async {
    Database db = await database;
    
    List<Map<String, dynamic>> existing = await db.query(
      'usuarios_local',
      where: 'id = ?',
      whereArgs: [user['id']],
    );
    
    if (existing.isNotEmpty) {
      await db.update(
        'usuarios_local',
        user,
        where: 'id = ?',
        whereArgs: [user['id']],
      );
    } else {
      await db.insert('usuarios_local', user);
    }
  }

  Future<void> clearUsers() async {
    Database db = await database;
    await db.delete('usuarios_local');
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    Database db = await database;
    return await db.query('usuarios_local');
  }

  // ==================== MÉTODOS SUPERVISORES ====================
  
  Future<int> insertSupervisor(Map<String, dynamic> supervisor) async {
    Database db = await database;
    return await db.insert('supervisores_local', supervisor);
  }

  Future<void> insertOrUpdateSupervisor(Map<String, dynamic> supervisor) async {
    Database db = await database;
    
    List<Map<String, dynamic>> existing = await db.query(
      'supervisores_local',
      where: 'id = ?',
      whereArgs: [supervisor['id']],
    );
    
    if (existing.isNotEmpty) {
      await db.update(
        'supervisores_local',
        supervisor,
        where: 'id = ?',
        whereArgs: [supervisor['id']],
      );
    } else {
      await db.insert('supervisores_local', supervisor);
    }
  }

  Future<List<Map<String, dynamic>>> getAllSupervisores() async {
    Database db = await database;
    return await db.query(
      'supervisores_local',
      where: 'activo = 1',
      orderBy: 'nombre',
    );
  }

  Future<Map<String, dynamic>?> getSupervisorById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'supervisores_local',
      where: 'id = ? AND activo = 1',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> clearSupervisores() async {
    Database db = await database;
    await db.delete('supervisores_local');
  }

  // ==================== MÉTODOS PESADORES ====================
  
  Future<int> insertPesador(Map<String, dynamic> pesador) async {
    Database db = await database;
    return await db.insert('pesadores_local', pesador);
  }

  Future<void> insertOrUpdatePesador(Map<String, dynamic> pesador) async {
    Database db = await database;
    
    List<Map<String, dynamic>> existing = await db.query(
      'pesadores_local',
      where: 'id = ?',
      whereArgs: [pesador['id']],
    );
    
    if (existing.isNotEmpty) {
      await db.update(
        'pesadores_local',
        pesador,
        where: 'id = ?',
        whereArgs: [pesador['id']],
      );
    } else {
      await db.insert('pesadores_local', pesador);
    }
  }

  Future<List<Map<String, dynamic>>> getAllPesadores() async {
    Database db = await database;
    return await db.query(
      'pesadores_local',
      where: 'activo = 1',
      orderBy: 'nombre',
    );
  }

  Future<Map<String, dynamic>?> getPesadorById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'pesadores_local',
      where: 'id = ? AND activo = 1',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> clearPesadores() async {
    Database db = await database;
    await db.delete('pesadores_local');
  }

  // ==================== MÉTODOS FINCAS ====================
  
  Future<int> insertFinca(Map<String, dynamic> finca) async {
    Database db = await database;
    return await db.insert('fincas_local', finca);
  }

  Future<void> insertOrUpdateFinca(Map<String, dynamic> finca) async {
    Database db = await database;
    
    List<Map<String, dynamic>> existing = await db.query(
      'fincas_local',
      where: 'nombre = ?',
      whereArgs: [finca['nombre']],
    );
    
    if (existing.isNotEmpty) {
      await db.update(
        'fincas_local',
        finca,
        where: 'nombre = ?',
        whereArgs: [finca['nombre']],
      );
    } else {
      await db.insert('fincas_local', finca);
    }
  }

  Future<List<Map<String, dynamic>>> getAllFincas() async {
    Database db = await database;
    return await db.query(
      'fincas_local',
      where: 'activo = 1',
      orderBy: 'nombre',
    );
  }

  Future<Map<String, dynamic>?> getFincaByNombre(String nombre) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'fincas_local',
      where: 'nombre = ? AND activo = 1',
      whereArgs: [nombre],
    );
    
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> clearFincas() async {
    Database db = await database;
    await db.delete('fincas_local');
  }

  // ==================== MÉTODOS GENERALES ====================
  
  // Obtener estadísticas de la base de datos
  Future<Map<String, int>> getDatabaseStats() async {
    Database db = await database;
    
    List<Map<String, dynamic>> usuarios = await db.rawQuery('SELECT COUNT(*) as count FROM usuarios_local WHERE activo = 1');
    List<Map<String, dynamic>> supervisores = await db.rawQuery('SELECT COUNT(*) as count FROM supervisores_local WHERE activo = 1');
    List<Map<String, dynamic>> pesadores = await db.rawQuery('SELECT COUNT(*) as count FROM pesadores_local WHERE activo = 1');
    List<Map<String, dynamic>> fincas = await db.rawQuery('SELECT COUNT(*) as count FROM fincas_local WHERE activo = 1');
    
    return {
      'usuarios': usuarios.first['count'] ?? 0,
      'supervisores': supervisores.first['count'] ?? 0,
      'pesadores': pesadores.first['count'] ?? 0,
      'fincas': fincas.first['count'] ?? 0,
    };
  }

  // Limpiar todos los datos (para resync completo)
  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('usuarios_local');
    await db.delete('supervisores_local');
    await db.delete('pesadores_local');
    await db.delete('fincas_local');
  }

  // Cerrar base de datos
  Future<void> close() async {
    Database db = await database;
    db.close();
  }
}