import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;

class CortesPdfService {
  // Colores de la paleta
  static const PdfColor COLOR_NEGRO = PdfColors.black;
  static const PdfColor COLOR_GRIS_OSCURO = PdfColor.fromInt(0xFF424242);
  static const PdfColor COLOR_GRIS_MEDIO = PdfColor.fromInt(0xFF757575);
  static const PdfColor COLOR_GRIS_CLARO = PdfColor.fromInt(0xFFBDBDBD);
  static const PdfColor COLOR_GRIS_MUY_CLARO = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor COLOR_ROJO_PRINCIPAL = PdfColor.fromInt(0xFFD32F2F);
  static const PdfColor COLOR_ROJO_CLARO = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor COLOR_RESPUESTA_SI = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor COLOR_RESPUESTA_NO = PdfColor.fromInt(0xFFD32F2F);
  static const PdfColor COLOR_RESPUESTA_NA = PdfColor.fromInt(0xFFFF8F00);

  // Método para compatibilidad con share_dialog_widget.dart
  static Future<Uint8List> generate({required Map<String, dynamic> data}) async {
    // Parsear los datos del record
    final record = data;
    
    List<Map<String, dynamic>> cuadrantes = [];
    List<Map<String, dynamic>> items = [];
    Map<String, Map<String, Map<int, String?>>> resultados = {};
    
    // Parsear cuadrantes
    if (data['cuadrantes_json'] != null) {
      final cuadrantesData = data['cuadrantes_json'];
      if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
        cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
      } else if (cuadrantesData is List) {
        cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
      }
    }
    
    // Parsear items
    if (data['items_json'] != null) {
      final itemsData = data['items_json'];
      if (itemsData is String && itemsData.isNotEmpty) {
        items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
      } else if (itemsData is List) {
        items = List<Map<String, dynamic>>.from(itemsData);
      }
    }
    
    // Parsear resultados
    for (var item in items) {
      final itemProceso = item['proceso']?.toString() ?? '';
      
      if (item['resultadosPorCuadrante'] != null) {
        final resultadosPorCuadrante = item['resultadosPorCuadrante'];
        if (resultadosPorCuadrante is Map<String, dynamic>) {
          resultadosPorCuadrante.forEach((cuadrante, muestras) {
            if (!resultados.containsKey(cuadrante)) {
              resultados[cuadrante] = {};
            }
            if (muestras is Map<String, dynamic>) {
              Map<int, String?> muestrasMap = {};
              muestras.forEach((muestra, resultado) {
                final muestraNum = int.tryParse(muestra) ?? 0;
                muestrasMap[muestraNum] = resultado?.toString();
              });
              resultados[cuadrante]![itemProceso] = muestrasMap;
            }
          });
        }
      }
    }
    
    return generateDetailed(
      record: record,
      cuadrantes: cuadrantes,
      items: items,
      resultados: resultados,
    );
  }

  // Método detallado para uso interno
  static Future<Uint8List> generateDetailed({
    required Map<String, dynamic> record,
    required List<Map<String, dynamic>> cuadrantes,
    required List<Map<String, dynamic>> items,
    required Map<String, Map<String, Map<int, String?>>> resultados,
  }) async {
    final pdf = pw.Document();
    
    // Cargar banner
    pw.MemoryImage? bannerImage;
    final List<String> rutasPosibles = [
      'assets/images/Tessa_banner.png',
      'assets/images/tessa_banner.png',
      'assets/Tessa_banner.png',
      'images/Tessa_banner.png',
    ];
    for (final ruta in rutasPosibles) {
      try {
        final ByteData dataBytes = await rootBundle.load(ruta);
        bannerImage = pw.MemoryImage(dataBytes.buffer.asUint8List());
        print('[PDF][CORTES] Banner cargado desde: $ruta');
        break;
      } catch (_) {}
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (context) => [
          _buildHeader(record, bannerImage),
          pw.SizedBox(height: 20),
          _buildInformacionGeneral(record),
          pw.SizedBox(height: 20),
          _buildResumenCumplimiento(record, cuadrantes, resultados),
          pw.SizedBox(height: 20),
          _buildTablaResultados(record, cuadrantes, items, resultados),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Map<String, dynamic> record, pw.MemoryImage? bannerImage) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: pw.BoxDecoration(
        color: COLOR_NEGRO,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo de la empresa (izquierda)
          if (bannerImage != null)
            pw.Container(
              height: 60,
              child: pw.Image(bannerImage),
            )
          else
            pw.SizedBox(width: 0),
          // Título (derecha)
          pw.Text(
            'REPORTE DE CORTES DEL DÍA',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
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
        border: pw.Border.all(color: COLOR_NEGRO),
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
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: COLOR_NEGRO, width: 0.5),
            columnWidths: {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Finca:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: COLOR_NEGRO,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      record['finca_nombre'] ?? 'N/A',
                      style: pw.TextStyle(fontSize: 11, color: COLOR_GRIS_OSCURO),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Kontroller:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: COLOR_NEGRO,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      record['usuario_nombre'] ?? 'N/A',
                      style: pw.TextStyle(fontSize: 11, color: COLOR_GRIS_OSCURO),
                    ),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Fecha:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: COLOR_NEGRO,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      _formatDate(record['fecha_creacion']),
                      style: pw.TextStyle(fontSize: 11, color: COLOR_GRIS_OSCURO),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Supervisor:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: COLOR_NEGRO,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text(
                      record['supervisor'] ?? 'N/A',
                      style: pw.TextStyle(fontSize: 11, color: COLOR_GRIS_OSCURO),
                    ),
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
    // Calcular estadísticas
    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;
    
    for (var cuadrante in cuadrantes) {
      final cuadranteId = cuadrante['cuadrante']?.toString() ?? '';
      
      int totalMuestras = 0;
      int muestrasConCorteConforme = 0;
      
      if (resultados.containsKey(cuadranteId)) {
        resultados[cuadranteId]!.forEach((item, muestras) {
          if (item.toLowerCase().contains('corte conforme')) {
            muestras.forEach((muestra, resultado) {
              if (resultado != null && resultado.isNotEmpty) {
                totalMuestras++;
                if (resultado.toLowerCase() == 'c' || resultado == '1') {
                  muestrasConCorteConforme++;
                }
              }
            });
          }
        });
      }
      
      if (totalMuestras > 0) {
        final porcentajeCuadrante = (muestrasConCorteConforme / 10 * 100);
        sumaPorcentajes += porcentajeCuadrante;
        cuadrantesConDatos++;
      }
    }
    
    final promedio = cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;

    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_NEGRO),
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
                style: pw.TextStyle(
                  fontSize: 12,
                  color: COLOR_GRIS_OSCURO,
                ),
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
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_NEGRO),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESULTADOS POR BLOQUE',
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
    final cuadranteId = cuadrante['cuadrante']?.toString() ?? '';
    final bloque = cuadrante['bloque'] ?? 'N/A';
    final variedad = cuadrante['variedad'] ?? 'N/A';
    final supervisor = cuadrante['supervisor'] ?? record['supervisor'] ?? 'N/A';

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 15),
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_MUY_CLARO,
        border: pw.Border.all(color: COLOR_NEGRO),
        borderRadius: pw.BorderRadius.circular(5),
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
                'Cuadrante: $cuadranteId',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: COLOR_GRIS_OSCURO,
                ),
              ),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Variedad: $variedad',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: COLOR_GRIS_OSCURO,
                ),
              ),
              pw.Text(
                'Supervisor: $supervisor',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: COLOR_GRIS_OSCURO,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Cumplimiento: ${_calcularPorcentajeBloque(cuadranteId, resultados).toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: COLOR_NEGRO,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _buildMuestrasTable(cuadranteId, items, resultados),
        ],
      ),
    );
  }

  static pw.Widget _buildMuestrasTable(
    String cuadranteId,
    List<Map<String, dynamic>> items,
    Map<String, Map<String, Map<int, String?>>> resultados,
  ) {
    if (!resultados.containsKey(cuadranteId)) {
      return pw.Text('Sin datos disponibles');
    }

    final cuadranteResultados = resultados[cuadranteId]!;
    
    // Crear tabla compacta
    return pw.Table(
      border: pw.TableBorder.all(color: COLOR_NEGRO, width: 0.5),
      columnWidths: {
        0: pw.FlexColumnWidth(2.5), // Item
        1: pw.FlexColumnWidth(0.8), // M1
        2: pw.FlexColumnWidth(0.8), // M2
        3: pw.FlexColumnWidth(0.8), // M3
        4: pw.FlexColumnWidth(0.8), // M4
        5: pw.FlexColumnWidth(0.8), // M5
        6: pw.FlexColumnWidth(0.8), // M6
        7: pw.FlexColumnWidth(0.8), // M7
        8: pw.FlexColumnWidth(0.8), // M8
        9: pw.FlexColumnWidth(0.8), // M9
        10: pw.FlexColumnWidth(0.8), // M10
      },
      children: [
        // Encabezados
        pw.TableRow(
          decoration: pw.BoxDecoration(color: COLOR_GRIS_CLARO),
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text(
                'Item',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: COLOR_NEGRO,
                ),
              ),
            ),
            for (int i = 1; i <= 10; i++)
              pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                child: pw.Text(
                  'M$i',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: COLOR_NEGRO,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
          ],
        ),
        // Filas de datos
        ...items.map((item) {
          final itemProceso = item['proceso']?.toString() ?? '';
          
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: pw.Text(
                  itemProceso,
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
              for (int i = 1; i <= 10; i++)
                pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                  child: pw.Container(
                    height: 16,
                    decoration: pw.BoxDecoration(
                      color: _getResultadoColor(cuadranteResultados[itemProceso]?[i]),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        _getResultadoTexto(cuadranteResultados[itemProceso]?[i]),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
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

  static PdfColor _getResultadoColor(String? resultado) {
    if (resultado == null || resultado.isEmpty) return COLOR_GRIS_CLARO;
    if (resultado.toLowerCase() == 'c' || resultado == '1') return COLOR_RESPUESTA_SI;
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return COLOR_RESPUESTA_NO;
    return COLOR_RESPUESTA_NA;
  }

  static String _getResultadoTexto(String? resultado) {
    if (resultado == null || resultado.isEmpty) return '';
    if (resultado.toLowerCase() == 'c' || resultado == '1') return 'X';
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return 'NC';
    return resultado.toUpperCase();
  }

  static double _calcularPorcentajeBloque(String cuadranteId, Map<String, Map<String, Map<int, String?>>> resultados) {
    if (!resultados.containsKey(cuadranteId)) return 0.0;
    
    final cuadranteResultados = resultados[cuadranteId]!;
    
    // Buscar el item "Corte conforme"
    String? itemCorteConforme;
    for (final itemProceso in cuadranteResultados.keys) {
      if (itemProceso.toLowerCase().contains('corte conforme')) {
        itemCorteConforme = itemProceso;
        break;
      }
    }
    
    if (itemCorteConforme == null || !cuadranteResultados.containsKey(itemCorteConforme)) {
      return 0.0;
    }
    
    final muestrasCorteConforme = cuadranteResultados[itemCorteConforme]!;
    int totalMuestras = 0;
    int muestrasConformes = 0;
    
    for (int i = 1; i <= 10; i++) {
      final resultado = muestrasCorteConforme[i];
      if (resultado != null && resultado.isNotEmpty) {
        totalMuestras++;
        if (resultado.toLowerCase() == 'c' || resultado == '1') {
          muestrasConformes++;
        }
      }
    }
    
    if (totalMuestras == 0) return 0.0;
    return (muestrasConformes / 10) * 100;
  }


  static String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (e) {
      return 'N/A';
    }
  }
}