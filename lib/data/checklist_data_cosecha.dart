import '../models/dropdown_models.dart';

class ChecklistCosechaItem {
  final int id;
  final String proceso;
  final ChecklistCosechaValores valores;
  String? respuesta; // 'si', 'no', 'na'
  double? valorNumerico; // Para cuando SI tiene diferentes valores
  String? observaciones;
  String? fotoBase64; // Foto comprimida en base64

  ChecklistCosechaItem({
    required this.id,
    required this.proceso,
    required this.valores,
    this.respuesta,
    this.valorNumerico,
    this.observaciones,
    this.fotoBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proceso': proceso,
      'valores': valores.toJson(),
      'respuesta': respuesta,
      'valorNumerico': valorNumerico,
      'observaciones': observaciones,
      'fotoBase64': fotoBase64,
    };
  }

  factory ChecklistCosechaItem.fromJson(Map<String, dynamic> json) {
    return ChecklistCosechaItem(
      id: json['id'],
      proceso: json['proceso'],
      valores: ChecklistCosechaValores.fromJson(json['valores']),
      respuesta: json['respuesta'],
      valorNumerico: json['valorNumerico']?.toDouble(),
      observaciones: json['observaciones'],
      fotoBase64: json['fotoBase64'],
    );
  }
}

class ChecklistCosechaValores {
  final double? max;
  final double? promedio;
  final double? min;

  ChecklistCosechaValores({
    required this.max,
    required this.promedio,
    required this.min,
  });

  factory ChecklistCosechaValores.fromJson(Map<String, dynamic> json) {
    return ChecklistCosechaValores(
      max: json['max']?.toDouble(),
      promedio: json['promedio']?.toDouble(),
      min: json['min']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max': max,
      'promedio': promedio,
      'min': min,
    };
  }

  // Obtener las opciones disponibles para el SI
  List<double> getOpcionesSi() {
    List<double> opciones = [];
    if (max != null) opciones.add(max!);
    if (promedio != null && promedio != max) opciones.add(promedio!);
    return opciones..sort((b, a) => a.compareTo(b)); // Ordenar descendente
  }

  // Verificar si tiene opciones múltiples para SI
  bool tieneOpcionesMultiples() {
    return getOpcionesSi().length > 1;
  }
}

class ChecklistCosechaSeccion {
  final String nombre;
  final List<ChecklistCosechaItem> items;

  ChecklistCosechaSeccion({
    required this.nombre,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory ChecklistCosechaSeccion.fromJson(Map<String, dynamic> json) {
    return ChecklistCosechaSeccion(
      nombre: json['nombre'],
      items: (json['items'] as List)
          .map((item) => ChecklistCosechaItem.fromJson(item))
          .toList(),
    );
  }
}

class ChecklistCosecha {
  final List<ChecklistCosechaSeccion> secciones;
  Finca? finca;
  Bloque? bloque;
  Variedad? variedad;
  DateTime? fecha;

  ChecklistCosecha({
    required this.secciones,
    this.finca,
    this.bloque,
    this.variedad,
    this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'secciones': secciones.map((seccion) => seccion.toJson()).toList(),
      'finca': finca?.toJson(),
      'bloque': bloque?.toJson(),
      'variedad': variedad?.toJson(),
      'fecha': fecha?.toIso8601String(),
    };
  }

  factory ChecklistCosecha.fromJson(Map<String, dynamic> json) {
    return ChecklistCosecha(
      secciones: (json['secciones'] as List)
          .map((seccion) => ChecklistCosechaSeccion.fromJson(seccion))
          .toList(),
      finca: json['finca'] != null ? Finca.fromJson(json['finca']) : null,
      bloque: json['bloque'] != null ? Bloque.fromJson(json['bloque']) : null,
      variedad: json['variedad'] != null ? Variedad.fromJson(json['variedad']) : null,
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
    );
  }

  // Calcular porcentaje de cumplimiento
  double calcularPorcentajeCumplimiento() {
    int totalItems = 0;
    double puntajeTotal = 0;
    double puntajeMaximo = 0;

    for (var seccion in secciones) {
      for (var item in seccion.items) {
        if (item.respuesta != null && item.respuesta != 'na') {
          totalItems++;
          puntajeMaximo += item.valores.max ?? 4;
          
          if (item.respuesta == 'si') {
            puntajeTotal += item.valorNumerico ?? item.valores.max ?? 4;
          } else if (item.respuesta == 'no') {
            puntajeTotal += item.valores.min ?? 0;
          }
        }
      }
    }

    return totalItems > 0 ? (puntajeTotal / puntajeMaximo) * 100 : 0;
  }

  // Obtener resumen por sección
  Map<String, double> obtenerResumenSecciones() {
    Map<String, double> resumen = {};

    for (var seccion in secciones) {
      double puntajeSeccion = 0;
      double puntajeMaximoSeccion = 0;
      int itemsContados = 0;

      for (var item in seccion.items) {
        if (item.respuesta != null && item.respuesta != 'na') {
          itemsContados++;
          puntajeMaximoSeccion += item.valores.max ?? 4;
          
          if (item.respuesta == 'si') {
            puntajeSeccion += item.valorNumerico ?? item.valores.max ?? 4;
          } else if (item.respuesta == 'no') {
            puntajeSeccion += item.valores.min ?? 0;
          }
        }
      }

      resumen[seccion.nombre] = itemsContados > 0 
          ? (puntajeSeccion / puntajeMaximoSeccion) * 100 
          : 0;
    }

    return resumen;
  }
}

// Datos estáticos del checklist de cosecha basados en el Excel
class ChecklistDataCosecha {
  static ChecklistCosecha getChecklistCosecha() {
    return ChecklistCosecha(
      secciones: [
        ChecklistCosechaSeccion(
          nombre: "PREPARACIÓN Y IDENTIFICACIÓN",
          items: [
            ChecklistCosechaItem(
              id: 1,
              proceso: "Identificación de cuadrantes",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 2,
              proceso: "Identificacion zona de manejo",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 3,
              proceso: "Definición punto muestra",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 4,
              proceso: "Uso de polisombra",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 5,
              proceso: "Desinfección de mallas",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 6,
              proceso: "Equipos y herramientas",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistCosechaSeccion(
          nombre: "INFRAESTRUCTURA Y MANTENIMIENTO",
          items: [
            ChecklistCosechaItem(
              id: 7,
              proceso: "Tanques aforados",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 8,
              proceso: "Nivelación del tacho",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 9,
              proceso: "Ph del agua",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 10,
              proceso: "Limpieza tachos de hidratación",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 11,
              proceso: "Limpieza de recolectores de agua lluvia",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 12,
              proceso: "Buen estado de las cortinas",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 13,
              proceso: "Buen estado de las culatas",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 14,
              proceso: "Buen estado de las polisombras",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 15,
              proceso: "Buen estado del cable vía",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
          ],
        ),
        ChecklistCosechaSeccion(
          nombre: "LIMPIEZA Y MANTENIMIENTO GENERAL",
          items: [
            ChecklistCosechaItem(
              id: 16,
              proceso: "Limpieza de faldones",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 17,
              proceso: "Corte motoguadaña",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
            ChecklistCosechaItem(
              id: 18,
              proceso: "Limpieza Alrededores",
              valores: ChecklistCosechaValores(max: 4, promedio: 2, min: 0),
            ),
          ],
        ),
        ChecklistCosechaSeccion(
          nombre: "APLICACIÓN Y CONTROL",
          items: [
            ChecklistCosechaItem(
              id: 19,
              proceso: "Programa de drench/campo",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 20,
              proceso: "Volumen inicial",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 21,
              proceso: "Orden de mezcla",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 22,
              proceso: "Volumen final",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 23,
              proceso: "Buen estado de los equipos",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 24,
              proceso: "Control del tiempo",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
            ChecklistCosechaItem(
              id: 25,
              proceso: "Actualización del registro de control de drench",
              valores: ChecklistCosechaValores(max: 4, promedio: null, min: 0),
            ),
          ],
        ),
      ],
    );
  }
}