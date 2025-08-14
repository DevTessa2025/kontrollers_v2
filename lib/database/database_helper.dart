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
      version: 4, // Incrementado para incluir las tablas de aplicaciones
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tablas existentes
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
    
    // Tablas para Cosecha
    await db.execute('''
      CREATE TABLE bloques_local (
        nombre TEXT NOT NULL,
        finca TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT,
        PRIMARY KEY (nombre, finca)
      )
    ''');
    await db.execute('''
      CREATE TABLE variedades_local (
        nombre TEXT NOT NULL,
        finca TEXT NOT NULL,
        bloque TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT,
        PRIMARY KEY (nombre, finca, bloque)
      )
    ''');
    
    // Tablas para Aplicaciones
    await _createAplicacionesTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Código de la versión 2 (tablas de supervisores, pesadores y fincas)
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
    
    if (oldVersion < 3) {
      // Código de la versión 3 (tablas de bloques y variedades)
      await db.execute('''
        CREATE TABLE bloques_local (
          nombre TEXT NOT NULL,
          finca TEXT NOT NULL,
          activo INTEGER DEFAULT 1,
          fecha_actualizacion TEXT,
          PRIMARY KEY (nombre, finca)
        )
      ''');
      await db.execute('''
        CREATE TABLE variedades_local (
          nombre TEXT NOT NULL,
          finca TEXT NOT NULL,
          bloque TEXT NOT NULL,
          activo INTEGER DEFAULT 1,
          fecha_actualizacion TEXT,
          PRIMARY KEY (nombre, finca, bloque)
        )
      ''');
    }
    
    if (oldVersion < 4) {
      // Código de la versión 4 (tablas de aplicaciones)
      await _createAplicacionesTables(db);
    }
  }

  // ==================== MÉTODOS EXISTENTES ====================

  // Métodos Usuarios
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
      await db.update('usuarios_local', user, where: 'id = ?', whereArgs: [user['id']]);
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

  // Métodos Supervisores
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
      await db.update('supervisores_local', supervisor, where: 'id = ?', whereArgs: [supervisor['id']]);
    } else {
      await db.insert('supervisores_local', supervisor);
    }
  }
  Future<List<Map<String, dynamic>>> getAllSupervisores() async {
    Database db = await database;
    return await db.query('supervisores_local', where: 'activo = 1', orderBy: 'nombre');
  }
  Future<Map<String, dynamic>?> getSupervisorById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('supervisores_local', where: 'id = ? AND activo = 1', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  Future<void> clearSupervisores() async {
    Database db = await database;
    await db.delete('supervisores_local');
  }

  // Métodos Pesadores
  Future<int> insertPesador(Map<String, dynamic> pesador) async {
    Database db = await database;
    return await db.insert('pesadores_local', pesador);
  }
  Future<void> insertOrUpdatePesador(Map<String, dynamic> pesador) async {
    Database db = await database;
    List<Map<String, dynamic>> existing = await db.query('pesadores_local', where: 'id = ?', whereArgs: [pesador['id']]);
    if (existing.isNotEmpty) {
      await db.update('pesadores_local', pesador, where: 'id = ?', whereArgs: [pesador['id']]);
    } else {
      await db.insert('pesadores_local', pesador);
    }
  }
  Future<List<Map<String, dynamic>>> getAllPesadores() async {
    Database db = await database;
    return await db.query('pesadores_local', where: 'activo = 1', orderBy: 'nombre');
  }
  Future<Map<String, dynamic>?> getPesadorById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('pesadores_local', where: 'id = ? AND activo = 1', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  Future<void> clearPesadores() async {
    Database db = await database;
    await db.delete('pesadores_local');
  }

  // Métodos Fincas
  Future<int> insertFinca(Map<String, dynamic> finca) async {
    Database db = await database;
    return await db.insert('fincas_local', finca);
  }
  Future<void> insertOrUpdateFinca(Map<String, dynamic> finca) async {
    Database db = await database;
    List<Map<String, dynamic>> existing = await db.query('fincas_local', where: 'nombre = ?', whereArgs: [finca['nombre']]);
    if (existing.isNotEmpty) {
      await db.update('fincas_local', finca, where: 'nombre = ?', whereArgs: [finca['nombre']]);
    } else {
      await db.insert('fincas_local', finca);
    }
  }
  Future<List<Map<String, dynamic>>> getAllFincas() async {
    Database db = await database;
    return await db.query('fincas_local', where: 'activo = 1', orderBy: 'nombre');
  }
  Future<Map<String, dynamic>?> getFincaByNombre(String nombre) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('fincas_local', where: 'nombre = ? AND activo = 1', whereArgs: [nombre]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  Future<void> clearFincas() async {
    Database db = await database;
    await db.delete('fincas_local');
  }

  // ==================== MÉTODOS PARA COSECHA ====================

  // Métodos Bloques
  Future<void> insertOrUpdateBloque(Map<String, dynamic> bloque) async {
    Database db = await database;
    List<Map<String, dynamic>> existing = await db.query('bloques_local', where: 'nombre = ? AND finca = ?', whereArgs: [bloque['nombre'], bloque['finca']]);
    if (existing.isNotEmpty) {
      await db.update('bloques_local', bloque, where: 'nombre = ? AND finca = ?', whereArgs: [bloque['nombre'], bloque['finca']]);
    } else {
      await db.insert('bloques_local', bloque);
    }
  }
  Future<List<Map<String, dynamic>>> getBloquesByFinca(String finca) async {
    Database db = await database;
    return await db.query('bloques_local', where: 'finca = ? AND activo = 1', whereArgs: [finca], orderBy: 'nombre');
  }
  Future<Map<String, dynamic>?> getBloqueByNombre(String nombre, String finca) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('bloques_local', where: 'nombre = ? AND finca = ? AND activo = 1', whereArgs: [nombre, finca]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  
  // MÉTODO FALTANTE: Obtener TODOS los bloques de cosecha
  Future<List<Map<String, dynamic>>> getAllBloques() async {
    Database db = await database;
    return await db.query(
      'bloques_local',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'finca, nombre',
    );
  }
  
  Future<void> clearBloques() async {
    Database db = await database;
    await db.delete('bloques_local');
  }

  // Métodos Variedades
  Future<void> insertOrUpdateVariedad(Map<String, dynamic> variedad) async {
    Database db = await database;
    List<Map<String, dynamic>> existing = await db.query('variedades_local', where: 'nombre = ? AND finca = ? AND bloque = ?', whereArgs: [variedad['nombre'], variedad['finca'], variedad['bloque']]);
    if (existing.isNotEmpty) {
      await db.update('variedades_local', variedad, where: 'nombre = ? AND finca = ? AND bloque = ?', whereArgs: [variedad['nombre'], variedad['finca'], variedad['bloque']]);
    } else {
      await db.insert('variedades_local', variedad);
    }
  }
  Future<List<Map<String, dynamic>>> getVariedadesByFincaAndBloque(String finca, String bloque) async {
    Database db = await database;
    return await db.query('variedades_local', where: 'finca = ? AND bloque = ? AND activo = 1', whereArgs: [finca, bloque], orderBy: 'nombre');
  }
  Future<Map<String, dynamic>?> getVariedadByNombre(String nombre, String finca, String bloque) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('variedades_local', where: 'nombre = ? AND finca = ? AND bloque = ? AND activo = 1', whereArgs: [nombre, finca, bloque]);
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  Future<void> clearVariedades() async {
    Database db = await database;
    await db.delete('variedades_local');
  }

  // ==================== MÉTODOS PARA APLICACIONES ====================

  // Crear tablas para aplicaciones
  Future<void> _createAplicacionesTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fincas_aplicaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bloques_aplicaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        finca TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT,
        UNIQUE(nombre, finca)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bombas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        finca TEXT NOT NULL,
        bloque TEXT NOT NULL,
        activo INTEGER DEFAULT 1,
        fecha_actualizacion TEXT,
        UNIQUE(nombre, finca, bloque)
      )
    ''');
  }

  // Métodos para fincas aplicaciones
  Future<int> insertOrUpdateFincaAplicaciones(Map<String, dynamic> finca) async {
    Database db = await database;
    return await db.insert(
      'fincas_aplicaciones',
      finca,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllFincasAplicaciones() async {
    Database db = await database;
    return await db.query(
      'fincas_aplicaciones',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'nombre',
    );
  }

  Future<Map<String, dynamic>?> getFincaAplicacionesByNombre(String nombre) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'fincas_aplicaciones',
      where: 'nombre = ? AND activo = ?',
      whereArgs: [nombre, 1],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> clearFincasAplicaciones() async {
    Database db = await database;
    await db.delete('fincas_aplicaciones');
  }

  // Métodos para bloques aplicaciones
  Future<int> insertOrUpdateBloqueAplicaciones(Map<String, dynamic> bloque) async {
    Database db = await database;
    return await db.insert(
      'bloques_aplicaciones',
      bloque,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBloquesByFincaAplicaciones(String finca) async {
    Database db = await database;
    return await db.query(
      'bloques_aplicaciones',
      where: 'finca = ? AND activo = ?',
      whereArgs: [finca, 1],
      orderBy: 'nombre',
    );
  }

  Future<Map<String, dynamic>?> getBloqueAplicacionesByNombre(String nombre, String finca) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bloques_aplicaciones',
      where: 'nombre = ? AND finca = ? AND activo = ?',
      whereArgs: [nombre, finca, 1],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  // MÉTODO FALTANTE: Obtener TODOS los bloques de aplicaciones
  Future<List<Map<String, dynamic>>> getAllBloquesAplicaciones() async {
    Database db = await database;
    return await db.query(
      'bloques_aplicaciones',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'finca, nombre',
    );
  }

  Future<void> clearBloquesAplicaciones() async {
    Database db = await database;
    await db.delete('bloques_aplicaciones');
  }

  // Métodos para bombas
  Future<int> insertOrUpdateBomba(Map<String, dynamic> bomba) async {
    Database db = await database;
    return await db.insert(
      'bombas',
      bomba,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBombasByFincaAndBloque(String finca, String bloque) async {
    Database db = await database;
    return await db.query(
      'bombas',
      where: 'finca = ? AND bloque = ? AND activo = ?',
      whereArgs: [finca, bloque, 1],
      orderBy: 'nombre',
    );
  }

  Future<Map<String, dynamic>?> getBombaByNombre(String nombre, String finca, String bloque) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bombas',
      where: 'nombre = ? AND finca = ? AND bloque = ? AND activo = ?',
      whereArgs: [nombre, finca, bloque, 1],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  // MÉTODO FALTANTE: Obtener TODAS las bombas
  Future<List<Map<String, dynamic>>> getAllBombas() async {
    Database db = await database;
    return await db.query(
      'bombas',
      where: 'activo = ?',
      whereArgs: [1],
      orderBy: 'finca, bloque, nombre',
    );
  }

  Future<void> clearBombas() async {
    Database db = await database;
    await db.delete('bombas');
  }

  // Estadísticas para aplicaciones
  Future<Map<String, int>> getAplicacionesDatabaseStats() async {
    Database db = await database;
    
    List<Map<String, dynamic>> fincasResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM fincas_aplicaciones WHERE activo = 1'
    );
    
    List<Map<String, dynamic>> bloquesResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bloques_aplicaciones WHERE activo = 1'
    );
    
    List<Map<String, dynamic>> bombasResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bombas WHERE activo = 1'
    );
    
    return {
      'fincas': fincasResult.first['count'] ?? 0,
      'bloques': bloquesResult.first['count'] ?? 0,
      'bombas': bombasResult.first['count'] ?? 0,
    };
  }

  // ==================== MÉTODOS GENERALES (Actualizados) ====================
  
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
  
  Future<Map<String, int>> getCosechaDatabaseStats() async {
    Database db = await database;
    List<Map<String, dynamic>> fincas = await db.rawQuery('SELECT COUNT(*) as count FROM fincas_local WHERE activo = 1');
    List<Map<String, dynamic>> bloques = await db.rawQuery('SELECT COUNT(*) as count FROM bloques_local WHERE activo = 1');
    List<Map<String, dynamic>> variedades = await db.rawQuery('SELECT COUNT(*) as count FROM variedades_local WHERE activo = 1');
    return {
      'fincas': fincas.first['count'] ?? 0,
      'bloques': bloques.first['count'] ?? 0,
      'variedades': variedades.first['count'] ?? 0,
    };
  }

  Future<void> clearAllData() async {
    Database db = await database;
    await db.delete('usuarios_local');
    await db.delete('supervisores_local');
    await db.delete('pesadores_local');
    await db.delete('fincas_local');
    await db.delete('bloques_local');
    await db.delete('variedades_local');
    await db.delete('fincas_aplicaciones');
    await db.delete('bloques_aplicaciones');
    await db.delete('bombas');
  }

  Future<void> close() async {
    Database db = await database;
    db.close();
  }
}