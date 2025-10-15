import '../models/dropdown_models.dart';
import 'dart:convert';

// ==================== MODELOS ESPECÍFICOS PARA LABORES PERMANENTES ====================

class ChecklistLaboresPermanentesItem {
  final int id;
  final String proceso;
  String? observaciones;
  String? fotoBase64;
  // Estructura: cuadrante -> parada -> resultado (0/1)
  Map<String, Map<int, String?>> resultadosPorCuadranteParada;

  ChecklistLaboresPermanentesItem({
    required this.id,
    required this.proceso,
    this.observaciones,
    this.fotoBase64,
    Map<String, Map<int, String?>>? resultadosPorCuadranteParada,
  }) : resultadosPorCuadranteParada = resultadosPorCuadranteParada ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proceso': proceso,
      'observaciones': observaciones,
      'fotoBase64': fotoBase64,
      'resultadosPorCuadranteParada': resultadosPorCuadranteParada.map((cuadrante, paradas) => 
        MapEntry(cuadrante, paradas.map((parada, resultado) => 
          MapEntry(parada.toString(), resultado))),
      ),
    };
  }

  factory ChecklistLaboresPermanentesItem.fromJson(Map<String, dynamic> json) {
    Map<String, Map<int, String?>> resultados = {};
    if (json['resultadosPorCuadranteParada'] != null) {
      Map<String, dynamic> cuadrantes = json['resultadosPorCuadranteParada'];
      cuadrantes.forEach((cuadrante, paradas) {
        Map<int, String?> paradasMap = {};
        if (paradas is Map<String, dynamic>) {
          paradas.forEach((parada, resultado) {
            paradasMap[int.parse(parada)] = resultado;
          });
        }
        resultados[cuadrante] = paradasMap;
      });
    }

    return ChecklistLaboresPermanentesItem(
      id: json['id'],
      proceso: json['proceso'],
      observaciones: json['observaciones'],
      fotoBase64: json['fotoBase64'],
      resultadosPorCuadranteParada: resultados,
    );
  }

  // Obtener resultado para cuadrante y parada específicos
  String? getResultado(String cuadrante, int parada) {
    return resultadosPorCuadranteParada[cuadrante]?[parada];
  }

  // Establecer resultado para cuadrante y parada específicos
  void setResultado(String cuadrante, int parada, String? resultado) {
    if (!resultadosPorCuadranteParada.containsKey(cuadrante)) {
      resultadosPorCuadranteParada[cuadrante] = {};
    }
    resultadosPorCuadranteParada[cuadrante]![parada] = resultado;
  }
}

class CuadranteLaboresInfo {
  final String supervisor;
  final String bloque;
  final String? variedad;
  final String cuadrante;
  final String? fotoBase64;
  final List<Map<String, dynamic>> fotos;

  CuadranteLaboresInfo({
    required this.supervisor,
    required this.bloque,
    this.variedad,
    required this.cuadrante,
    this.fotoBase64,
    List<Map<String, dynamic>>? fotos,
  }) : fotos = fotos ?? [];

  Map<String, dynamic> toJson() {
    return {
      'supervisor': supervisor,
      'bloque': bloque,
      'variedad': variedad,
      'cuadrante': cuadrante,
      'fotoBase64': fotoBase64,
      'fotos': fotos,
    };
  }

  factory CuadranteLaboresInfo.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> fotos = [];
    if (json['fotos'] is List) {
      fotos = List<Map<String, dynamic>>.from(json['fotos']);
    } else if (json['fotos'] is String && (json['fotos'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(json['fotos'] as String);
        if (decoded is List) fotos = List<Map<String, dynamic>>.from(decoded);
      } catch (_) {}
    }
    return CuadranteLaboresInfo(
      supervisor: json['supervisor'],
      bloque: json['bloque'],
      variedad: json['variedad'],
      cuadrante: json['cuadrante'],
      fotoBase64: json['fotoBase64'],
      fotos: fotos,
    );
  }
  
  // Generar clave única para identificar este cuadrante
  String get claveUnica => '${supervisor}_${bloque}_${cuadrante}';
}

class ChecklistLaboresPermanentes {
  final int? id;
  final DateTime? fecha;
  final Finca? finca;
  final String? up; // Unidad Productiva
  final String? semana;
  final String? kontroller;
  final List<CuadranteLaboresInfo> cuadrantes;
  final List<ChecklistLaboresPermanentesItem> items;
  final DateTime? fechaEnvio;
  final double? porcentajeCumplimiento;
  final String? observacionesGenerales;

  ChecklistLaboresPermanentes({
    this.id,
    this.fecha,
    this.finca,
    this.up,
    this.semana,
    this.kontroller,
    List<CuadranteLaboresInfo>? cuadrantes,
    List<ChecklistLaboresPermanentesItem>? items,
    this.fechaEnvio,
    this.porcentajeCumplimiento,
    this.observacionesGenerales,
  }) : cuadrantes = cuadrantes ?? [],
       items = items ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha?.toIso8601String(),
      'finca': finca?.toJson(),
      'up': up,
      'semana': semana,
      'kontroller': kontroller,
      'cuadrantes': cuadrantes.map((c) => c.toJson()).toList(),
      'items': items.map((item) => item.toJson()).toList(),
      'fechaEnvio': fechaEnvio?.toIso8601String(),
      'porcentajeCumplimiento': porcentajeCumplimiento,
      'observacionesGenerales': observacionesGenerales,
    };
  }

  factory ChecklistLaboresPermanentes.fromJson(Map<String, dynamic> json) {
    return ChecklistLaboresPermanentes(
      id: json['id'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      finca: json['finca'] != null ? Finca.fromJson(json['finca']) : null,
      up: json['up'],
      semana: json['semana'],
      kontroller: json['kontroller'],
      cuadrantes: json['cuadrantes'] != null
          ? (json['cuadrantes'] as List).map((c) => CuadranteLaboresInfo.fromJson(c)).toList()
          : [],
      items: json['items'] != null
          ? (json['items'] as List).map((item) => ChecklistLaboresPermanentesItem.fromJson(item)).toList()
          : [],
      fechaEnvio: json['fechaEnvio'] != null ? DateTime.parse(json['fechaEnvio']) : null,
      porcentajeCumplimiento: json['porcentajeCumplimiento']?.toDouble(),
      observacionesGenerales: json['observacionesGenerales'],
    );
  }

  // Calcular porcentaje de cumplimiento general
  double calcularPorcentajeCumplimiento() {
    // Nueva regla: 100% cuando no hay nada marcado; al marcar baja el porcentaje
    if (items.isEmpty || cuadrantes.isEmpty) return 0.0;

    final int itemsPorParada = items.length;
    final int paradasPorCuadrante = 5;
    final int totalSlots = itemsPorParada * cuadrantes.length * paradasPorCuadrante;
    if (totalSlots == 0) return 0.0;

    int marcados = 0;
    for (var item in items) {
      for (var cuadrante in cuadrantes) {
        for (int parada = 1; parada <= 5; parada++) {
          String? resultado = item.getResultado(cuadrante.claveUnica, parada);
          if (resultado != null && resultado.trim().isNotEmpty) {
            marcados++;
          }
        }
      }
    }

    final int conformes = totalSlots - marcados;
    return (conformes / totalSlots) * 100;
  }

  // Calcular resumen por item
  Map<String, Map<String, dynamic>> calcularResumenPorItem() {
    Map<String, Map<String, dynamic>> resumen = {};

    for (var item in items) {
      int conformes = 0;
      int noConformes = 0;
      int total = 0;

      for (var cuadrante in cuadrantes) {
        for (int parada = 1; parada <= 5; parada++) {
          String? resultado = item.getResultado(cuadrante.claveUnica, parada);
          if (resultado != null && resultado.isNotEmpty) {
            total++;
            if (resultado == '1' || resultado.toLowerCase() == 'c') {
              conformes++;
            } else if (resultado == '0' || resultado.toLowerCase() == 'nc') {
              noConformes++;
            }
          }
        }
      }

      resumen[item.proceso] = {
        'conformes': conformes,
        'noConformes': noConformes,
        'total': total,
        'porcentaje': total > 0 ? (conformes / total) * 100 : 0.0,
      };
    }

    return resumen;
  }

  // Calcular resumen por cuadrante
  Map<String, Map<String, dynamic>> calcularResumenPorCuadrante() {
    Map<String, Map<String, dynamic>> resumen = {};

    for (var cuadrante in cuadrantes) {
      int conformes = 0;
      int noConformes = 0;
      int total = 0;

      for (var item in items) {
        for (int parada = 1; parada <= 5; parada++) {
          String? resultado = item.getResultado(cuadrante.claveUnica, parada);
          if (resultado != null && resultado.isNotEmpty) {
            total++;
            if (resultado == '1' || resultado.toLowerCase() == 'c') {
              conformes++;
            } else if (resultado == '0' || resultado.toLowerCase() == 'nc') {
              noConformes++;
            }
          }
        }
      }

      resumen[cuadrante.claveUnica] = {
        'conformes': conformes,
        'noConformes': noConformes,
        'total': total,
        'porcentaje': total > 0 ? (conformes / total) * 100 : 0.0,
        'supervisor': cuadrante.supervisor,
        'bloque': cuadrante.bloque,
        'variedad': cuadrante.variedad,
        'cuadrante': cuadrante.cuadrante,
      };
    }

    return resumen;
  }

  // Calcular resumen por supervisor
  Map<String, Map<String, dynamic>> calcularResumenPorSupervisor() {
    Map<String, Map<String, dynamic>> resumen = {};

    // Agrupar cuadrantes por supervisor
    Map<String, List<CuadranteLaboresInfo>> supervisorCuadrantes = {};
    for (var cuadrante in cuadrantes) {
      if (!supervisorCuadrantes.containsKey(cuadrante.supervisor)) {
        supervisorCuadrantes[cuadrante.supervisor] = [];
      }
      supervisorCuadrantes[cuadrante.supervisor]!.add(cuadrante);
    }

    supervisorCuadrantes.forEach((supervisor, cuadrantesList) {
      int conformes = 0;
      int noConformes = 0;
      int total = 0;

      for (var cuadrante in cuadrantesList) {
        for (var item in items) {
          for (int parada = 1; parada <= 5; parada++) {
            String? resultado = item.getResultado(cuadrante.claveUnica, parada);
            if (resultado != null && resultado.isNotEmpty) {
              total++;
              if (resultado == '1' || resultado.toLowerCase() == 'c') {
                conformes++;
              } else if (resultado == '0' || resultado.toLowerCase() == 'nc') {
                noConformes++;
              }
            }
          }
        }
      }

      resumen[supervisor] = {
        'conformes': conformes,
        'noConformes': noConformes,
        'total': total,
        'porcentaje': total > 0 ? (conformes / total) * 100 : 0.0,
        'cuadrantes': cuadrantesList.length,
        'bloques': cuadrantesList.map((c) => c.bloque).toSet().length,
      };
    });

    return resumen;
  }
}

// ==================== DATOS ESTÁTICOS DEL CHECKLIST ====================

class ChecklistDataLaboresPermanentes {
  static ChecklistLaboresPermanentes getChecklistLaboresPermanentes() {
    return ChecklistLaboresPermanentes(
      items: [
        ChecklistLaboresPermanentesItem(
          id: 1,
          proceso: "Desyeme conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 2,
          proceso: "Descabece conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 3,
          proceso: "Deshooting conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 4,
          proceso: "Rectificación de tocones conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 5,
          proceso: "Deschupone conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 6,
          proceso: "Deshierbe conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 7,
          proceso: "Encanaste y peinado conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 8,
          proceso: "Escarificado conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 9,
          proceso: "Escobillado conforme",
        ),
        ChecklistLaboresPermanentesItem(
          id: 10,
          proceso: "Limpieza de hojas secas",
        ),
        ChecklistLaboresPermanentesItem(
          id: 11,
          proceso: "Mangueras de goteo descubiertas",
        ),
        ChecklistLaboresPermanentesItem(
          id: 12,
          proceso: "Presencia de charcos de agua",
        ),
        ChecklistLaboresPermanentesItem(
          id: 13,
          proceso: "Tutoreo y tensado de alambres",
        ),
        ChecklistLaboresPermanentesItem(
          id: 14,
          proceso: "Drenchado",
        ),
        ChecklistLaboresPermanentesItem(
          id: 15,
          proceso: "Erradicación de velloso",
        ),
        ChecklistLaboresPermanentesItem(
          id: 16,
          proceso: "Pinch (tallos > 7mm)",
        ),
      ],
    );
  }
}