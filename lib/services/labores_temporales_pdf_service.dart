import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class LaboresTemporalesPdfService {
  // Colores para el PDF
  static const PdfColor COLOR_NEGRO = PdfColors.black;
  static const PdfColor COLOR_GRIS_OSCURO = PdfColors.grey800;
  static const PdfColor COLOR_GRIS_CLARO = PdfColors.grey300;
  static const PdfColor COLOR_BLANCO = PdfColors.white;

  static Future<Uint8List> generate({required Map<String, dynamic> data}) async {
    try {
      // Parsear datos del record
      final record = data;
      final cuadrantesData = record['cuadrantes_json'];
      final itemsData = record['items_json'];

      List<Map<String, dynamic>> cuadrantes = [];
      if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
        cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
      } else if (cuadrantesData is List) {
        cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
      }

      List<Map<String, dynamic>> items = [];
      if (itemsData is String && itemsData.isNotEmpty) {
        items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
      } else if (itemsData is List) {
        items = List<Map<String, dynamic>>.from(itemsData);
      }

      // Parsear resultados
      Map<String, Map<String, Map<int, String?>>> resultados = {};
      for (var item in items) {
        final itemProceso = item['proceso']?.toString() ?? '';
        
        if (item['resultadosPorCuadranteParada'] != null) {
          final resultadosPorCuadranteParada = item['resultadosPorCuadranteParada'];
          if (resultadosPorCuadranteParada is Map<String, dynamic>) {
            resultadosPorCuadranteParada.forEach((cuadrante, paradas) {
              if (!resultados.containsKey(cuadrante)) {
                resultados[cuadrante] = {};
              }
              if (paradas is Map<String, dynamic>) {
                Map<int, String?> paradasMap = {};
                paradas.forEach((parada, resultado) {
                  final paradaNum = int.tryParse(parada) ?? 0;
                  paradasMap[paradaNum] = resultado?.toString();
                });
                resultados[cuadrante]![itemProceso] = paradasMap;
              }
            });
          }
        }
      }

      return await generateDetailed(
        record: record,
        cuadrantes: cuadrantes,
        items: items,
        resultados: resultados,
      );
    } catch (e) {
      print('Error generando PDF de labores temporales: $e');
      rethrow;
    }
  }

  static Future<Uint8List> generateDetailed({
    required Map<String, dynamic> record,
    required List<Map<String, dynamic>> cuadrantes,
    required List<Map<String, dynamic>> items,
    required Map<String, Map<String, Map<int, String?>>> resultados,
  }) async {
    final doc = pw.Document();
    
    // Cargar imagen del banner
    pw.MemoryImage? bannerImage;
    try {
      final ByteData bannerData = await rootBundle.load('assets/images/Tessa_banner.png');
      bannerImage = pw.MemoryImage(bannerData.buffer.asUint8List());
    } catch (e) {
      print('Error cargando banner: $e');
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            _buildHeader(record, bannerImage),
            pw.SizedBox(height: 20),
            _buildInformacionGeneral(record),
            pw.SizedBox(height: 20),
            _buildResumenCumplimiento(record, cuadrantes, items, resultados),
            pw.SizedBox(height: 20),
            _buildTablaResultados(record, cuadrantes, items, resultados),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(Map<String, dynamic> record, pw.MemoryImage? bannerImage) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: COLOR_NEGRO,
      ),
      child: pw.Row(
        children: [
          if (bannerImage != null) ...[
            pw.Image(bannerImage, width: 80, height: 40),
            pw.SizedBox(width: 20),
          ],
          pw.Expanded(
            child: pw.Text(
              'LABORES TEMPORALES - REPORTE DETALLADO',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: COLOR_BLANCO,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInformacionGeneral(Map<String, dynamic> record) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_CLARO,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMACIÓN GENERAL',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: COLOR_NEGRO,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Finca:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(record['finca_nombre'] ?? 'N/A'),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Kontroller:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(record['usuario_nombre'] ?? 'N/A'),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Fecha:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(_formatDate(record['fecha_creacion'])),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Supervisor:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text(record['supervisor'] ?? 'N/A'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildResumenCumplimiento(
    Map<String, dynamic> record,
    List<Map<String, dynamic>> cuadrantes,
    List<Map<String, dynamic>> items,
    Map<String, Map<String, Map<int, String?>>> resultados,
  ) {
    final promedio = _calcularPorcentajePromedio(cuadrantes, resultados, items.length);
    
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_CLARO,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'RESUMEN DE CUMPLIMIENTO',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: COLOR_NEGRO,
            ),
          ),
          pw.Row(
            children: [
              pw.Text(
                'Bloques evaluados: ${cuadrantes.length}',
                style: pw.TextStyle(fontSize: 12, color: COLOR_GRIS_OSCURO),
              ),
              pw.SizedBox(width: 20),
              pw.Text(
                'Promedio: ${promedio.toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: COLOR_NEGRO,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTablaResultados(
    Map<String, dynamic> record,
    List<Map<String, dynamic>> cuadrantes,
    List<Map<String, dynamic>> items,
    Map<String, Map<String, Map<int, String?>>> resultados,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESULTADOS POR BLOQUES',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: COLOR_NEGRO,
            ),
          ),
          pw.SizedBox(height: 15),
          ...cuadrantes.map((cuadrante) => _buildBloqueSection(record, cuadrante, items, resultados)),
        ],
      ),
    );
  }

  static pw.Widget _buildBloqueSection(
    Map<String, dynamic> record,
    Map<String, dynamic> cuadrante,
    List<Map<String, dynamic>> items,
    Map<String, Map<String, Map<int, String?>>> resultados,
  ) {
    final cuadranteId = cuadrante['cuadrante']?.toString() ?? 'N/A';
    final bloque = cuadrante['bloque'] ?? 'N/A';
    final variedad = cuadrante['variedad'] ?? 'N/A';
    final supervisor = cuadrante['supervisor'] ?? record['supervisor'] ?? 'N/A';
    
    // Construir el key correcto para buscar en resultados
    final resultadoKey = '${supervisor}_${bloque}_${cuadranteId}';
    final porcentaje = _calcularPorcentajeBloque(resultadoKey, resultados, items.length);

    // Obtener fotos del cuadrante
    final fotos = _getFotosFromCuadrante(cuadrante);

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 15),
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_CLARO,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Bloque: $bloque',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: COLOR_NEGRO,
                ),
              ),
              pw.Text(
                'Cumplimiento: ${porcentaje.toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: COLOR_GRIS_OSCURO,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text('Cuadrante: $cuadranteId', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 20),
              pw.Text('Variedad: $variedad', style: pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 20),
              pw.Text('Supervisor: $supervisor', style: pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 10),
          _buildParadasTable(resultadoKey, items, resultados),
          if (fotos.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _buildFotosSection(fotos, items),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildParadasTable(
    String resultadoKey,
    List<Map<String, dynamic>> items,
    Map<String, Map<String, Map<int, String?>>> resultados,
  ) {
    if (!resultados.containsKey(resultadoKey)) {
      return pw.Text('Sin datos disponibles');
    }

    final cuadranteResultados = resultados[resultadoKey]!;
    
    return pw.Table(
      border: pw.TableBorder.all(color: COLOR_NEGRO, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(2.5), // Item
        for (int i = 1; i <= 5; i++) i: pw.FlexColumnWidth(0.8), // P1-P5
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: COLOR_GRIS_CLARO),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text(
                'Item',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
            ),
            for (int i = 1; i <= 5; i++)
              pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Text(
                  'P$i',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
          ],
        ),
        // Data rows
        ...items.map((item) {
          final itemProceso = item['proceso']?.toString() ?? '';
          final paradas = cuadranteResultados[itemProceso] ?? {};
          
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Text(
                  itemProceso,
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
              for (int i = 1; i <= 5; i++)
                pw.Container(
                  height: 16,
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: _getResultadoColor(paradas[i]),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      _getResultadoTexto(paradas[i]),
                      style: pw.TextStyle(
                        color: COLOR_BLANCO,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      ],
    );
  }

  static double _calcularPorcentajePromedio(
    List<Map<String, dynamic>> cuadrantes,
    Map<String, Map<String, Map<int, String?>>> resultados,
    int itemsCount,
  ) {
    if (cuadrantes.isEmpty) return 0.0;
    
    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;
    
    for (var cuadrante in cuadrantes) {
      final cuadranteId = cuadrante['cuadrante']?.toString() ?? '';
      final bloque = cuadrante['bloque']?.toString() ?? '';
      final supervisor = cuadrante['supervisor']?.toString() ?? '';
      if (cuadranteId.isEmpty || bloque.isEmpty) continue;
      
      // Construir el key correcto para buscar en resultados
      final resultadoKey = '${supervisor}_${bloque}_${cuadranteId}';
      
      // Calcular porcentaje usando la misma lógica que la pantalla de detalles
      // totalSlots = numItems * 5; conformes = no marcados
      final porcentaje = _calcularPorcentajeBloque(resultadoKey, resultados, itemsCount);
      sumaPorcentajes += porcentaje;
      cuadrantesConDatos++;
    }
    
    return cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
  }

  static double _calcularPorcentajeBloque(String resultadoKey, Map<String, Map<String, Map<int, String?>>> resultados, int itemsCount) {
    if (!resultados.containsKey(resultadoKey)) return 0.0;
    
    final cuadranteResultados = resultados[resultadoKey]!;
    
    // Misma lógica que la pantalla de detalles: 100% cuando nada marcado
    int marcados = 0;
    const int paradas = 5;
    final int totalSlots = (itemsCount > 0 ? itemsCount : cuadranteResultados.keys.length) * paradas;
    
    for (final entry in cuadranteResultados.entries) {
      final mapaParadas = entry.value;
      for (int p = 1; p <= paradas; p++) {
        final v = mapaParadas[p];
        if (v != null && v.toString().isNotEmpty) {
          marcados++;
        }
      }
    }
    
    if (totalSlots > 0) {
      final int noMarcados = totalSlots - marcados; // conformes = no marcados
      return (noMarcados / totalSlots) * 100;
    }
    
    return 0.0;
  }

  static PdfColor _getResultadoColor(String? resultado) {
    if (resultado == null || resultado.isEmpty) return COLOR_GRIS_CLARO;
    if (resultado == '1') return PdfColors.green;
    if (resultado == '0') return PdfColors.red;
    return PdfColors.orange;
  }

  static String _getResultadoTexto(String? resultado) {
    if (resultado == null || resultado.isEmpty) return '';
    if (resultado == '1') return 'X';
    if (resultado == '0') return 'NC';
    return resultado.toUpperCase();
  }

  static List<Map<String, dynamic>> _getFotosFromCuadrante(Map<String, dynamic> cuadrante) {
    List<Map<String, dynamic>> fotos = [];
    
    // Intentar obtener fotos del array 'fotos'
    if (cuadrante['fotos'] is List) {
      fotos = List<Map<String, dynamic>>.from(cuadrante['fotos']);
    } else if (cuadrante['fotos'] is String && (cuadrante['fotos'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(cuadrante['fotos'] as String);
        if (decoded is List) {
          fotos = List<Map<String, dynamic>>.from(decoded);
        }
      } catch (e) {
        print('Error decodificando fotos: $e');
      }
    }
    
    // Si no hay fotos en el array, usar fotoBase64 principal si existe
    if (fotos.isEmpty && cuadrante['fotoBase64'] != null && (cuadrante['fotoBase64'] as String).isNotEmpty) {
      fotos.add({
        'base64': cuadrante['fotoBase64'],
        'etiqueta': null,
      });
    }
    
    return fotos;
  }

  static pw.Widget _buildFotosSection(List<Map<String, dynamic>> fotos, List<Map<String, dynamic>> items) {
    if (fotos.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FOTOS ADJUNTAS (${fotos.length})',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: COLOR_NEGRO,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fotos.map((foto) => _buildFotoWidget(foto, items)).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildFotoWidget(Map<String, dynamic> foto, List<Map<String, dynamic>> items) {
    final base64Image = foto['base64']?.toString();
    final etiqueta = foto['etiqueta']?.toString();
    
    if (base64Image == null || base64Image.isEmpty) {
      return pw.Container(
        width: 60,
        height: 60,
        decoration: pw.BoxDecoration(
          color: COLOR_GRIS_CLARO,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: COLOR_NEGRO, width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text(
            'Sin imagen',
            style: pw.TextStyle(fontSize: 8, color: COLOR_GRIS_OSCURO),
          ),
        ),
      );
    }

    try {
      final bytes = base64Decode(base64Image);
      final image = pw.MemoryImage(bytes);
      
      String etiquetaText = '';
      if (etiqueta != null && etiqueta.isNotEmpty) {
        final int? id = int.tryParse(etiqueta);
        if (id != null) {
          try {
            final found = items.firstWhere((it) => (it['id']?.toString() ?? '') == id.toString(), orElse: () => {});
            etiquetaText = found['proceso']?.toString() ?? '';
          } catch (_) {}
        }
      }

      return pw.Container(
        width: 90,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: COLOR_NEGRO, width: 0.5),
        ),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.ClipRRect(
              child: pw.Image(image, width: 90, height: 90, fit: pw.BoxFit.cover),
            ),
            if (etiquetaText.isNotEmpty)
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                color: COLOR_NEGRO,
                child: pw.Text(
                  etiquetaText,
                  style: pw.TextStyle(
                    color: COLOR_BLANCO,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      print('Error procesando imagen: $e');
      return pw.Container(
        width: 60,
        height: 60,
        decoration: pw.BoxDecoration(
          color: PdfColors.red100,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.red, width: 0.5),
        ),
        child: pw.Center(
          child: pw.Text(
            'Error',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.red),
          ),
        ),
      );
    }
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}