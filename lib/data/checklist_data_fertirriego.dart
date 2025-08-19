// ==================== CHECKLIST DATA FERTIRRIEGO ====================
import '../models/dropdown_models.dart';

class ChecklistFertiriegoValores {
  final double? max;
  final dynamic promedio; // Puede ser double o String ("N/A")
  final double? min;

  ChecklistFertiriegoValores({
    this.max,
    this.promedio,
    this.min,
  });

  Map<String, dynamic> toJson() {
    return {
      'max': max,
      'promedio': promedio,
      'min': min,
    };
  }

  factory ChecklistFertiriegoValores.fromJson(Map<String, dynamic> json) {
    return ChecklistFertiriegoValores(
      max: json['max']?.toDouble(),
      promedio: json['promedio'],
      min: json['min']?.toDouble(),
    );
  }
}

class ChecklistFertiriegoItem {
  final int id;
  final String proceso;
  final ChecklistFertiriegoValores valores;
  String? respuesta; // 'si', 'no', 'na'
  double? valorNumerico;
  String? observaciones;
  String? fotoBase64;

  ChecklistFertiriegoItem({
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

  factory ChecklistFertiriegoItem.fromJson(Map<String, dynamic> json) {
    return ChecklistFertiriegoItem(
      id: json['id'],
      proceso: json['proceso'],
      valores: ChecklistFertiriegoValores.fromJson(json['valores']),
      respuesta: json['respuesta'],
      valorNumerico: json['valorNumerico']?.toDouble(),
      observaciones: json['observaciones'],
      fotoBase64: json['fotoBase64'],
    );
  }

  // Obtener opciones disponibles para respuesta "SI" cuando tiene valores múltiples
  List<double> getOpcionesSi() {
    List<double> opciones = [];
    if (valores.max != null) opciones.add(valores.max!);
    if (valores.promedio != null && valores.promedio is double && valores.promedio != valores.max) {
      opciones.add(valores.promedio as double);
    }
    return opciones..sort((b, a) => a.compareTo(b)); // Ordenar descendente
  }

  // Verificar si tiene opciones múltiples para SI
  bool tieneOpcionesMultiples() {
    return getOpcionesSi().length > 1;
  }
}

class ChecklistFertiriegoSeccion {
  final String nombre;
  final List<ChecklistFertiriegoItem> items;

  ChecklistFertiriegoSeccion({
    required this.nombre,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory ChecklistFertiriegoSeccion.fromJson(Map<String, dynamic> json) {
    return ChecklistFertiriegoSeccion(
      nombre: json['nombre'],
      items: (json['items'] as List)
          .map((item) => ChecklistFertiriegoItem.fromJson(item))
          .toList(),
    );
  }
}

class ChecklistFertirriego {
  final List<ChecklistFertiriegoSeccion> secciones;
  Finca? finca;
  Bloque? bloque;
  DateTime? fecha;

  ChecklistFertirriego({
    required this.secciones,
    this.finca,
    this.bloque,
    this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'secciones': secciones.map((seccion) => seccion.toJson()).toList(),
      'finca': finca?.toJson(),
      'bloque': bloque?.toJson(),
      'fecha': fecha?.toIso8601String(),
    };
  }

  factory ChecklistFertirriego.fromJson(Map<String, dynamic> json) {
    return ChecklistFertirriego(
      secciones: (json['secciones'] as List)
          .map((seccion) => ChecklistFertiriegoSeccion.fromJson(seccion))
          .toList(),
      finca: json['finca'] != null ? Finca.fromJson(json['finca']) : null,
      bloque: json['bloque'] != null ? Bloque.fromJson(json['bloque']) : null,
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

// Datos estáticos del checklist de fertirriego basados en el Excel
class ChecklistDataFertirriego {
  static ChecklistFertirriego getChecklistFertirriego() {
    return ChecklistFertirriego(
      secciones: [
        ChecklistFertiriegoSeccion(
          nombre: "FÓRMULA DE FERTILIZACIÓN Y RECEPCIÓN DE PEDIDOS",
          items: [
            ChecklistFertiriegoItem(
              id: 1,
              proceso: "Fórmula de riego actualizada",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 2,
              proceso: "Fórmula de riego-Caseta",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 3,
              proceso: "Programación semanal- Caseta",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 4,
              proceso: "Consumos de fertilizantes vs fórmula de riego (kg) - Caseta",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 5,
              proceso: "Registro consumo de fertilizantes",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 6,
              proceso: "Pesas en casetas",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
          ],
        ),
        ChecklistFertiriegoSeccion(
          nombre: "PREPARACIÓN",
          items: [
            ChecklistFertiriegoItem(
              id: 7,
              proceso: "Parámetros del agua",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 8,
              proceso: "Lavado de tanques y filtros",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 9,
              proceso: "Llenado de tanques inicial",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 10,
              proceso: "Orden de colocación productos fertilizantes",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 11,
              proceso: "Preparación quelato de hierro + nitrato de calcio",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 13,
              proceso: "Nivel de solución en el tanque",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 14,
              proceso: "Descarga homogénea",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 15,
              proceso: "Llenado de tanques final",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
          ],
        ),
        ChecklistFertiriegoSeccion(
          nombre: "PROGRAMACIÓN DEL SISTEMA DE RIEGO",
          items: [
            ChecklistFertiriegoItem(
              id: 16,
              proceso: "Lámina total (L/m2)",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 17,
              proceso: "Variables programadas",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
          ],
        ),
        ChecklistFertiriegoSeccion(
          nombre: "CONTROL DE VARIABLES EN EL CAMPO",
          items: [
            ChecklistFertiriegoItem(
              id: 18,
              proceso: "CE y pH premix",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 20,
              proceso: "CE y pH goteros",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 21,
              proceso: "Presión de las válvulas",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 22,
              proceso: "Aforos en las mangueras",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 23,
              proceso: "Líneas de goteo",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 24,
              proceso: "Mangueras rotas",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
            ChecklistFertiriegoItem(
              id: 25,
              proceso: "Mangueras incompletas",
              valores: ChecklistFertiriegoValores(max: 4, promedio: "N/A", min: 0),
            ),
          ],
        ),
      ],
    );
  }
}