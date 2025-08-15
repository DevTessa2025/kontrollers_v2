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
      version: 5, // Incrementado para incluir índices y métodos faltantes
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
    
    // Crear índices de performance
    await _createPerformanceIndexes(db);
    
    // Crear tabla de metadatos
    await _createMetadataTables(db);
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
    
    if (oldVersion < 5) {
      // Código de la versión 5 (índices y metadatos)
      await _createPerformanceIndexes(db);
      await _createMetadataTables(db);
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
  
  // Obtener TODOS los bloques de cosecha
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

  // Crear tabla de metadatos
  Future<void> _createMetadataTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT
      )
    ''');
  }

  // Crear índices para mejorar performance
  Future<void> _createPerformanceIndexes(Database db) async {
    try {
      // Índices para fincas aplicaciones
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_fincas_aplicaciones_nombre 
        ON fincas_aplicaciones(nombre) WHERE activo = 1
      ''');
      
      // Índices para bloques aplicaciones
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bloques_aplicaciones_finca 
        ON bloques_aplicaciones(finca) WHERE activo = 1
      ''');
      
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bloques_aplicaciones_finca_nombre 
        ON bloques_aplicaciones(finca, nombre) WHERE activo = 1
      ''');
      
      // Índices para bombas
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bombas_finca_bloque 
        ON bombas(finca, bloque) WHERE activo = 1
      ''');
      
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bombas_finca_bloque_nombre 
        ON bombas(finca, bloque, nombre) WHERE activo = 1
      ''');
      
      // Índice para fechas de actualización
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bombas_fecha_actualizacion 
        ON bombas(fecha_actualizacion) WHERE activo = 1
      ''');
      
      print('Índices de performance creados exitosamente');
      
    } catch (e) {
      print('Error creando índices: $e');
    }
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

  // Obtener TODOS los bloques de aplicaciones
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

  // Obtener TODAS las bombas
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

  // ==================== MÉTODOS DE BÚSQUEDA PARA COSECHA ====================

// Buscar fincas de cosecha por patrón de texto
Future<List<Map<String, dynamic>>> searchFincas(String searchPattern) async {
  Database db = await database;
  return await db.query(
    'fincas_local',
    where: 'nombre LIKE ? AND activo = ?',
    whereArgs: ['%$searchPattern%', 1],
    orderBy: 'nombre',
  );
}

// Buscar bloques de cosecha por patrón de texto y finca
Future<List<Map<String, dynamic>>> searchBloques(String finca, String searchPattern) async {
  Database db = await database;
  return await db.query(
    'bloques_local',
    where: 'finca = ? AND nombre LIKE ? AND activo = ?',
    whereArgs: [finca, '%$searchPattern%', 1],
    orderBy: 'nombre',
  );
}

// Buscar variedades de cosecha por patrón de texto
Future<List<Map<String, dynamic>>> searchVariedades(String finca, String bloque, String searchPattern) async {
  Database db = await database;
  return await db.query(
    'variedades_local',
    where: 'finca = ? AND bloque = ? AND nombre LIKE ? AND activo = ?',
    whereArgs: [finca, bloque, '%$searchPattern%', 1],
    orderBy: 'nombre',
  );
}

// ==================== MÉTODOS DE BÚSQUEDA PARA APLICACIONES ====================

// Buscar fincas de aplicaciones por patrón de texto
Future<List<Map<String, dynamic>>> searchFincasAplicaciones(String searchPattern) async {
  Database db = await database;
  return await db.query(
    'fincas_aplicaciones',
    where: 'nombre LIKE ? AND activo = ?',
    whereArgs: ['%$searchPattern%', 1],
    orderBy: 'nombre',
  );
}

// Buscar bloques de aplicaciones por patrón de texto y finca
Future<List<Map<String, dynamic>>> searchBloquesAplicaciones(String finca, String searchPattern) async {
  Database db = await database;
  return await db.query(
    'bloques_aplicaciones',
    where: 'finca = ? AND nombre LIKE ? AND activo = ?',
    whereArgs: [finca, '%$searchPattern%', 1],
    orderBy: 'nombre',
  );
}

// Buscar bombas por patrón de texto
Future<List<Map<String, dynamic>>> searchBombas(String finca, String bloque, String searchPattern) async {
  Database db = await database;
  return await db.query(
    'bombas',
    where: 'finca = ? AND bloque = ? AND nombre LIKE ? AND activo = ?',
    whereArgs: [finca, bloque, '%$searchPattern%', 1],
    orderBy: 'nombre',
  );
}



  // ==================== MÉTODOS FALTANTES AGREGADOS ====================

  // Verificar fincas que no tienen bloques asociados
  Future<List<Map<String, dynamic>>> getFincasSinBloques() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT f.nombre, f.fecha_actualizacion
      FROM fincas_aplicaciones f
      LEFT JOIN bloques_aplicaciones b ON f.nombre = b.finca AND b.activo = 1
      WHERE f.activo = 1 AND b.finca IS NULL
      ORDER BY f.nombre
    ''');
  }

  // Verificar bloques que no tienen bombas asociadas
  Future<List<Map<String, dynamic>>> getBloquesSinBombas() async {
    Database db = await database;
    return await db.rawQuery('''
      SELECT b.nombre, b.finca, b.fecha_actualizacion
      FROM bloques_aplicaciones b
      LEFT JOIN bombas bo ON b.finca = bo.finca AND b.nombre = bo.bloque AND bo.activo = 1
      WHERE b.activo = 1 AND bo.finca IS NULL
      ORDER BY b.finca, b.nombre
    ''');
  }

  // Verificar datos duplicados
  Future<Map<String, int>> checkDuplicateData() async {
    Database db = await database;
    
    // Duplicados en fincas aplicaciones
    List<Map<String, dynamic>> fincasDuplicadas = await db.rawQuery('''
      SELECT nombre, COUNT(*) as count
      FROM fincas_aplicaciones
      WHERE activo = 1
      GROUP BY nombre
      HAVING COUNT(*) > 1
    ''');
    
    // Duplicados en bloques aplicaciones
    List<Map<String, dynamic>> bloquesDuplicados = await db.rawQuery('''
      SELECT nombre, finca, COUNT(*) as count
      FROM bloques_aplicaciones
      WHERE activo = 1
      GROUP BY nombre, finca
      HAVING COUNT(*) > 1
    ''');
    
    // Duplicados en bombas
    List<Map<String, dynamic>> bombasDuplicadas = await db.rawQuery('''
      SELECT nombre, finca, bloque, COUNT(*) as count
      FROM bombas
      WHERE activo = 1
      GROUP BY nombre, finca, bloque
      HAVING COUNT(*) > 1
    ''');
    
    return {
      'fincas_duplicadas': fincasDuplicadas.length,
      'bloques_duplicados': bloquesDuplicados.length,
      'bombas_duplicadas': bombasDuplicadas.length,
    };
  }

  // Obtener fecha de última sincronización
  Future<DateTime?> getLastSyncDate() async {
    Database db = await database;
    
    // Buscar la fecha más reciente entre todas las tablas
    List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT MAX(fecha_actualizacion) as last_sync FROM (
        SELECT fecha_actualizacion FROM fincas_aplicaciones WHERE fecha_actualizacion IS NOT NULL
        UNION ALL
        SELECT fecha_actualizacion FROM bloques_aplicaciones WHERE fecha_actualizacion IS NOT NULL
        UNION ALL
        SELECT fecha_actualizacion FROM bombas WHERE fecha_actualizacion IS NOT NULL
      )
    ''');
    
    if (result.isNotEmpty && result.first['last_sync'] != null) {
      try {
        return DateTime.parse(result.first['last_sync']);
      } catch (e) {
        print('Error parsing last sync date: $e');
        return null;
      }
    }
    
    return null;
  }

  // Actualizar timestamp de sincronización
  Future<void> updateSyncTimestamp() async {
    Database db = await database;
    String timestamp = DateTime.now().toIso8601String();
    
    await db.insert(
      'sync_metadata',
      {
        'key': 'last_full_sync',
        'value': timestamp,
        'updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Limpiar datos antiguos basado en fecha
  Future<void> cleanOldAplicacionesData(String cutoffDate) async {
    Database db = await database;
    
    // Marcar como inactivos los datos antiguos en lugar de eliminarlos
    await db.update(
      'fincas_aplicaciones',
      {'activo': 0, 'fecha_actualizacion': DateTime.now().toIso8601String()},
      where: 'fecha_actualizacion < ?',
      whereArgs: [cutoffDate],
    );
    
    await db.update(
      'bloques_aplicaciones',
      {'activo': 0, 'fecha_actualizacion': DateTime.now().toIso8601String()},
      where: 'fecha_actualizacion < ?',
      whereArgs: [cutoffDate],
    );
    
    await db.update(
      'bombas',
      {'activo': 0, 'fecha_actualizacion': DateTime.now().toIso8601String()},
      where: 'fecha_actualizacion < ?',
      whereArgs: [cutoffDate],
    );
    
    print('Datos antiguos marcados como inactivos (antes de $cutoffDate)');
  }

  // Optimizar base de datos (VACUUM y REINDEX)
  Future<void> optimizeDatabase() async {
    Database db = await database;
    
    try {
      // VACUUM para recuperar espacio
      await db.execute('VACUUM');
      print('VACUUM ejecutado exitosamente');
      
      // REINDEX para optimizar índices
      await db.execute('REINDEX');
      print('REINDEX ejecutado exitosamente');
      
      await updateSyncTimestamp();
    } catch (e) {
      print('Error optimizando base de datos: $e');
    }
  }

  // // Buscar fincas por patrón de texto
  // Future<List<Map<String, dynamic>>> searchFincas(String searchPattern) async {
  //   Database db = await database;
  //   return await db.query(
  //     'fincas_aplicaciones',
  //     where: 'nombre LIKE ? AND activo = ?',
  //     whereArgs: ['%$searchPattern%', 1],
  //     orderBy: 'nombre',
  //   );
  // }

  // // Buscar bloques por patrón de texto y finca
  // Future<List<Map<String, dynamic>>> searchBloques(String finca, String searchPattern) async {
  //   Database db = await database;
  //   return await db.query(
  //     'bloques_aplicaciones',
  //     where: 'finca = ? AND nombre LIKE ? AND activo = ?',
  //     whereArgs: [finca, '%$searchPattern%', 1],
  //     orderBy: 'nombre',
  //   );
  // }

  // // Buscar bombas por patrón de texto
  // Future<List<Map<String, dynamic>>> searchBombas(String finca, String bloque, String searchPattern) async {
  //   Database db = await database;
  //   return await db.query(
  //     'bombas',
  //     where: 'finca = ? AND bloque = ? AND nombre LIKE ? AND activo = ?',
  //     whereArgs: [finca, bloque, '%$searchPattern%', 1],
  //     orderBy: 'nombre',
  //   );
  // }

  // Verificar si los datos están actualizados (dentro del tiempo de cache)
  Future<bool> isCacheValid(String tableName, String? finca, {Duration cacheTime = const Duration(hours: 1)}) async {
    Database db = await database;
    
    String query;
    List<dynamic> whereArgs = [];
    
    switch (tableName) {
      case 'fincas_aplicaciones':
        query = 'SELECT MAX(fecha_actualizacion) as last_update FROM fincas_aplicaciones WHERE activo = 1';
        break;
      case 'bloques_aplicaciones':
        if (finca != null) {
          query = 'SELECT MAX(fecha_actualizacion) as last_update FROM bloques_aplicaciones WHERE finca = ? AND activo = 1';
          whereArgs = [finca];
        } else {
          query = 'SELECT MAX(fecha_actualizacion) as last_update FROM bloques_aplicaciones WHERE activo = 1';
        }
        break;
      case 'bombas':
        if (finca != null) {
          query = 'SELECT MAX(fecha_actualizacion) as last_update FROM bombas WHERE finca = ? AND activo = 1';
          whereArgs = [finca];
        } else {
          query = 'SELECT MAX(fecha_actualizacion) as last_update FROM bombas WHERE activo = 1';
        }
        break;
      default:
        return false;
    }
    
    List<Map<String, dynamic>> result = await db.rawQuery(query, whereArgs);
    
    if (result.isNotEmpty && result.first['last_update'] != null) {
      try {
        DateTime lastUpdate = DateTime.parse(result.first['last_update']);
        DateTime now = DateTime.now();
        return now.difference(lastUpdate) <= cacheTime;
      } catch (e) {
        print('Error parsing cache date: $e');
        return false;
      }
    }
    
    return false;
  }

  // Obtener tamaño de la base de datos
  Future<Map<String, dynamic>> getDatabaseSize() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'kontrollers_local.db');
      File dbFile = File(path);
      
      if (await dbFile.exists()) {
        int sizeInBytes = await dbFile.length();
        double sizeInMB = sizeInBytes / (1024 * 1024);
        
        return {
          'size_bytes': sizeInBytes,
          'size_mb': double.parse(sizeInMB.toStringAsFixed(2)),
          'path': path,
          'exists': true,
        };
      } else {
        return {
          'size_bytes': 0,
          'size_mb': 0.0,
          'path': path,
          'exists': false,
        };
      }
    } catch (e) {
      print('Error getting database size: $e');
      return {
        'size_bytes': 0,
        'size_mb': 0.0,
        'path': '',
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  // Crear respaldo de datos críticos
  Future<Map<String, dynamic>> createDataBackup() async {
    Database db = await database;
    
    try {
      Map<String, dynamic> backup = {
        'timestamp': DateTime.now().toIso8601String(),
        'version': 5,
      };
      
      // Respaldar fincas aplicaciones
      backup['fincas_aplicaciones'] = await db.query('fincas_aplicaciones', where: 'activo = 1');
      
      // Respaldar bloques aplicaciones
      backup['bloques_aplicaciones'] = await db.query('bloques_aplicaciones', where: 'activo = 1');
      
      // Respaldar bombas (límite para evitar archivos muy grandes)
      backup['bombas'] = await db.query('bombas', where: 'activo = 1', limit: 10000);
      
      // Estadísticas del respaldo
      backup['stats'] = {
        'fincas_count': (backup['fincas_aplicaciones'] as List).length,
        'bloques_count': (backup['bloques_aplicaciones'] as List).length,
        'bombas_count': (backup['bombas'] as List).length,
      };
      
      print('Respaldo creado exitosamente: ${backup['stats']}');
      return backup;
      
    } catch (e) {
      print('Error creando respaldo: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Restaurar desde respaldo
  Future<bool> restoreFromBackup(Map<String, dynamic> backup) async {
    Database db = await database;
    
    try {
      // Verificar versión del respaldo
      if (backup['version'] != 5) {
        print('Versión de respaldo incompatible: ${backup['version']}');
        return false;
      }
      
      // Limpiar tablas existentes
      await db.delete('fincas_aplicaciones');
      await db.delete('bloques_aplicaciones');
      await db.delete('bombas');
      
      // Restaurar fincas
      if (backup['fincas_aplicaciones'] != null) {
        for (Map<String, dynamic> finca in backup['fincas_aplicaciones']) {
          await db.insert('fincas_aplicaciones', finca);
        }
      }
      
      // Restaurar bloques
      if (backup['bloques_aplicaciones'] != null) {
        for (Map<String, dynamic> bloque in backup['bloques_aplicaciones']) {
          await db.insert('bloques_aplicaciones', bloque);
        }
      }
      
      // Restaurar bombas
      if (backup['bombas'] != null) {
        for (Map<String, dynamic> bomba in backup['bombas']) {
          await db.insert('bombas', bomba);
        }
      }
      
      await updateSyncTimestamp();
      print('Respaldo restaurado exitosamente');
      return true;
      
    } catch (e) {
      print('Error restaurando respaldo: $e');
      return false;
    }
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

  // Obtener estadísticas completas de la base de datos
  Future<Map<String, dynamic>> getCompleteStats() async {
    Database db = await database;
    
    try {
      Map<String, dynamic> stats = {};
      
      // Estadísticas generales
      stats['general'] = await getDatabaseStats();
      
      // Estadísticas de cosecha
      stats['cosecha'] = await getCosechaDatabaseStats();
      
      // Estadísticas de aplicaciones
      stats['aplicaciones'] = await getAplicacionesDatabaseStats();
      
      // Información de la base de datos
      stats['database_info'] = await getDatabaseSize();
      
      // Fecha de última sincronización
      DateTime? lastSync = await getLastSyncDate();
      stats['last_sync'] = lastSync?.toIso8601String();
      
      // Estado de salud
      Map<String, int> duplicates = await checkDuplicateData();
      List<Map<String, dynamic>> fincasSinBloques = await getFincasSinBloques();
      List<Map<String, dynamic>> bloquesSinBombas = await getBloquesSinBombas();
      
      stats['health'] = {
        'duplicates': duplicates,
        'fincas_sin_bloques': fincasSinBloques.length,
        'bloques_sin_bombas': bloquesSinBombas.length,
        'healthy': duplicates.values.every((count) => count == 0) && 
                  fincasSinBloques.isEmpty && 
                  bloquesSinBombas.isEmpty,
      };
      
      return stats;
    } catch (e) {
      print('Error obteniendo estadísticas completas: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Limpiar todos los datos con confirmación
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
    await db.delete('sync_metadata');
    
    print('Todos los datos han sido eliminados de la base de datos local');
  }

  // Reinicializar base de datos completamente
  Future<void> resetDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'kontrollers_local.db');
      
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      File dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('Base de datos eliminada: $path');
      }
      
      // Recrear la base de datos
      _database = await _initDatabase();
      print('Base de datos reinicializada exitosamente');
      
    } catch (e) {
      print('Error reinicializando base de datos: $e');
      rethrow;
    }
  }

  // Verificar integridad de la base de datos
  Future<Map<String, dynamic>> checkDatabaseIntegrity() async {
    Database db = await database;
    
    try {
      Map<String, dynamic> integrity = {
        'timestamp': DateTime.now().toIso8601String(),
        'checks': {},
        'errors': <String>[],
        'warnings': <String>[],
        'healthy': true,
      };
      
      // Verificar que las tablas existen
      List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      List<String> tableNames = tables.map((t) => t['name'] as String).toList();
      
      List<String> requiredTables = [
        'usuarios_local', 'supervisores_local', 'pesadores_local', 'fincas_local',
        'bloques_local', 'variedades_local', 'fincas_aplicaciones', 
        'bloques_aplicaciones', 'bombas', 'sync_metadata'
      ];
      
      for (String table in requiredTables) {
        bool exists = tableNames.contains(table);
        integrity['checks'][table] = exists;
        if (!exists) {
          integrity['errors'].add('Tabla faltante: $table');
          integrity['healthy'] = false;
        }
      }
      
      // Verificar índices
      List<Map<String, dynamic>> indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index'"
      );
      integrity['indexes_count'] = indexes.length;
      
      // Verificar foreign key constraints (simulado)
      Map<String, int> duplicates = await checkDuplicateData();
      if (duplicates.values.any((count) => count > 0)) {
        integrity['warnings'].add('Se encontraron datos duplicados');
      }
      
      // Verificar coherencia de datos
      List<Map<String, dynamic>> fincasSinBloques = await getFincasSinBloques();
      if (fincasSinBloques.isNotEmpty) {
        integrity['warnings'].add('${fincasSinBloques.length} fincas sin bloques');
      }
      
      return integrity;
    } catch (e) {
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'healthy': false,
        'error': e.toString(),
      };
    }
  }

  // Cerrar conexión a la base de datos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('Conexión a la base de datos cerrada');
    }
  }

  // Obtener información de la base de datos
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    Database db = await database;
    
    try {
      // Información de SQLite
      List<Map<String, dynamic>> versionResult = await db.rawQuery('SELECT sqlite_version() as version');
      String sqliteVersion = versionResult.first['version'];
      
      // Información del archivo
      Map<String, dynamic> sizeInfo = await getDatabaseSize();
      
      // Estadísticas completas
      Map<String, dynamic> stats = await getCompleteStats();
      
      return {
        'database_version': 5,
        'sqlite_version': sqliteVersion,
        'file_info': sizeInfo,
        'statistics': stats,
        'created_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

//   Future<List<Map<String, dynamic>>> searchVariedades(String finca, String bloque, String searchPattern) async {
//   Database db = await database;
//   return await db.query(
//     'variedades_local',
//     where: 'finca = ? AND bloque = ? AND nombre LIKE ? AND activo = ?',
//     whereArgs: [finca, bloque, '%$searchPattern%', 1],
//     orderBy: 'nombre',
//   );
// }
}