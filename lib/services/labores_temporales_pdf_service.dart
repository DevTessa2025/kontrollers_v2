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
            _buildResumenCumplimiento(record, cuadrantes, resultados),
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
    Map<String, Map<String, Map<int, String?>>> resultados,
  ) {
    final promedio = _calcularPorcentajePromedio(cuadrantes, resultados);
    
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
    final resultadoKey = 'test_${bloque}_${cuadranteId}';
    final porcentaje = _calcularPorcentajeBloque(resultadoKey, resultados);

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
  ) {
    if (cuadrantes.isEmpty) return 0.0;
    
    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;
    
    for (var cuadrante in cuadrantes) {
      final cuadranteId = cuadrante['cuadrante']?.toString() ?? '';
      final bloque = cuadrante['bloque']?.toString() ?? '';
      if (cuadranteId.isEmpty || bloque.isEmpty) continue;
      
      // Construir el key correcto
      final resultadoKey = 'test_${bloque}_${cuadranteId}';
      
      // Buscar el item "Labores temporales conforme"
      String? itemLaboresConforme;
      for (var item in resultados[resultadoKey]?.keys ?? {}) {
        final itemStr = item?.toString() ?? '';
        if (itemStr.toLowerCase().contains('labores temporales conforme')) {
          itemLaboresConforme = itemStr;
          break;
        }
      }
      
      if (itemLaboresConforme != null && resultados.containsKey(resultadoKey)) {
        final cuadranteResultados = resultados[resultadoKey]!;
        if (cuadranteResultados.containsKey(itemLaboresConforme)) {
          final paradas = cuadranteResultados[itemLaboresConforme]!;
          int totalParadas = 0;
          int paradasConformes = 0;
          
          for (int i = 1; i <= 5; i++) {
            final resultado = paradas[i];
            if (resultado != null && resultado.isNotEmpty) {
              totalParadas++;
              if (resultado == '1') {
                paradasConformes++;
              }
            }
          }
          
          if (totalParadas > 0) {
            final porcentaje = (paradasConformes / 5) * 100;
            sumaPorcentajes += porcentaje;
            cuadrantesConDatos++;
          }
        }
      }
    }
    
    return cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
  }

  static double _calcularPorcentajeBloque(String resultadoKey, Map<String, Map<String, Map<int, String?>>> resultados) {
    if (!resultados.containsKey(resultadoKey)) return 0.0;
    
    final cuadranteResultados = resultados[resultadoKey]!;
    
    // Buscar el item "Labores temporales conforme"
    String? itemLaboresConforme;
    for (var item in cuadranteResultados.keys) {
      if (item.toLowerCase().contains('labores temporales conforme')) {
        itemLaboresConforme = item;
        break;
      }
    }
    
    if (itemLaboresConforme != null && cuadranteResultados.containsKey(itemLaboresConforme)) {
      final paradas = cuadranteResultados[itemLaboresConforme]!;
      int totalParadas = 0;
      int paradasConformes = 0;
      
      for (int i = 1; i <= 5; i++) {
        final resultado = paradas[i];
        if (resultado != null && resultado.isNotEmpty) {
          totalParadas++;
          if (resultado == '1') {
            paradasConformes++;
          }
        }
      }
      
      if (totalParadas > 0) {
        return (paradasConformes / 5) * 100;
      }
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