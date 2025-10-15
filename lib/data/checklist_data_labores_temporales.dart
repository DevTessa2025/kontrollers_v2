import '../models/dropdown_models.dart';

// ==================== MODELOS ESPECÍFICOS PARA LABORES TEMPORALES ====================

class ChecklistLaboresTemporalesItem {
  final int id;
  final String proceso;
  String? observaciones;
  String? fotoBase64;
  // Estructura: cuadrante -> parada -> resultado (0/1)
  Map<String, Map<int, String?>> resultadosPorCuadranteParada;

  ChecklistLaboresTemporalesItem({
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

  factory ChecklistLaboresTemporalesItem.fromJson(Map<String, dynamic> json) {
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

    return ChecklistLaboresTemporalesItem(
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

  // Calcular porcentaje de cumplimiento para este ítem
  double calcularPorcentajeCumplimiento() {
    int totalEvaluaciones = 0;
    int conformes = 0;

    resultadosPorCuadranteParada.forEach((cuadrante, paradas) {
      paradas.forEach((parada, resultado) {
        if (resultado != null && resultado.trim().isNotEmpty) {
          totalEvaluaciones++;
          String resultadoLower = resultado.toLowerCase().trim();
          if (resultadoLower == 'c' || resultadoLower == '1') {
            conformes++;
          }
        }
      });
    });

    return totalEvaluaciones > 0 ? (conformes / totalEvaluaciones) * 100 : 0.0;
  }
}

class CuadranteLaboresTemporalesInfo {
  final String supervisor;
  final String bloque;
  final String variedad;
  final String cuadrante;
  final String claveUnica;

  CuadranteLaboresTemporalesInfo({
    required this.supervisor,
    required this.bloque,
    required this.variedad,
    required this.cuadrante,
  }) : claveUnica = '${supervisor}_${bloque}_${cuadrante}';

  Map<String, dynamic> toJson() {
    return {
      'supervisor': supervisor,
      'bloque': bloque,
      'variedad': variedad,
      'cuadrante': cuadrante,
      'claveUnica': claveUnica,
    };
  }

  factory CuadranteLaboresTemporalesInfo.fromJson(Map<String, dynamic> json) {
    return CuadranteLaboresTemporalesInfo(
      supervisor: json['supervisor'] ?? '',
      bloque: json['bloque'] ?? '',
      variedad: json['variedad'] ?? '',
      cuadrante: json['cuadrante'] ?? '',
    );
  }
}

class ChecklistLaboresTemporales {
  int? id;
  DateTime? fecha;
  Finca? finca;
  String? up;
  String? semana;
  String? kontroller;
  List<CuadranteLaboresTemporalesInfo> cuadrantes;
  List<ChecklistLaboresTemporalesItem> items;
  DateTime? fechaEnvio;
  double? porcentajeCumplimiento;
  String? observacionesGenerales;

  ChecklistLaboresTemporales({
    this.id,
    this.fecha,
    this.finca,
    this.up,
    this.semana,
    this.kontroller,
    required this.cuadrantes,
    required this.items,
    this.fechaEnvio,
    this.porcentajeCumplimiento,
    this.observacionesGenerales,
  });

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

  factory ChecklistLaboresTemporales.fromJson(Map<String, dynamic> json) {
    List<CuadranteLaboresTemporalesInfo> cuadrantes = [];
    if (json['cuadrantes'] != null) {
      cuadrantes = (json['cuadrantes'] as List)
          .map((c) => CuadranteLaboresTemporalesInfo.fromJson(c))
          .toList();
    }

    List<ChecklistLaboresTemporalesItem> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List)
          .map((item) => ChecklistLaboresTemporalesItem.fromJson(item))
          .toList();
    }

    Finca? finca;
    if (json['finca'] != null) {
      finca = Finca.fromJson(json['finca']);
    }

    return ChecklistLaboresTemporales(
      id: json['id'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      finca: finca,
      up: json['up'],
      semana: json['semana'],
      kontroller: json['kontroller'],
      cuadrantes: cuadrantes,
      items: items,
      fechaEnvio: json['fechaEnvio'] != null ? DateTime.parse(json['fechaEnvio']) : null,
      porcentajeCumplimiento: json['porcentajeCumplimiento']?.toDouble(),
      observacionesGenerales: json['observacionesGenerales'],
    );
  }

  // Calcular porcentaje general de cumplimiento
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

    final int conformes = totalSlots - marcados; // no marcados
    return (conformes / totalSlots) * 100;
  }

  // Obtener estadísticas generales
  Map<String, int> obtenerEstadisticas() {
    // Nueva regla: Conformes = no marcados; No Conformes = marcados
    if (items.isEmpty || cuadrantes.isEmpty) {
      return {'totalEvaluaciones': 0, 'conformes': 0, 'noConformes': 0};
    }

    final int itemsPorParada = items.length;
    final int paradasPorCuadrante = 5;
    final int totalSlots = itemsPorParada * cuadrantes.length * paradasPorCuadrante;

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
    final int noConformes = marcados;
    return {
      'totalEvaluaciones': totalSlots,
      'conformes': conformes,
      'noConformes': noConformes,
    };
  }
}

// ==================== DATOS ESTÁTICOS DEL CHECKLIST ====================

class ChecklistDataLaboresTemporales {
  static ChecklistLaboresTemporales getChecklistLaboresTemporales() {
    return ChecklistLaboresTemporales(
      cuadrantes: [],
      items: [
        ChecklistLaboresTemporalesItem(
          id: 1,
          proceso: "Alzado de hombros",
        ),
        ChecklistLaboresTemporalesItem(
          id: 2,
          proceso: "Hormonado",
        ),
        ChecklistLaboresTemporalesItem(
          id: 3,
          proceso: "Paloteo",
        ),
        ChecklistLaboresTemporalesItem(
          id: 4,
          proceso: "Incorporación de materia orgánica",
        ),
        ChecklistLaboresTemporalesItem(
          id: 5,
          proceso: "Limpieza de agrobacterium",
        ),
      ],
    );
  }
}
