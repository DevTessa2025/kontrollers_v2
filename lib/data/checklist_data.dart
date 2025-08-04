import '../models/dropdown_models.dart';

class ChecklistItem {
  final int id;
  final String proceso;
  final ChecklistValores valores;
  String? respuesta; // 'si', 'no', 'na'
  double? valorNumerico; // Para cuando SI tiene diferentes valores
  String? observaciones;
  String? fotoBase64; // Foto comprimida en base64

  ChecklistItem({
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

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      proceso: json['proceso'],
      valores: ChecklistValores.fromJson(json['valores']),
      respuesta: json['respuesta'],
      valorNumerico: json['valorNumerico']?.toDouble(),
      observaciones: json['observaciones'],
      fotoBase64: json['fotoBase64'],
    );
  }
}

class ChecklistValores {
  final double? max;
  final double? promedio;
  final double? min;

  ChecklistValores({
    required this.max,
    required this.promedio,
    required this.min,
  });

  Map<String, dynamic> toJson() {
    return {
      'max': max,
      'promedio': promedio,
      'min': min,
    };
  }

  factory ChecklistValores.fromJson(Map<String, dynamic> json) {
    return ChecklistValores(
      max: json['max']?.toDouble(),
      promedio: json['promedio']?.toDouble(),
      min: json['min']?.toDouble(),
    );
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

class ChecklistSeccion {
  final String nombre;
  final List<ChecklistItem> items;

  ChecklistSeccion({
    required this.nombre,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  factory ChecklistSeccion.fromJson(Map<String, dynamic> json) {
    return ChecklistSeccion(
      nombre: json['nombre'],
      items: (json['items'] as List)
          .map((item) => ChecklistItem.fromJson(item))
          .toList(),
    );
  }
}

class ChecklistBodega {
  final String titulo;
  final String subtitulo;
  final List<ChecklistSeccion> secciones;
  Finca? finca;
  Supervisor? supervisor;
  Pesador? pesador;
  DateTime? fecha;

  ChecklistBodega({
    required this.titulo,
    required this.subtitulo,
    required this.secciones,
    this.finca,
    this.supervisor,
    this.pesador,
    this.fecha,
  });

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'subtitulo': subtitulo,
      'secciones': secciones.map((seccion) => seccion.toJson()).toList(),
      'finca': finca?.toJson(),
      'supervisor': supervisor?.toJson(),
      'pesador': pesador?.toJson(),
      'fecha': fecha?.toIso8601String(),
    };
  }

  factory ChecklistBodega.fromJson(Map<String, dynamic> json) {
    return ChecklistBodega(
      titulo: json['titulo'],
      subtitulo: json['subtitulo'],
      secciones: (json['secciones'] as List)
          .map((seccion) => ChecklistSeccion.fromJson(seccion))
          .toList(),
      finca: json['finca'] != null ? Finca.fromJson(json['finca']) : null,
      supervisor: json['supervisor'] != null ? Supervisor.fromJson(json['supervisor']) : null,
      pesador: json['pesador'] != null ? Pesador.fromJson(json['pesador']) : null,
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
          puntajeMaximo += item.valores.max ?? 5;
          
          if (item.respuesta == 'si') {
            puntajeTotal += item.valorNumerico ?? item.valores.max ?? 5;
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
          puntajeMaximoSeccion += item.valores.max ?? 5;
          
          if (item.respuesta == 'si') {
            puntajeSeccion += item.valorNumerico ?? item.valores.max ?? 5;
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

// Datos estáticos del checklist de bodega basados en el Excel
class ChecklistDataBodega {
  static ChecklistBodega getChecklistBodega() {
    return ChecklistBodega(
      titulo: "LISTA DE CHEQUEO BODEGA",
      subtitulo: "APLICACIONES FITOSANITARIAS",
      fecha: DateTime.now(),
      secciones: [
        ChecklistSeccion(
          nombre: "APLICACIONES FITOSANITARIAS",
          items: [
            ChecklistItem(
              id: 1,
              proceso: "Programa de fumigación",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 2,
              proceso: "Envases y etiquetado de productos",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 3,
              proceso: "Pesaje de productos, bodega",
              valores: ChecklistValores(max: 5, promedio: 2.5, min: 0),
            ),
            ChecklistItem(
              id: 4,
              proceso: "Despacho de productos",
              valores: ChecklistValores(max: 5, promedio: 2.5, min: 0),
            ),
            ChecklistItem(
              id: 5,
              proceso: "Verificación de productos en campo",
              valores: ChecklistValores(max: 5, promedio: 2.5, min: 0),
            ),
          ],
        ),
        ChecklistSeccion(
          nombre: "DRENCH",
          items: [
            ChecklistItem(
              id: 6,
              proceso: "Programa de drench",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 7,
              proceso: "Envases y etiquetado de productos",
              valores: ChecklistValores(max: 5, promedio: null, min: null),
            ),
            ChecklistItem(
              id: 8,
              proceso: "Pesaje de productos - Bodega",
              valores: ChecklistValores(max: 5, promedio: 2.5, min: 0),
            ),
            ChecklistItem(
              id: 9,
              proceso: "Verificación de productos campo",
              valores: ChecklistValores(max: 5, promedio: 2.5, min: 0),
            ),
          ],
        ),
        ChecklistSeccion(
          nombre: "FERTIRRIEGO",
          items: [
            ChecklistItem(
              id: 10,
              proceso: "Fórmula de riego - Bodega",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 11,
              proceso: "Recepción de productos - Bodega",
              valores: ChecklistValores(max: 5, promedio: 2.5, min: 0),
            ),
            ChecklistItem(
              id: 12,
              proceso: "Productos etiquetados - Caseta",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
          ],
        ),
        ChecklistSeccion(
          nombre: "CONTROL INTERNO",
          items: [
            ChecklistItem(
              id: 13,
              proceso: "Validación diaria de Balanzas",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 14,
              proceso: "Validación con patrón",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 15,
              proceso: "Almacenamiento de insumos",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 16,
              proceso: "Almacenamiento diferenciado",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 17,
              proceso: "Orden de colocación",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 18,
              proceso: "Orden de distribución",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 19,
              proceso: "Control de Almacenamiento",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
            ChecklistItem(
              id: 20,
              proceso: "Trazabilidad",
              valores: ChecklistValores(max: 5, promedio: null, min: 0),
            ),
          ],
        ),
      ],
    );
  }
}