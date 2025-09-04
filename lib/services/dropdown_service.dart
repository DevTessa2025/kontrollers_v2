import 'dart:convert';
import 'package:kontrollers_v2/services/RobustConnectionManager.dart';

import '../models/dropdown_models.dart';
import '../database/database_helper.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

class DropdownService {
  
  // ==================== SUPERVISORES ====================
  
  // Obtener supervisores activos (offline first)
  static Future<List<Supervisor>> getSupervisores() async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getAllSupervisores();
      
      // Si hay datos locales, usarlos
      if (localData.isNotEmpty) {
        print('Supervisores cargados desde SQLite: ${localData.length}');
        return localData.map((item) => Supervisor.fromJson(item)).toList();
      }

      // Si no hay datos locales y hay conexión, intentar obtener del servidor
      if (await AuthService.hasInternetConnection()) {
        print('No hay supervisores locales, obteniendo del servidor...');
        return await _getSupervisoresFromServer();
      }

      // Sin datos locales ni conexión
      print('Sin supervisores locales ni conexión');
      return [];
      
    } catch (e) {
      print('Error obteniendo supervisores: $e');
      return [];
    }
  }

  // Obtener supervisores del servidor y guardar localmente
  static Future<List<Supervisor>> _getSupervisoresFromServer() async {
    try {
      String query = '''
        SELECT id, nombre, cedula, activo 
        FROM supervisores 
        WHERE activo = 1 
        ORDER BY nombre
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> supervisor in data) {
          supervisor['fecha_actualizacion'] = DateTime.now().toIso8601String();
          await dbHelper.insertOrUpdateSupervisor(supervisor);
        }
        print('${data.length} supervisores sincronizados desde servidor');
      }
      
      return data.map((item) => Supervisor.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo supervisores del servidor: $e');
      return [];
    }
  }

  // ==================== PESADORES ====================
  
  // Obtener pesadores activos (offline first)
  static Future<List<Pesador>> getPesadores() async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getAllPesadores();
      
      // Si hay datos locales, usarlos
      if (localData.isNotEmpty) {
        print('Pesadores cargados desde SQLite: ${localData.length}');
        return localData.map((item) => Pesador.fromJson(item)).toList();
      }

      // Si no hay datos locales y hay conexión, intentar obtener del servidor
      if (await AuthService.hasInternetConnection()) {
        print('No hay pesadores locales, obteniendo del servidor...');
        return await _getPesadoresFromServer();
      }

      // Sin datos locales ni conexión
      print('Sin pesadores locales ni conexión');
      return [];
      
    } catch (e) {
      print('Error obteniendo pesadores: $e');
      return [];
    }
  }

  // Obtener pesadores del servidor y guardar localmente
  static Future<List<Pesador>> _getPesadoresFromServer() async {
    try {
      String query = '''
        SELECT id, nombre, cedula, activo 
        FROM pesadores 
        WHERE activo = 1 
        ORDER BY nombre
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> pesador in data) {
          pesador['fecha_actualizacion'] = DateTime.now().toIso8601String();
          await dbHelper.insertOrUpdatePesador(pesador);
        }
        print('${data.length} pesadores sincronizados desde servidor');
      }
      
      return data.map((item) => Pesador.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo pesadores del servidor: $e');
      return [];
    }
  }

  // ==================== FINCAS ====================
  
  // Obtener fincas (offline first)
  static Future<List<Finca>> getFincas() async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getAllFincas();
      
      // Si hay datos locales, usarlos
      if (localData.isNotEmpty) {
        print('Fincas cargadas desde SQLite: ${localData.length}');
        return localData.map((item) => Finca.fromJson(item)).toList();
      }

      // Si no hay datos locales y hay conexión, intentar obtener del servidor
      if (await AuthService.hasInternetConnection()) {
        print('No hay fincas locales, obteniendo del servidor...');
        return await _getFincasFromServer();
      }

      // Sin datos locales ni conexión, devolver finca de error
      print('Sin fincas locales ni conexión');
      return [Finca(nombre: 'Error, Volver a intentar')];
      
    } catch (e) {
      print('Error obteniendo fincas: $e');
      return [Finca(nombre: 'Error, Volver a intentar')];
    }
  }

  // Obtener fincas del servidor y guardar localmente
  static Future<List<Finca>> _getFincasFromServer() async {
    try {
      String query = '''
        SELECT DISTINCT LOCALIDAD as nombre
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
        ORDER BY LOCALIDAD
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> fincaData in data) {
          Map<String, dynamic> finca = {
            'nombre': fincaData['nombre'],
            'activo': 1,
            'fecha_actualizacion': DateTime.now().toIso8601String(),
          };
          await dbHelper.insertOrUpdateFinca(finca);
        }
        print('${data.length} fincas sincronizadas desde servidor');
      }
      
      return data.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo fincas del servidor: $e');
      return [Finca(nombre: 'Error, Volver a intentar')];
    }
  }

  // ==================== USUARIOS ====================
  
  // Obtener usuarios activos (offline first)
  static Future<List<Usuario>> getUsuarios() async {
    try {
      // Primero intentar obtener datos locales
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> localData = await dbHelper.getAllUsers();
      
      // Si hay datos locales, usarlos
      if (localData.isNotEmpty) {
        print('Usuarios cargados desde SQLite: ${localData.length}');
        return localData.map((item) => Usuario.fromJson(item)).toList();
      }

      // Si no hay datos locales y hay conexión, intentar obtener del servidor
      if (await AuthService.hasInternetConnection()) {
        print('No hay usuarios locales, obteniendo del servidor...');
        return await _getUsuariosFromServer();
      }

      // Sin datos locales ni conexión
      print('Sin usuarios locales ni conexión');
      return [];
      
    } catch (e) {
      print('Error obteniendo usuarios: $e');
      return [];
    }
  }

  // Obtener usuarios del servidor y guardar localmente
  static Future<List<Usuario>> _getUsuariosFromServer() async {
    try {
      String query = '''
        SELECT id, username, nombre, email, activo 
        FROM usuarios_app 
        WHERE activo = 1 
        ORDER BY nombre
      ''';

      String result = await RobustSqlServerService.executeQueryRobust(
        query, 
        operationName: 'Get Usuarios'
      );
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      // Guardar en SQLite
      if (data.isNotEmpty) {
        DatabaseHelper dbHelper = DatabaseHelper();
        for (Map<String, dynamic> usuario in data) {
          usuario['fecha_actualizacion'] = DateTime.now().toIso8601String();
          await dbHelper.insertOrUpdateUser(usuario);
        }
        print('${data.length} usuarios sincronizados desde servidor');
      }
      
      return data.map((item) => Usuario.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo usuarios del servidor: $e');
      return [];
    }
  }

  // ==================== MÉTODOS PRINCIPALES ====================

  // Obtener todos los datos necesarios para el checklist
  static Future<Map<String, dynamic>> getChecklistDropdownData({required bool forceSync}) async {
    try {
      print('Obteniendo datos de dropdown (forceSync: $forceSync)');
      
      // Si se requiere sincronización forzada y hay conexión
      if (forceSync && await AuthService.hasInternetConnection()) {
        print('Sincronización forzada solicitada');
        return await _forceSync();
      }

      // Obtener datos (offline first)
      List<Future> futures = [
        getSupervisores(),
        getPesadores(),
        getFincas(),
        getUsuarios(),
      ];

      List<dynamic> results = await Future.wait(futures);

      return {
        'supervisores': results[0] as List<Supervisor>,
        'pesadores': results[1] as List<Pesador>,
        'fincas': results[2] as List<Finca>,
        'usuarios': results[3] as List<Usuario>,
      };
    } catch (e) {
      print('Error obteniendo datos de dropdown: $e');
      return {
        'supervisores': <Supervisor>[],
        'pesadores': <Pesador>[],
        'fincas': <Finca>[],
      };
    }
  }

  // Sincronización forzada desde el servidor
  static Future<Map<String, dynamic>> _forceSync() async {
    try {
      print('Iniciando sincronización forzada...');
      
      // Obtener datos directamente del servidor
      List<Future> futures = [
        _getSupervisoresFromServer(),
        _getPesadoresFromServer(),
        _getFincasFromServer(),
        _getUsuariosFromServer(),
      ];

      List<dynamic> results = await Future.wait(futures);

      print('Sincronización forzada completada');
      return {
        'supervisores': results[0] as List<Supervisor>,
        'pesadores': results[1] as List<Pesador>,
        'fincas': results[2] as List<Finca>,
        'usuarios': results[3] as List<Usuario>,
      };
    } catch (e) {
      print('Error en sincronización forzada: $e');
      // En caso de error, intentar con datos locales
      return await getChecklistDropdownData(forceSync: false);
    }
  }

  // ==================== MÉTODOS DE BÚSQUEDA POR ID ====================

  // Buscar supervisor por ID (offline first)
  static Future<Supervisor?> getSupervisorById(int id) async {
    try {
      // Primero buscar localmente
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localData = await dbHelper.getSupervisorById(id);
      
      if (localData != null) {
        return Supervisor.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Supervisor> supervisores = await _getSupervisoresFromServer();
        return supervisores.firstWhere(
          (supervisor) => supervisor.id == id,
          orElse: () => throw Exception('Supervisor no encontrado'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando supervisor por ID: $e');
      return null;
    }
  }

  // Buscar pesador por ID (offline first)
  static Future<Pesador?> getPesadorById(int id) async {
    try {
      // Primero buscar localmente
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localData = await dbHelper.getPesadorById(id);
      
      if (localData != null) {
        return Pesador.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Pesador> pesadores = await _getPesadoresFromServer();
        return pesadores.firstWhere(
          (pesador) => pesador.id == id,
          orElse: () => throw Exception('Pesador no encontrado'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando pesador por ID: $e');
      return null;
    }
  }

  // Buscar finca por nombre (offline first)
  static Future<Finca?> getFincaByNombre(String nombre) async {
    try {
      // Primero buscar localmente
      DatabaseHelper dbHelper = DatabaseHelper();
      Map<String, dynamic>? localData = await dbHelper.getFincaByNombre(nombre);
      
      if (localData != null) {
        return Finca.fromJson(localData);
      }

      // Si no está local y hay conexión, buscar en servidor
      if (await AuthService.hasInternetConnection()) {
        List<Finca> fincas = await _getFincasFromServer();
        return fincas.firstWhere(
          (finca) => finca.nombre == nombre,
          orElse: () => throw Exception('Finca no encontrada'),
        );
      }

      return null;
    } catch (e) {
      print('Error buscando finca por nombre: $e');
      return null;
    }
  }

  // ==================== MÉTODOS DE SINCRONIZACIÓN ====================

  // Sincronizar todos los datos de dropdown
  static Future<Map<String, dynamic>> syncDropdownData() async {
    try {
      if (!await AuthService.hasInternetConnection()) {
        return {
          'success': false,
          'message': 'No hay conexión a internet'
        };
      }

      print('Iniciando sincronización de datos de dropdown...');

      int totalSynced = 0;
      List<String> errors = [];

      // Sincronizar supervisores
      try {
        List<Supervisor> supervisores = await _getSupervisoresFromServer();
        totalSynced += supervisores.length;
        print('Supervisores sincronizados: ${supervisores.length}');
      } catch (e) {
        errors.add('Supervisores: $e');
      }

      // Sincronizar pesadores
      try {
        List<Pesador> pesadores = await _getPesadoresFromServer();
        totalSynced += pesadores.length;
        print('Pesadores sincronizados: ${pesadores.length}');
      } catch (e) {
        errors.add('Pesadores: $e');
      }

      // Sincronizar fincas
      try {
        List<Finca> fincas = await _getFincasFromServer();
        totalSynced += fincas.length;
        print('Fincas sincronizadas: ${fincas.length}');
      } catch (e) {
        errors.add('Fincas: $e');
      }

      if (errors.isEmpty) {
        return {
          'success': true,
          'message': 'Sincronización exitosa. $totalSynced registros sincronizados.',
          'count': totalSynced
        };
      } else {
        return {
          'success': false,
          'message': 'Sincronización parcial. Errores: ${errors.join(', ')}',
          'count': totalSynced
        };
      }

    } catch (e) {
      return {
        'success': false,
        'message': 'Error durante la sincronización: $e'
      };
    }
  }

  // Obtener estadísticas de datos locales
  static Future<Map<String, int>> getLocalStats() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      return await dbHelper.getDatabaseStats();
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return {
        'usuarios': 0,
        'supervisores': 0,
        'pesadores': 0,
        'fincas': 0,
      };
    }
  }

  // Limpiar todos los datos locales de dropdown
  static Future<void> clearLocalDropdownData() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      await dbHelper.clearSupervisores();
      await dbHelper.clearPesadores();
      await dbHelper.clearFincas();
      print('Datos locales de dropdown limpiados');
    } catch (e) {
      print('Error limpiando datos locales: $e');
      rethrow;
    }
  }
}