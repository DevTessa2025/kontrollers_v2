import '../services/auth_service.dart';
import '../services/sql_server_service.dart';

class AdminService {
  // Permitir que todos los usuarios tengan acceso de administrador
  // Lista vacía = todos los usuarios pueden acceder
  static const List<int> ADMIN_USER_IDS = [];
  
  // ==================== CONFIGURACIÓN DE ITEMS POR TIPO ====================
  
  // Definir los items que existen para cada tipo de checklist
  static Map<String, List<int>> ITEMS_POR_TIPO = {
    'check_fertirriego': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25], // 23 items, falta 12 y 19
    'check_bodega': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], // 20 items
    'check_aplicaciones': List.generate(30, (index) => index + 1), // 30 items del 1 al 30
    'check_cosecha': List.generate(20, (index) => index + 1), // 20 items del 1 al 20
    'check_cortes': List.generate(12, (index) => index + 1), // 12 items del 1 al 12
    'check_labores_permanentes': List.generate(20, (index) => index + 1), // 20 items del 1 al 20
    'check_labores_temporales': List.generate(20, (index) => index + 1), // 20 items del 1 al 20
  };
  
  // Verificar si el usuario actual es administrador
  // Solo permite acceso a usuarios admin o Belén Escobar
  static Future<bool> isCurrentUserAdmin() async {
    try {
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      
      if (currentUser == null) {
        return false;
      }
      
      String username = currentUser['username']?.toString().toLowerCase() ?? '';
      String nombre = currentUser['nombre']?.toString() ?? '';
      
      // Verificar si es admin o Belén Escobar
      bool isAdmin = username == 'admin' || 
                     nombre.toLowerCase().contains('belén') && nombre.toLowerCase().contains('escobar');
      
      print('🔍 Verificación de admin - Username: $username, Nombre: $nombre, Es admin: $isAdmin');
      
      return isAdmin;
      
    } catch (e) {
      print('Error verificando permisos de admin: $e');
      return false;
    }
  }
  
  // ==================== OBTENER REGISTROS DE FERTIRRIEGO ====================
  
  static Future<Map<String, dynamic>> getFertiriegoRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    try {
      // Construir query con filtros opcionales
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_id = $usuarioId";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          id,
          checklist_uuid,
          finca_nombre,
          bloque_nombre,
          usuario_id,
          usuario_nombre,
          fecha_creacion,
          fecha_envio,
          porcentaje_cumplimiento
        FROM check_fertirriego 
        $whereClause
        ORDER BY fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      // Obtener estadísticas
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_id) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_fertirriego 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de fertirriego: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER REGISTROS DE BODEGA ====================
  
  static Future<Map<String, dynamic>> getBodegaRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    try {
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_id = $usuarioId";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          id,
          checklist_uuid,
          finca_nombre,
          supervisor_nombre,
          pesador_nombre,
          usuario_id,
          usuario_nombre,
          fecha_creacion,
          fecha_envio,
          porcentaje_cumplimiento
        FROM check_bodega 
        $whereClause
        ORDER BY fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_id) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_bodega 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de bodega: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER REGISTROS DE APLICACIONES ====================
  
  static Future<Map<String, dynamic>> getAplicacionesRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    try {
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_id = $usuarioId";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          id,
          checklist_uuid,
          finca_nombre,
          bloque_nombre,
          bomba_nombre,
          usuario_id,
          usuario_nombre,
          fecha_creacion,
          fecha_envio,
          porcentaje_cumplimiento
        FROM check_aplicaciones 
        $whereClause
        ORDER BY fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_id) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_aplicaciones 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de aplicaciones: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER REGISTROS DE COSECHAS ====================
  
  static Future<Map<String, dynamic>> getCosechasRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    try {
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_id = $usuarioId";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          id,
          checklist_uuid,
          finca_nombre,
          bloque_nombre,
          variedad_nombre,
          usuario_id,
          usuario_nombre,
          fecha_creacion,
          fecha_envio,
          porcentaje_cumplimiento
        FROM check_cosecha 
        $whereClause
        ORDER BY fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_id) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_cosecha 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de cosecha: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER REGISTROS DE CORTES ====================
  
  static Future<Map<String, dynamic>> getCortesRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    try {
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_creacion = (SELECT username FROM usuarios_app WHERE id = $usuarioId)";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          c.id,
          c.id as checklist_uuid,
          c.finca_nombre,
          c.supervisor,
          c.supervisor as bloque_nombre,
          c.supervisor as variedad_nombre,
          c.usuario_creacion as usuario_id,
          CASE 
            WHEN u.nombre IS NOT NULL AND u.nombre != '' THEN u.nombre
            WHEN u.username IS NOT NULL AND u.username != '' THEN u.username
            ELSE c.usuario_creacion
          END as usuario_nombre,
          c.fecha as fecha,
          c.fecha_modificacion as fecha_envio,
          c.porcentaje_cumplimiento,
          c.cuadrantes_json,
          c.items_json,
          c.total_evaluaciones,
          c.total_conformes,
          c.total_no_conformes
        FROM check_cortes c
        LEFT JOIN usuarios_app u ON c.usuario_creacion = u.username
        $whereClause
        ORDER BY c.fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      // Debug: verificar qué datos están llegando del servidor para cortes
      print('🔍 DEBUG ADMIN - Consulta ejecutada para cortes');
      print('🔍 Query: $query');
      print('🔍 Resultado: $result');
      if (records.isNotEmpty) {
        print('🔍 Primer registro: ${records.first}');
        print('🔍 usuario_nombre del primer registro: ${records.first['usuario_nombre']}');
        print('🔍 usuario_id del primer registro: ${records.first['usuario_id']}');
      }
      
      // Debug adicional: verificar si el JOIN está funcionando
      String debugQuery = '''
        SELECT 
          c.usuario_creacion,
          u.username,
          u.nombre,
          u.email
        FROM check_cortes c
        LEFT JOIN usuarios_app u ON c.usuario_creacion = u.username
        WHERE c.id = ${records.isNotEmpty ? records.first['id'] : 'NULL'}
      ''';
      
      try {
        String debugResult = await SqlServerService.executeQuery(debugQuery);
        List<Map<String, dynamic>> debugRecords = SqlServerService.processQueryResult(debugResult);
        print('🔍 DEBUG JOIN - Resultado del JOIN: $debugRecords');
      } catch (e) {
        print('🔍 DEBUG JOIN - Error en consulta de debug: $e');
      }
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_creacion) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_cortes 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de cortes: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER REGISTROS DE LABORES PERMANENTES ====================
  
  static Future<Map<String, dynamic>> getLaboresPermanentesRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    print('🔍 DEBUG ADMIN - INICIANDO getLaboresPermanentesRecords');
    try {
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_creacion = (SELECT username FROM usuarios_app WHERE id = $usuarioId)";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          l.id,
          l.id as checklist_uuid,
          l.finca_nombre,
          l.up_unidad_productiva as bloque_nombre,
          l.up_unidad_productiva as variedad_nombre,
          l.usuario_creacion as usuario_id,
          CASE 
            WHEN l.kontroller IS NOT NULL AND l.kontroller != '' THEN l.kontroller
            ELSE l.usuario_creacion
          END as usuario_nombre,
          l.fecha_creacion,
          l.fecha_modificacion as fecha_envio,
          l.porcentaje_cumplimiento,
          l.cuadrantes_json,
          l.items_json,
          l.total_evaluaciones,
          l.total_conformes,
          l.total_no_conformes
        FROM check_labores_permanentes l
        $whereClause
        ORDER BY l.fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      // Debug: verificar qué datos están llegando del servidor para labores permanentes
      print('🔍 DEBUG ADMIN - Consulta ejecutada para labores permanentes');
      print('🔍 Query: $query');
      print('🔍 Resultado: $result');
      if (records.isNotEmpty) {
        print('🔍 Primer registro: ${records.first}');
        print('🔍 Keys del primer registro: ${records.first.keys.toList()}');
        print('🔍 cuadrantes_json presente: ${records.first.containsKey('cuadrantes_json')}');
        print('🔍 items_json presente: ${records.first.containsKey('items_json')}');
        if (records.first.containsKey('cuadrantes_json')) {
          print('🔍 cuadrantes_json valor: ${records.first['cuadrantes_json']}');
        }
        if (records.first.containsKey('items_json')) {
          print('🔍 items_json valor: ${records.first['items_json']}');
        }
      }
      
      // Debug adicional: verificar si hay datos en la tabla
      String debugQuery = '''
        SELECT TOP 1
          l.id,
          l.cuadrantes_json,
          l.items_json,
          l.fecha_creacion
        FROM check_labores_permanentes l
        ORDER BY l.fecha_creacion DESC
      ''';
      
      try {
        String debugResult = await SqlServerService.executeQuery(debugQuery);
        List<Map<String, dynamic>> debugRecords = SqlServerService.processQueryResult(debugResult);
        print('🔍 DEBUG - Verificación de datos en servidor: $debugResult');
        print('🔍 DEBUG - Registros procesados: $debugRecords');
        if (debugRecords.isNotEmpty) {
          print('🔍 DEBUG KONTROLLER - usuario_creacion: ${debugRecords.first['usuario_creacion']}');
          print('🔍 DEBUG KONTROLLER - kontroller: ${debugRecords.first['kontroller']}');
          print('🔍 DEBUG KONTROLLER - usuario_nombre_calculado: ${debugRecords.first['usuario_nombre_calculado']}');
        }
      } catch (e) {
        print('🔍 DEBUG KONTROLLER - Error en consulta de debug: $e');
      }
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_creacion) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_labores_permanentes 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de labores permanentes: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER REGISTROS DE LABORES TEMPORALES ====================
  
  static Future<Map<String, dynamic>> getLaboresTemporalesRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    print('🔍 DEBUG ADMIN - INICIANDO getLaboresTemporalesRecords');
    try {
      String whereClause = "WHERE 1=1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_creacion = (SELECT username FROM usuarios_app WHERE id = $usuarioId)";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          l.id,
          l.id as checklist_uuid,
          l.finca_nombre,
          l.up_unidad_productiva as bloque_nombre,
          l.up_unidad_productiva as variedad_nombre,
          l.usuario_creacion as usuario_id,
          CASE 
            WHEN l.kontroller IS NOT NULL AND l.kontroller != '' THEN l.kontroller
            ELSE l.usuario_creacion
          END as usuario_nombre,
          l.fecha_creacion,
          l.fecha_modificacion as fecha_envio,
          l.porcentaje_cumplimiento,
          l.cuadrantes_json,
          l.items_json,
          l.total_evaluaciones,
          l.total_conformes,
          l.total_no_conformes
        FROM check_labores_temporales l
        $whereClause
        ORDER BY l.fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      // Debug: verificar qué datos están llegando del servidor para labores temporales
      print('🔍 DEBUG ADMIN - Consulta ejecutada para labores temporales');
      print('🔍 Query: $query');
      print('🔍 Resultado: $result');
      if (records.isNotEmpty) {
        print('🔍 Primer registro: ${records.first}');
        print('🔍 usuario_nombre del primer registro: ${records.first['usuario_nombre']}');
        print('🔍 usuario_id del primer registro: ${records.first['usuario_id']}');
        
        // Debug adicional: verificar la columna kontroller directamente
        String debugQuery = '''
          SELECT 
            l.usuario_creacion,
            l.kontroller,
            l.id,
            CASE 
              WHEN l.kontroller IS NOT NULL AND l.kontroller != '' THEN l.kontroller
              ELSE l.usuario_creacion
            END as usuario_nombre_calculado
          FROM check_labores_temporales l
          WHERE l.id = ${records.first['id']}
        ''';
        
        try {
          String debugResult = await SqlServerService.executeQuery(debugQuery);
          List<Map<String, dynamic>> debugRecords = SqlServerService.processQueryResult(debugResult);
          print('🔍 DEBUG KONTROLLER - Resultado de la consulta: $debugRecords');
          if (debugRecords.isNotEmpty) {
            print('🔍 DEBUG KONTROLLER - usuario_creacion: ${debugRecords.first['usuario_creacion']}');
            print('🔍 DEBUG KONTROLLER - kontroller: ${debugRecords.first['kontroller']}');
            print('🔍 DEBUG KONTROLLER - usuario_nombre_calculado: ${debugRecords.first['usuario_nombre_calculado']}');
          }
        } catch (e) {
          print('🔍 DEBUG KONTROLLER - Error en consulta de debug: $e');
        }
      }
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          AVG(porcentaje_cumplimiento) as promedio_cumplimiento,
          COUNT(DISTINCT usuario_creacion) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM check_labores_temporales 
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de labores temporales: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }

  // ==================== OBTENER REGISTROS DE OBSERVACIONES ADICIONALES ====================
  
  static Future<Map<String, dynamic>> getObservacionesAdicionalesRecords({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? usuarioId,
    String? fincaNombre,
  }) async {
    try {
      String whereClause = "WHERE activo = 1";
      
      if (fechaInicio != null) {
        String fechaInicioStr = fechaInicio.toString().substring(0, 19);
        whereClause += " AND fecha_creacion >= '$fechaInicioStr'";
      }
      
      if (fechaFin != null) {
        String fechaFinStr = fechaFin.toString().substring(0, 19);
        whereClause += " AND fecha_creacion <= '$fechaFinStr'";
      }
      
      if (usuarioId != null) {
        whereClause += " AND usuario_creacion = (SELECT username FROM usuarios_app WHERE id = $usuarioId)";
      }
      
      if (fincaNombre != null && fincaNombre.isNotEmpty) {
        whereClause += " AND finca_nombre = '$fincaNombre'";
      }
      
      String query = '''
        SELECT 
          id,
          id as checklist_uuid,
          finca_nombre,
          bloque_nombre,
          variedad_nombre,
          usuario_creacion as usuario_id,
          usuario_nombre,
          fecha_creacion,
          fecha_envio,
          tipo,
          observacion,
          imagenes_json,
          blanco_biologico,
          incidencia,
          severidad,
          tercio
        FROM observaciones_adicionales
        $whereClause
        ORDER BY fecha_creacion DESC
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      String statsQuery = '''
        SELECT 
          COUNT(*) as total_registros,
          COUNT(DISTINCT usuario_creacion) as total_usuarios,
          COUNT(DISTINCT finca_nombre) as total_fincas
        FROM observaciones_adicionales
        $whereClause
      ''';
      
      String statsResult = await SqlServerService.executeQuery(statsQuery);
      List<Map<String, dynamic>> stats = SqlServerService.processQueryResult(statsResult);
      
      return {
        'success': true,
        'records': records,
        'statistics': stats.isNotEmpty ? stats.first : {},
        'total_count': records.length
      };
      
    } catch (e) {
      print('Error obteniendo registros de observaciones adicionales: $e');
      return {
        'success': false,
        'error': e.toString(),
        'records': [],
        'statistics': {},
        'total_count': 0
      };
    }
  }
  
  // ==================== OBTENER LISTA DE USUARIOS ====================
  
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      String query = '''
        SELECT 
          id,
          username,
          nombre,
          email,
          activo,
          fecha_creacion
        FROM usuarios_app 
        ORDER BY nombre
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> users = SqlServerService.processQueryResult(result);
      
      return users;
      
    } catch (e) {
      print('Error obteniendo lista de usuarios: $e');
      return [];
    }
  }
  
  // ==================== OBTENER LISTA DE FINCAS ====================
  
  static Future<List<String>> getAllFincas() async {
    try {
      String query = '''
        SELECT DISTINCT finca_nombre 
        FROM (
          SELECT finca_nombre FROM check_fertirriego WHERE finca_nombre IS NOT NULL
          UNION
          SELECT finca_nombre FROM check_bodega WHERE finca_nombre IS NOT NULL
          UNION
          SELECT finca_nombre FROM check_aplicaciones WHERE finca_nombre IS NOT NULL
          UNION
          SELECT finca_nombre FROM check_cosecha WHERE finca_nombre IS NOT NULL
          UNION
          SELECT finca_nombre FROM observaciones_adicionales WHERE finca_nombre IS NOT NULL
        ) AS fincas
        WHERE finca_nombre != ''
        ORDER BY finca_nombre
      ''';
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> fincasData = SqlServerService.processQueryResult(result);
      
      return fincasData.map((f) => f['finca_nombre'].toString()).toList();
      
    } catch (e) {
      print('Error obteniendo lista de fincas: $e');
      return [];
    }
  }
  
  // ==================== OBTENER DETALLE DE UN REGISTRO ====================
  
  static Future<Map<String, dynamic>?> getRecordDetail(String tableName, int recordId) async {
    try {
      // Validar nombre de tabla para evitar inyección SQL
      List<String> validTables = ['check_fertirriego', 'check_bodega', 'check_aplicaciones', 'check_cosecha', 'check_cortes', 'check_labores_permanentes', 'check_labores_temporales', 'observaciones_adicionales'];
      if (!validTables.contains(tableName)) {
        throw Exception('Tabla no válida: $tableName');
      }
      
      // Obtener los items que existen para este tipo de checklist
      List<int> itemsExistentes = ITEMS_POR_TIPO[tableName] ?? [];
      
      print('🔍 Obteniendo detalle para $tableName ID $recordId');
      print('📋 Items existentes: $itemsExistentes');
      
      // Construir la lista de campos dinámicamente basada en los items existentes
      List<String> camposItems = [];
      for (int itemNum in itemsExistentes) {
        camposItems.addAll([
          'item_${itemNum}_respuesta',
          'item_${itemNum}_valor_numerico', 
          'item_${itemNum}_observaciones',
          'item_${itemNum}_foto_base64'
        ]);
      }
      
      // Construir query dinámico con campos específicos según el tipo
      String query = _buildSpecificQuery(tableName, recordId, camposItems);
      
      print('🔍 Query generado: ${query.substring(0, 100)}...');
      
      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> records = SqlServerService.processQueryResult(result);
      
      if (records.isNotEmpty) {
        Map<String, dynamic> record = records.first;
        
        print('✅ Datos obtenidos exitosamente para $tableName ID $recordId');
        print('   Finca: ${record['finca_nombre']}');
        print('   Items procesados: ${itemsExistentes.length}');
        
        return record;
      }
      
      print('❌ No se encontró registro para $tableName ID $recordId');
      return null;
      
    } catch (e) {
      print('❌ Error obteniendo detalle del registro: $e');
      return null;
    }
  }
  
  // ==================== CONSTRUIR QUERY ESPECÍFICO POR TABLA ====================
  
  static String _buildSpecificQuery(String tableName, int recordId, List<String> camposItems) {
    // Campos base comunes - mapeados según la estructura de cada tabla
    List<String> camposBase = [];
    
    // Campos específicos por tipo
    switch (tableName) {
      case 'check_fertirriego':
        camposBase = [
          'id', 'checklist_uuid', 'finca_nombre', 
          'usuario_id', 'usuario_nombre', 'fecha_creacion', 
          'fecha_envio', 'porcentaje_cumplimiento', 'bloque_nombre'
        ];
        break;
      case 'check_bodega':
        camposBase = [
          'id', 'checklist_uuid', 'finca_nombre', 
          'usuario_id', 'usuario_nombre', 'fecha_creacion', 
          'fecha_envio', 'porcentaje_cumplimiento', 
          'supervisor_nombre', 'pesador_nombre'
        ];
        break;
      case 'check_aplicaciones':
        camposBase = [
          'id', 'checklist_uuid', 'finca_nombre', 
          'usuario_id', 'usuario_nombre', 'fecha_creacion', 
          'fecha_envio', 'porcentaje_cumplimiento', 
          'bloque_nombre', 'bomba_nombre'
        ];
        break;
      case 'check_cosecha':
        camposBase = [
          'id', 'checklist_uuid', 'finca_nombre', 
          'usuario_id', 'usuario_nombre', 'fecha_creacion', 
          'fecha_envio', 'porcentaje_cumplimiento', 
          'bloque_nombre', 'variedad_nombre'
        ];
        break;
      case 'check_cortes':
        camposBase = [
          'id', 'id as checklist_uuid', 'finca_nombre', 
          'supervisor', 'usuario_creacion as usuario_id', 'usuario_creacion as usuario_nombre', 
          'fecha as fecha', 'fecha_modificacion as fecha_envio', 
          'porcentaje_cumplimiento', 'supervisor as bloque_nombre',
          'cuadrantes_json', 'items_json', 'total_evaluaciones', 'total_conformes', 'total_no_conformes'
        ];
        break;
      case 'check_labores_permanentes':
        camposBase = [
          'id', 'id as checklist_uuid', 'finca_nombre', 
          'usuario_creacion as usuario_id', 'usuario_creacion as usuario_nombre', 
          'fecha_creacion', 'fecha_modificacion as fecha_envio', 
          'porcentaje_cumplimiento', 'up_unidad_productiva as bloque_nombre',
          'cuadrantes_json', 'items_json', 'observaciones_generales'
        ];
        break;
      case 'check_labores_temporales':
        camposBase = [
          'id', 'id as checklist_uuid', 'finca_nombre', 
          'usuario_creacion as usuario_id', 'usuario_creacion as usuario_nombre', 
          'fecha_creacion', 'fecha_modificacion as fecha_envio', 
          'porcentaje_cumplimiento', 'up_unidad_productiva as bloque_nombre',
          'cuadrantes_json', 'items_json', 'observaciones_generales'
        ];
        break;
      case 'observaciones_adicionales':
        camposBase = [
          'id', 'id as checklist_uuid', 'finca_nombre', 'bloque_nombre', 'variedad_nombre',
          'usuario_creacion as usuario_id', 'usuario_nombre', 'fecha_creacion', 'fecha_envio',
          'tipo', 'observacion', 'imagenes_json',
          'blanco_biologico', 'incidencia', 'severidad', 'tercio'
        ];
        break;
    }
    
    // Para las nuevas tablas (cortes, labores), no usar campos de items individuales
    // ya que los datos están en JSON. Para las tablas originales, sí usar campos de items.
    List<String> todosCampos;
    if (['check_cortes', 'check_labores_permanentes', 'check_labores_temporales', 'observaciones_adicionales'].contains(tableName)) {
      todosCampos = camposBase; // Solo campos base, sin campos de items individuales
    } else {
      todosCampos = [...camposBase, ...camposItems]; // Campos base + campos de items individuales
    }
    
    return '''
      SELECT ${todosCampos.join(', ')}
      FROM $tableName 
      WHERE id = $recordId
    ''';
  }
  
  // ==================== MÉTODO AUXILIAR PARA VALIDAR EXISTENCIA DE ITEMS ====================
  
  static bool itemExistsForType(String tableName, int itemNumber) {
    List<int> itemsExistentes = ITEMS_POR_TIPO[tableName] ?? [];
    return itemsExistentes.contains(itemNumber);
  }
  
  // ==================== OBTENER LISTA DE ITEMS EXISTENTES ====================
  
  static List<int> getExistingItemsForType(String tableName) {
    return ITEMS_POR_TIPO[tableName] ?? [];
  }
  
  // ==================== ADMINISTRACIÓN DE USUARIOS ====================
  
  // Crear nuevo usuario
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String nombre,
    required String email,
  }) async {
    try {
      String query = '''
        INSERT INTO usuarios_app (username, password, nombre, email, activo, fecha_creacion)
        VALUES ('$username', '$password', '$nombre', '$email', 1, GETDATE())
      ''';
      
      await SqlServerService.executeQuery(query);
      
      return {
        'success': true,
        'message': 'Usuario creado exitosamente'
      };
      
    } catch (e) {
      print('Error creando usuario: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  
  // Actualizar usuario
  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    String? username,
    String? password,
    String? nombre,
    String? email,
    bool? activo,
  }) async {
    try {
      List<String> updates = [];
      
      if (username != null) updates.add("username = '$username'");
      if (password != null) updates.add("password = '$password'");
      if (nombre != null) updates.add("nombre = '$nombre'");
      if (email != null) updates.add("email = '$email'");
      if (activo != null) updates.add("activo = ${activo ? 1 : 0}");
      
      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No hay campos para actualizar'
        };
      }
      
      updates.add("fecha_actualizacion = GETDATE()");
      
      String query = '''
        UPDATE usuarios_app 
        SET ${updates.join(', ')}
        WHERE id = $userId
      ''';
      
      await SqlServerService.executeQuery(query);
      
      return {
        'success': true,
        'message': 'Usuario actualizado exitosamente'
      };
      
    } catch (e) {
      print('Error actualizando usuario: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  
  // Activar/Desactivar usuario
  static Future<Map<String, dynamic>> toggleUserStatus(int userId, bool activo) async {
    try {
      String query = '''
        UPDATE usuarios_app 
        SET activo = ${activo ? 1 : 0}, fecha_actualizacion = GETDATE()
        WHERE id = $userId
      ''';
      
      await SqlServerService.executeQuery(query);
      
      return {
        'success': true,
        'message': 'Estado del usuario actualizado exitosamente'
      };
      
    } catch (e) {
      print('Error cambiando estado del usuario: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  
  // Eliminar usuario (soft delete)
  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    try {
      String query = '''
        UPDATE usuarios_app 
        SET activo = 0, fecha_actualizacion = GETDATE()
        WHERE id = $userId
      ''';
      
      await SqlServerService.executeQuery(query);
      
      return {
        'success': true,
        'message': 'Usuario eliminado exitosamente'
      };
      
    } catch (e) {
      print('Error eliminando usuario: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
}