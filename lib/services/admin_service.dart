import '../services/auth_service.dart';
import '../services/sql_server_service.dart';

class AdminService {
  // IDs de usuarios que tienen permisos de administrador
  static const List<int> ADMIN_USER_IDS = [1, 2, 3];
  
  // ==================== CONFIGURACIÓN DE ITEMS POR TIPO ====================
  
  // Definir los items que existen para cada tipo de checklist
  static Map<String, List<int>> ITEMS_POR_TIPO = {
    'check_fertirriego': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25], // 23 items, falta 12 y 19
    'check_bodega': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], // 20 items
    'check_aplicaciones': List.generate(30, (index) => index + 1), // 30 items del 1 al 30
    'check_cosecha': List.generate(20, (index) => index + 1), // 20 items del 1 al 20
  };
  
  // Verificar si el usuario actual es administrador
  static Future<bool> isCurrentUserAdmin() async {
    try {
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      
      if (currentUser == null) {
        return false;
      }
      
      int userId = currentUser['id'] ?? 0;
      return ADMIN_USER_IDS.contains(userId);
      
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
      List<String> validTables = ['check_fertirriego', 'check_bodega', 'check_aplicaciones', 'check_cosecha'];
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
    // Campos base comunes
    List<String> camposBase = [
      'id', 'checklist_uuid', 'finca_nombre', 
      'usuario_id', 'usuario_nombre', 'fecha_creacion', 
      'fecha_envio', 'porcentaje_cumplimiento'
    ];
    
    // Campos específicos por tipo
    switch (tableName) {
      case 'check_fertirriego':
        camposBase.add('bloque_nombre');
        break;
      case 'check_bodega':
        camposBase.addAll(['supervisor_nombre', 'pesador_nombre']);
        break;
      case 'check_aplicaciones':
        camposBase.addAll(['bloque_nombre', 'bomba_nombre']);
        break;
      case 'check_cosecha':
        camposBase.addAll(['bloque_nombre', 'variedad_nombre']);
        break;
    }
    
    // Combinar campos base con campos de items
    List<String> todosCampos = [...camposBase, ...camposItems];
    
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
}