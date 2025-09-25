import 'dart:convert';
import '../database/database_helper.dart';
import 'auth_service.dart';
import 'sql_server_service.dart';

class ObservacionAdicional {
  int? id;
  DateTime? fecha;
  String fincaNombre;
  String bloqueNombre;
  String variedadNombre;
  String tipo; // MIPE | CULTIVO | MIRFE
  String observacion;
  List<String> imagenesBase64; // múltiples imágenes
  String? usuarioUsername;
  String? usuarioNombre;
  DateTime? fechaCreacion;
  DateTime? fechaActualizacion;
  int enviado;
  int activo;
  
  // Campos específicos para MIPE
  String? blancoBiologico;
  double? incidencia;
  double? severidad;
  String? tercio; // Alto | Medio | Bajo

  ObservacionAdicional({
    this.id,
    this.fecha,
    required this.fincaNombre,
    required this.bloqueNombre,
    required this.variedadNombre,
    required this.tipo,
    required this.observacion,
    List<String>? imagenesBase64,
    this.usuarioUsername,
    this.usuarioNombre,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.enviado = 0,
    this.activo = 1,
    // Campos específicos para MIPE
    this.blancoBiologico,
    this.incidencia,
    this.severidad,
    this.tercio,
  }) : imagenesBase64 = imagenesBase64 ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha?.toIso8601String(),
      'finca_nombre': fincaNombre,
      'bloque_nombre': bloqueNombre,
      'variedad_nombre': variedadNombre,
      'tipo': tipo,
      'observacion': observacion,
      'imagenes_json': jsonEncode(imagenesBase64),
      'usuario_username': usuarioUsername,
      'usuario_nombre': usuarioNombre,
      'fecha_creacion': fechaCreacion?.toIso8601String(),
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'enviado': enviado,
      'activo': activo,
      // Campos específicos para MIPE
      'blanco_biologico': blancoBiologico,
      'incidencia': incidencia,
      'severidad': severidad,
      'tercio': tercio,
    };
  }

  static ObservacionAdicional fromMap(Map<String, dynamic> map) {
    List<dynamic> imgs = [];
    try {
      if (map['imagenes_json'] != null) {
        imgs = jsonDecode(map['imagenes_json']);
      }
    } catch (_) {}

    return ObservacionAdicional(
      id: map['id'] as int?,
      fecha: map['fecha'] != null ? DateTime.tryParse(map['fecha']) : null,
      fincaNombre: map['finca_nombre'] ?? '',
      bloqueNombre: map['bloque_nombre'] ?? '',
      variedadNombre: map['variedad_nombre'] ?? '',
      tipo: map['tipo'] ?? 'MIPE',
      observacion: map['observacion'] ?? '',
      imagenesBase64: imgs.cast<String>(),
      usuarioUsername: map['usuario_username'],
      usuarioNombre: map['usuario_nombre'],
      fechaCreacion: map['fecha_creacion'] != null ? DateTime.tryParse(map['fecha_creacion']) : null,
      fechaActualizacion: map['fecha_actualizacion'] != null ? DateTime.tryParse(map['fecha_actualizacion']) : null,
      enviado: map['enviado'] ?? 0,
      activo: map['activo'] ?? 1,
      // Campos específicos para MIPE
      blancoBiologico: map['blanco_biologico'],
      incidencia: map['incidencia'] != null ? (map['incidencia'] as num).toDouble() : null,
      severidad: map['severidad'] != null ? (map['severidad'] as num).toDouble() : null,
      tercio: map['tercio'],
    );
  }
}

class ObservacionesAdicionalesService {
  // Guardar localmente
  static Future<int> save(ObservacionAdicional obs) async {
    // Asegurar que las columnas MIPE existen
    await DatabaseHelper.ensureMIPEColumns();
    
    final db = await DatabaseHelper().database;

    // Obtener usuario actual
    final currentUser = await AuthService.getCurrentUser();
    final username = currentUser?['username'] as String?;
    final nombre = (currentUser?['nombre'] as String?) ?? username;

    final now = DateTime.now();

    final map = obs.toMap();
    map['usuario_username'] = username;
    map['usuario_nombre'] = nombre;
    map['fecha_creacion'] = now.toIso8601String();
    map['enviado'] = 0;
    map['activo'] = 1;

    return await db.insert('observaciones_adicionales', map);
  }

  static Future<int> update(ObservacionAdicional obs) async {
    if (obs.id == null) throw Exception('ID requerido para actualizar');
    
    // Asegurar que las columnas MIPE existen
    await DatabaseHelper.ensureMIPEColumns();
    
    final db = await DatabaseHelper().database;
    final map = obs.toMap();
    map['fecha_actualizacion'] = DateTime.now().toIso8601String();
    return await db.update(
      'observaciones_adicionales',
      map,
      where: 'id = ?',
      whereArgs: [obs.id],
    );
  }

  static Future<List<ObservacionAdicional>> getAll() async {
    // Asegurar que las columnas MIPE existen
    await DatabaseHelper.ensureMIPEColumns();
    
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'observaciones_adicionales',
      where: 'activo = 1',
      orderBy: 'fecha_creacion DESC',
    );
    return maps.map((m) => ObservacionAdicional.fromMap(m)).toList();
  }

  static Future<void> softDelete(int id) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'observaciones_adicionales',
      {'activo': 0, 'fecha_actualizacion': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== SINCRONIZACIÓN CON SERVIDOR ====================
  
  static Future<Map<String, dynamic>> syncToServer() async {
    final db = await DatabaseHelper().database;
    
    // Obtener observaciones no enviadas
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'observaciones_adicionales',
      where: 'enviado = ? AND activo = ?',
      whereArgs: [0, 1],
      orderBy: 'fecha_creacion ASC',
    );

    print('Intentando sincronizar ${unsyncedMaps.length} observaciones adicionales...');

    if (unsyncedMaps.isEmpty) {
      return {
        'success': true,
        'message': 'No hay observaciones adicionales pendientes por sincronizar',
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
        ObservacionAdicional observacion = ObservacionAdicional.fromMap(map);
        await _sendObservacionToServer(observacion);
        
        // Marcar como enviado
        await db.update(
          'observaciones_adicionales',
          {'enviado': 1, 'fecha_envio': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [map['id']],
        );
        
        syncedCount++;
        print('Observación adicional ID ${map['id']} sincronizada exitosamente');
        
      } catch (e) {
        failedCount++;
        errors.add('ID ${map['id']}: $e');
        print('Error sincronizando observación adicional ID ${map['id']}: $e');
      }
    }

    return {
      'success': failedCount == 0,
      'message': syncedCount > 0 
          ? '$syncedCount observaciones adicionales sincronizadas exitosamente'
          : 'No se pudieron sincronizar las observaciones adicionales',
      'synced': syncedCount,
      'failed': failedCount,
      'errors': errors,
    };
  }

  static Future<void> _sendObservacionToServer(ObservacionAdicional observacion) async {
    if (observacion.id == null) throw Exception('ID de la observación es requerido');

    // Obtener usuario actual desde AuthService
    Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) throw Exception('Usuario no autenticado');
    String username = currentUser['username'] ?? '';
    String nombreUsuario = (observacion.usuarioNombre ?? currentUser['nombre'] ?? username) as String;

    // Helpers
    String esc(String? s) => (s ?? '').replaceAll("'", "''");
    String? escOrNull(String? s) => s == null ? null : s.replaceAll("'", "''");
    String fmtDate(DateTime? d, {bool nullAsNull = true}) {
      // Enviar en formato ANSI con estilo 126 para evitar errores regionales
      if (d == null) return nullAsNull ? 'NULL' : 'GETDATE()';
      try {
        final iso = d.toIso8601String(); // 2025-09-15T12:34:56.789Z
        final trimmed = iso.length >= 19 ? iso.substring(0, 19) : iso; // 2025-09-15T12:34:56
        return "CONVERT(DATETIME2, '$trimmed', 126)"; // estilo 126 reconoce la 'T'
      } catch (_) {
        return 'GETDATE()';
      }
    }

    // Escapar strings para SQL
    String escapedFinca = esc(observacion.fincaNombre);
    String escapedBloque = esc(observacion.bloqueNombre);
    String escapedVariedad = esc(observacion.variedadNombre);
    String escapedTipo = esc(observacion.tipo);
    String escapedObservacion = esc(observacion.observacion);
    String escapedImagenes = jsonEncode(observacion.imagenesBase64).replaceAll("'", "''");
    String escapedUser = esc(username);
    String escapedNombreUsuario = esc(nombreUsuario);

    // Campos MIPE
    String? escapedBlancoBiologico = escOrNull(observacion.blancoBiologico);
    String incidenciaVal = observacion.incidencia != null ? observacion.incidencia!.toString() : 'NULL';
    String severidadVal = observacion.severidad != null ? observacion.severidad!.toString() : 'NULL';
    String? escapedTercio = escOrNull(observacion.tercio);

    // Construir query de inserción
    // Upsert: si existe id_local, actualizar; si no, insertar
    String query = '''
      IF NOT EXISTS (SELECT 1 FROM observaciones_adicionales WHERE id_local = ${observacion.id})
      BEGIN
        INSERT INTO observaciones_adicionales (
          id_local, fecha, finca_nombre, bloque_nombre, variedad_nombre,
          tipo, observacion, imagenes_json, usuario_creacion, usuario_nombre,
          fecha_creacion, fecha_actualizacion, activo,
          blanco_biologico, incidencia, severidad, tercio
        ) VALUES (
          ${observacion.id},
          ${fmtDate(observacion.fecha)},
          '$escapedFinca',
          '$escapedBloque',
          '$escapedVariedad',
          '$escapedTipo',
          '$escapedObservacion',
          '$escapedImagenes',
          '$escapedUser',
          '$escapedNombreUsuario',
          ${fmtDate(observacion.fechaCreacion, nullAsNull: true)},
          ${fmtDate(observacion.fechaActualizacion, nullAsNull: true)},
          1,
          ${escapedBlancoBiologico == null ? 'NULL' : "'$escapedBlancoBiologico'"},
          $incidenciaVal,
          $severidadVal,
          ${escapedTercio == null ? 'NULL' : "'$escapedTercio'"}
        )
      END
      ELSE
      BEGIN
        UPDATE observaciones_adicionales SET
          fecha = ${fmtDate(observacion.fecha)},
          finca_nombre = '$escapedFinca',
          bloque_nombre = '$escapedBloque',
          variedad_nombre = '$escapedVariedad',
          tipo = '$escapedTipo',
          observacion = '$escapedObservacion',
          imagenes_json = '$escapedImagenes',
          usuario_creacion = '$escapedUser',
          usuario_nombre = '$escapedNombreUsuario',
          fecha_actualizacion = GETDATE(),
          activo = 1,
          blanco_biologico = ${escapedBlancoBiologico == null ? 'NULL' : "'$escapedBlancoBiologico'"},
          incidencia = $incidenciaVal,
          severidad = $severidadVal,
          tercio = ${escapedTercio == null ? 'NULL' : "'$escapedTercio'"}
        WHERE id_local = ${observacion.id}
      END
    ''';

    await SqlServerService.executeQuery(query);
    print('Observación adicional enviada al servidor exitosamente');
  }

  // Sincronización individual de una observación
  static Future<Map<String, dynamic>> syncIndividualToServer(int id) async {
    final db = await DatabaseHelper().database;
    
    // Obtener la observación específica
    final List<Map<String, dynamic>> maps = await db.query(
      'observaciones_adicionales',
      where: 'id = ? AND enviado = ? AND activo = ?',
      whereArgs: [id, 0, 1],
    );

    if (maps.isEmpty) {
      return {
        'success': false,
        'message': 'Observación no encontrada o ya sincronizada',
        'synced': 0,
        'failed': 1,
        'errors': ['Observación no encontrada'],
      };
    }

    if (!await AuthService.hasInternetConnection()) {
      throw Exception('No hay conexión a internet para sincronizar');
    }

    try {
      ObservacionAdicional observacion = ObservacionAdicional.fromMap(maps.first);
      await _sendObservacionToServer(observacion);
      
      // Marcar como enviado
      await db.update(
        'observaciones_adicionales',
        {'enviado': 1, 'fecha_envio': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('Observación adicional ID $id sincronizada individualmente');
      
      return {
        'success': true,
        'message': 'Observación sincronizada exitosamente',
        'synced': 1,
        'failed': 0,
        'errors': [],
      };
      
    } catch (e) {
      print('Error sincronizando observación individual ID $id: $e');
      return {
        'success': false,
        'message': 'Error al sincronizar observación: $e',
        'synced': 0,
        'failed': 1,
        'errors': ['$e'],
      };
    }
  }
}


