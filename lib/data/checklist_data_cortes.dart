import '../models/dropdown_models.dart';

// ==================== MODELOS ESPECÍFICOS PARA CORTES ====================

class ChecklistCortesItem {
  final int id;
  final String proceso;
  String? observaciones;
  String? fotoBase64;
  // Matriz de resultados por cuadrante y muestra (12 ítems x 10 muestras)
  Map<String, Map<int, String?>> resultadosPorCuadrante; // cuadrante -> {muestra -> resultado}

  ChecklistCortesItem({
    required this.id,
    required this.proceso,
    this.observaciones,
    this.fotoBase64,
    Map<String, Map<int, String?>>? resultadosPorCuadrante,
  }) : resultadosPorCuadrante = resultadosPorCuadrante ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proceso': proceso,
      'observaciones': observaciones,
      'fotoBase64': fotoBase64,
      'resultadosPorCuadrante': resultadosPorCuadrante.map((cuadrante, muestras) => 
        MapEntry(cuadrante, muestras.map((muestra, resultado) => 
          MapEntry(muestra.toString(), resultado))),
      ),
    };
  }

  factory ChecklistCortesItem.fromJson(Map<String, dynamic> json) {
    Map<String, Map<int, String?>> resultados = {};
    if (json['resultadosPorCuadrante'] != null) {
      Map<String, dynamic> cuadrantes = json['resultadosPorCuadrante'];
      cuadrantes.forEach((cuadrante, muestras) {
        Map<int, String?> muestrasMap = {};
        if (muestras is Map<String, dynamic>) {
          muestras.forEach((muestra, resultado) {
            muestrasMap[int.parse(muestra)] = resultado;
          });
        }
        resultados[cuadrante] = muestrasMap;
      });
    }

    return ChecklistCortesItem(
      id: json['id'],
      proceso: json['proceso'],
      observaciones: json['observaciones'],
      fotoBase64: json['fotoBase64'],
      resultadosPorCuadrante: resultados,
    );
  }

  // Obtener resultado para cuadrante y muestra específicos
  String? getResultado(String cuadrante, int muestra) {
    return resultadosPorCuadrante[cuadrante]?[muestra];
  }

  // Establecer resultado para cuadrante y muestra específicos
  void setResultado(String cuadrante, int muestra, String? resultado) {
    if (!resultadosPorCuadrante.containsKey(cuadrante)) {
      resultadosPorCuadrante[cuadrante] = {};
    }
    resultadosPorCuadrante[cuadrante]![muestra] = resultado;
  }
}

class CuadranteInfo {
  final String cuadrante;
  final String? bloque;
  final String? variedad;
  final String? supervisor;

  CuadranteInfo({
    required this.cuadrante,
    this.bloque,
    this.variedad,
    this.supervisor,
  });

  Map<String, dynamic> toJson() {
    return {
      'cuadrante': cuadrante,
      'bloque': bloque,
      'variedad': variedad,
      'supervisor': supervisor,
    };
  }

  factory CuadranteInfo.fromJson(Map<String, dynamic> json) {
    return CuadranteInfo(
      cuadrante: json['cuadrante'],
      bloque: json['bloque'],
      variedad: json['variedad'],
      supervisor: json['supervisor'],
    );
  }
}

class ChecklistCortes {
  final int? id;
  final DateTime? fecha;
  final Finca? finca;
  final String? supervisor;
  final List<CuadranteInfo> cuadrantes;
  final List<ChecklistCortesItem> items;
  final DateTime? fechaEnvio;
  final double? porcentajeCumplimiento;

  ChecklistCortes({
    this.id,
    this.fecha,
    this.finca,
    this.supervisor,
    List<CuadranteInfo>? cuadrantes,
    List<ChecklistCortesItem>? items,
    this.fechaEnvio,
    this.porcentajeCumplimiento,
  }) : cuadrantes = cuadrantes ?? [],
       items = items ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fecha': fecha?.toIso8601String(),
      'finca': finca?.toJson(),
      'supervisor': supervisor,
      'cuadrantes': cuadrantes.map((c) => c.toJson()).toList(),
      'items': items.map((item) => item.toJson()).toList(),
      'fechaEnvio': fechaEnvio?.toIso8601String(),
      'porcentajeCumplimiento': porcentajeCumplimiento,
    };
  }

  factory ChecklistCortes.fromJson(Map<String, dynamic> json) {
    return ChecklistCortes(
      id: json['id'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      finca: json['finca'] != null ? Finca.fromJson(json['finca']) : null,
      supervisor: json['supervisor'],
      cuadrantes: json['cuadrantes'] != null
          ? (json['cuadrantes'] as List).map((c) => CuadranteInfo.fromJson(c)).toList()
          : [],
      items: json['items'] != null
          ? (json['items'] as List).map((item) => ChecklistCortesItem.fromJson(item)).toList()
          : [],
      fechaEnvio: json['fechaEnvio'] != null ? DateTime.parse(json['fechaEnvio']) : null,
      porcentajeCumplimiento: json['porcentajeCumplimiento']?.toDouble(),
    );
  }

  // Calcular porcentaje de cumplimiento general
  double calcularPorcentajeCumplimiento() {
    if (items.isEmpty || cuadrantes.isEmpty) return 0.0;

    // Usar exclusivamente el ítem "Corte conforme" (id 1) y promediar por cuadrante
    ChecklistCortesItem? itemCorteConforme;
    for (final item in items) {
      if (item.id == 1 || item.proceso.toLowerCase().contains('corte conforme')) {
        itemCorteConforme = item;
        break;
      }
    }

    if (itemCorteConforme == null) return 0.0;

    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;

    for (final cuadrante in cuadrantes) {
      int muestrasConformes = 0;
      for (int muestra = 1; muestra <= 10; muestra++) {
        final resultado = itemCorteConforme.getResultado(cuadrante.cuadrante, muestra);
        if (resultado != null && resultado.isNotEmpty) {
          if (resultado.toLowerCase() == 'c' || resultado == '1') {
            muestrasConformes++;
          }
        }
      }
      final porcentajeCuadrante = (muestrasConformes / 10) * 100;
      sumaPorcentajes += porcentajeCuadrante;
      cuadrantesConDatos++;
    }

    return cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
  }

  // Calcular resumen por ítem
  Map<String, Map<String, dynamic>> calcularResumenPorItem() {
    Map<String, Map<String, dynamic>> resumen = {};

    for (var item in items) {
      int conformes = 0;
      int noConformes = 0;
      int total = 0;

      for (var cuadrante in cuadrantes) {
        for (int muestra = 1; muestra <= 10; muestra++) {
          String? resultado = item.getResultado(cuadrante.cuadrante, muestra);
          if (resultado != null && resultado.isNotEmpty) {
            total++;
            if (resultado.toLowerCase() == 'c' || resultado == '1') {
              conformes++;
            } else if (resultado.toLowerCase() == 'nc' || resultado == '0') {
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
        for (int muestra = 1; muestra <= 10; muestra++) {
          String? resultado = item.getResultado(cuadrante.cuadrante, muestra);
          if (resultado != null && resultado.isNotEmpty) {
            total++;
            if (resultado.toLowerCase() == 'c' || resultado == '1') {
              conformes++;
            } else if (resultado.toLowerCase() == 'nc' || resultado == '0') {
              noConformes++;
            }
          }
        }
      }

      resumen[cuadrante.cuadrante] = {
        'conformes': conformes,
        'noConformes': noConformes,
        'total': total,
        'porcentaje': total > 0 ? (conformes / total) * 100 : 0.0,
        'bloque': cuadrante.bloque,
        'variedad': cuadrante.variedad,
      };
    }

    return resumen;
  }
}

// ==================== DATOS ESTÁTICOS DEL CHECKLIST ====================

class ChecklistDataCortes {
  static ChecklistCortes getChecklistCortes() {
    return ChecklistCortes(
      items: [
        ChecklistCortesItem(
          id: 1,
          proceso: "Corte conforme",
        ),
        ChecklistCortesItem(
          id: 2,
          proceso: "Dentro de zona de manejo",
        ),
        ChecklistCortesItem(
          id: 3,
          proceso: "Corte con desinfectante",
        ),
        ChecklistCortesItem(
          id: 4,
          proceso: "Calibre conforme (≥4)",
        ),
        ChecklistCortesItem(
          id: 5,
          proceso: "Distancia mínimo 10 cm (subiendo)",
        ),
        ChecklistCortesItem(
          id: 6,
          proceso: "Yema a yema (bajando)",
        ),
        ChecklistCortesItem(
          id: 7,
          proceso: "Orientación yema (orilleros)",
        ),
        ChecklistCortesItem(
          id: 8,
          proceso: "Tocón entre 0,5 cm-1 cm",
        ),
        ChecklistCortesItem(
          id: 9,
          proceso: "Desnuque total",
        ),
        ChecklistCortesItem(
          id: 10,
          proceso: "Corte sin desgarre",
        ),
        ChecklistCortesItem(
          id: 11,
          proceso: "Bisel corte",
        ),
        ChecklistCortesItem(
          id: 12,
          proceso: "Corte en zigzag",
        ),
      ],
    );
  }
}