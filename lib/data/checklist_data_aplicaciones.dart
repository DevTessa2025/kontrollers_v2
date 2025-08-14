import '../models/dropdown_models.dart';

class ChecklistAplicacionesItem {
  final int id;
  final String proceso;
  final ChecklistAplicacionesValores valores;
  String? respuesta; // 'si', 'no', 'na'
  double? valorNumerico; // Para cuando SI tiene diferentes valores
  String? observaciones;
  String? fotoBase64; // Foto comprimida en base64

  ChecklistAplicacionesItem({
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

  factory ChecklistAplicacionesItem.fromJson(Map<String, dynamic> json) {
    return ChecklistAplicacionesItem(
      id: json['id'],
      proceso: json['proceso'],
      valores: ChecklistAplicacionesValores.fromJson(json['valores']),
      respuesta: json['respuesta'],
      valorNumerico: json['valorNumerico']?.toDouble(),
      observaciones: json['observaciones'],
      fotoBase64: json['fotoBase64'],
    );
  }
}

class ChecklistAplicacionesValores {
  final double? max;
  final double? promedio;
  final double? min;

  ChecklistAplicacionesValores({
    required this.max,
    required this.promedio,
    required this.min,
  });

  factory ChecklistAplicacionesValores.fromJson(Map<String, dynamic> json) {
    return ChecklistAplicacionesValores(
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

class ChecklistAplicacionesSeccion {
  final String nombre;
  final List<ChecklistAplicacionesItem> items;

  ChecklistAplicacionesSeccion({
    required this.nombre,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory ChecklistAplicacionesSeccion.fromJson(Map<String, dynamic> json) {
    return ChecklistAplicacionesSeccion(
      nombre: json['nombre'],
      items: (json['items'] as List)
          .map((item) => ChecklistAplicacionesItem.fromJson(item))
          .toList(),
    );
  }
}

class ChecklistAplicaciones {
  final List<ChecklistAplicacionesSeccion> secciones;
  Finca? finca;
  Bloque? bloque;
  Bomba? bomba;
  DateTime? fecha;

  ChecklistAplicaciones({
    required this.secciones,
    this.finca,
    this.bloque,
    this.bomba,
    this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'secciones': secciones.map((seccion) => seccion.toJson()).toList(),
      'finca': finca?.toJson(),
      'bloque': bloque?.toJson(),
      'bomba': bomba?.toJson(),
      'fecha': fecha?.toIso8601String(),
    };
  }

  factory ChecklistAplicaciones.fromJson(Map<String, dynamic> json) {
    return ChecklistAplicaciones(
      secciones: (json['secciones'] as List)
          .map((seccion) => ChecklistAplicacionesSeccion.fromJson(seccion))
          .toList(),
      finca: json['finca'] != null ? Finca.fromJson(json['finca']) : null,
      bloque: json['bloque'] != null ? Bloque.fromJson(json['bloque']) : null,
      bomba: json['bomba'] != null ? Bomba.fromJson(json['bomba']) : null,
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
          puntajeMaximo += item.valores.max ?? 2.5;
          
          if (item.respuesta == 'si') {
            puntajeTotal += item.valorNumerico ?? item.valores.max ?? 2.5;
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
          puntajeMaximoSeccion += item.valores.max ?? 2.5;
          
          if (item.respuesta == 'si') {
            puntajeSeccion += item.valorNumerico ?? item.valores.max ?? 2.5;
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

// Datos estáticos del checklist de aplicaciones basados en el Excel
class ChecklistDataAplicaciones {
  static ChecklistAplicaciones getChecklistAplicaciones() {
    return ChecklistAplicaciones(
      secciones: [
        ChecklistAplicacionesSeccion(
          nombre: "PROGRAMA DE FUMIGACIÓN Y RECEPCIÓN DE PRODUCTOS",
          items: [
            ChecklistAplicacionesItem(
              id: 1,
              proceso: "Programa de fumigación",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 2,
              proceso: "Programa de fumigación /campo",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 3,
              proceso: "Total tiempo/efectivo/bomba",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 4,
              proceso: "Rotación del producto",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistAplicacionesSeccion(
          nombre: "REVISIÓN DEL ESTADO DEL EQUIPO",
          items: [
            ChecklistAplicacionesItem(
              id: 5,
              proceso: "Buen estado de las mangueras",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 6,
              proceso: "Buen estado de lanzas",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 7,
              proceso: "Buen estado de tanques",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 8,
              proceso: "Equipos de protección",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 9,
              proceso: "Limpieza de boquillas y filtros",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 10,
              proceso: "Aforo de lanzas Scarab",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 11,
              proceso: "Lavado de mangueras entre bloques",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistAplicacionesSeccion(
          nombre: "PREPARACIÓN DE MEZCLA",
          items: [
            ChecklistAplicacionesItem(
              id: 12,
              proceso: "Volumen inicial",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 13,
              proceso: "Ajuste de dureza",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 14,
              proceso: "Regular el pH",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 15,
              proceso: "Premezcla",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 16,
              proceso: "Orden de mezcla/SCARAB",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 17,
              proceso: "Orden de mezcla programación/CAMPO",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 18,
              proceso: "Dosis de productos",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 19,
              proceso: "Volumen final",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistAplicacionesSeccion(
          nombre: "CONTROL DE APLICACIÓN",
          items: [
            ChecklistAplicacionesItem(
              id: 20,
              proceso: "Invernadero libre de personal",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 21,
              proceso: "Instrucciones de aplicaciones",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 22,
              proceso: "Control de temperatura",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 23,
              proceso: "Presion de la bomba",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 24,
              proceso: "Fecha y responsables actualizados",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 25,
              proceso: "Tiempos/cama",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 26,
              proceso: "Verificacion/ corrección tiempos",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 27,
              proceso: "Tipo de lanza",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 28,
              proceso: "Boquilla",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 29,
              proceso: "Nro.boquillas",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 30,
              proceso: "Tercio aplicado",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 31,
              proceso: "Altura de lanza",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 32,
              proceso: "Ángulo lanza-cama",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 33,
              proceso: "Doble pase",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 34,
              proceso: "Cambio de preparación",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistAplicacionesSeccion(
          nombre: "DESPUÉS DE LAS APLICACIONES",
          items: [
            ChecklistAplicacionesItem(
              id: 35,
              proceso: "Faltantes/ Sobrantes",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 36,
              proceso: "Actualización del registro de control de aplicaciones",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 37,
              proceso: "Lavado del equipo de fumigación",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 38,
              proceso: "Revisión del Jefe/Tecnico MIPE",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistAplicacionesSeccion(
          nombre: "ASEGURAMIENTO DE AFORO Y EFICIENCIA DE LA APLICACIÓN",
          items: [
            ChecklistAplicacionesItem(
              id: 39,
              proceso: "Aforo de lanzas",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
            ChecklistAplicacionesItem(
              id: 40,
              proceso: "Uso del papel hidro sensible",
              valores: ChecklistAplicacionesValores(max: 2.5, promedio: 1.25, min: 0),
            ),
          ],
        ),
      ],
    );
  }
}