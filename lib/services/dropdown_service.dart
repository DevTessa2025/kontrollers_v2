import 'dart:convert';
import '../models/dropdown_models.dart';
import 'sql_server_service.dart';

class DropdownService {
  
  // Obtener supervisores activos
  static Future<List<Supervisor>> getSupervisores() async {
    try {
      String query = '''
        SELECT id, nombre, cedula, activo 
        FROM supervisores 
        WHERE activo = 1 
        ORDER BY nombre
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.map((item) => Supervisor.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo supervisores: $e');
      return [];
    }
  }

  // Obtener pesadores activos
  static Future<List<Pesador>> getPesadores() async {
    try {
      String query = '''
        SELECT id, nombre, cedula, activo 
        FROM pesadores 
        WHERE activo = 1 
        ORDER BY nombre
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.map((item) => Pesador.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo pesadores: $e');
      return [];
    }
  }

  // Obtener fincas desde Bi_TESSACORP
  static Future<List<Finca>> getFincas() async {
    try {
      String query = '''
        SELECT DISTINCT LOCALIDAD as finca
        FROM Bi_TESSACORP.dbo.PLANO_CULTIVO_SCRAPING 
        WHERE LOCALIDAD IS NOT NULL 
          AND LOCALIDAD != ''
        ORDER BY LOCALIDAD
      ''';

      String result = await SqlServerService.executeQuery(query);
      List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
      
      return data.map((item) => Finca.fromJson(item)).toList();
    } catch (e) {
      print('Error obteniendo fincas: $e');
      // Fincas de respaldo en caso de error
      return [
        Finca(nombre: 'Error, Volver a intentar')
      ];
    }
  }

  // Obtener todos los datos necesarios para el checklist
  static Future<Map<String, dynamic>> getChecklistDropdownData() async {
    try {
      // Ejecutar todas las consultas en paralelo
      List<Future> futures = [
        getSupervisores(),
        getPesadores(),
        getFincas(),
      ];

      List<dynamic> results = await Future.wait(futures);

      return {
        'supervisores': results[0] as List<Supervisor>,
        'pesadores': results[1] as List<Pesador>,
        'fincas': results[2] as List<Finca>,
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

  // Buscar supervisor por ID
  static Future<Supervisor?> getSupervisorById(int id) async {
    try {
      List<Supervisor> supervisores = await getSupervisores();
      return supervisores.firstWhere(
        (supervisor) => supervisor.id == id,
        orElse: () => throw Exception('Supervisor no encontrado'),
      );
    } catch (e) {
      print('Error buscando supervisor por ID: $e');
      return null;
    }
  }

  // Buscar pesador por ID
  static Future<Pesador?> getPesadorById(int id) async {
    try {
      List<Pesador> pesadores = await getPesadores();
      return pesadores.firstWhere(
        (pesador) => pesador.id == id,
        orElse: () => throw Exception('Pesador no encontrado'),
      );
    } catch (e) {
      print('Error buscando pesador por ID: $e');
      return null;
    }
  }

  // Buscar finca por nombre
  static Future<Finca?> getFincaByNombre(String nombre) async {
    try {
      List<Finca> fincas = await getFincas();
      return fincas.firstWhere(
        (finca) => finca.nombre == nombre,
        orElse: () => throw Exception('Finca no encontrada'),
      );
    } catch (e) {
      print('Error buscando finca por nombre: $e');
      return null;
    }
  }
}