import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:image/image.dart' as img;

class FertirriegoPDFService {
  static const int _MAX_TOTAL_PAGES = 40;

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

  // Items específicos para fertirriego
  static const List<int> ITEMS_FERTIRRIEGO = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25];

  static Future<Uint8List> generate({
    required Map<String, dynamic> data,
    bool obtenerDatosFrescos = false,
  }) async {
    print('[PDF][FERTIRRIEGO] Generando PDF para fertirriego ID=${data['id']} finca=${data['finca_nombre']}');
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
        print('[PDF][FERTIRRIEGO] Banner cargado desde: $ruta');
        break;
      } catch (_) {}
    }

    // Obtener items relevantes para fertirriego
    final List<Map<String, dynamic>> itemsRelevantes = _extraerItemsRelevantesFertirriego(data);

    // Página principal
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: _MAX_TOTAL_PAGES,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _construirHeader(data, bannerImage),
        footer: (context) => _construirFooter(context),
        build: (context) {
          final List<pw.Widget> widgets = [];

          // Información general
          widgets.add(_construirInformacionGeneral(data));
          widgets.add(pw.SizedBox(height: 20));

          // Resumen de cumplimiento
          widgets.add(_construirResumenCumplimiento(data));
          widgets.add(pw.SizedBox(height: 20));

          // Items relevantes (ahora incluyen sus imágenes)
          if (itemsRelevantes.isNotEmpty) {
            widgets.add(_construirSeccionItemsRelevantes(itemsRelevantes));
          }

          return widgets;
        },
      ),
    );

    // Las imágenes ahora se muestran junto a cada item, no en páginas separadas

    print('[PDF][FERTIRRIEGO] PDF generado exitosamente');
    return pdf.save();
  }

  static pw.Widget _construirHeader(Map<String, dynamic> data, pw.MemoryImage? banner) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: COLOR_NEGRO, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            if (banner != null) ...[
              pw.Container(width: 120, height: 36, child: pw.Image(banner, fit: pw.BoxFit.contain)),
              pw.SizedBox(width: 10),
            ],
            pw.Text('SISTEMA KONTROLLERS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16)),
          ]),
          pw.Text('FERTIRRIEGO', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  static pw.Widget _construirFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
    );
  }

  static pw.Widget _construirInformacionGeneral(Map<String, dynamic> data) {
    // Debug: verificar qué datos están llegando
    print('[PDF][FERTIRRIEGO] Datos recibidos para información general:');
    print('[PDF][FERTIRRIEGO] finca_nombre: ${data['finca_nombre']}');
    print('[PDF][FERTIRRIEGO] bloque_nombre: ${data['bloque_nombre']}');
    print('[PDF][FERTIRRIEGO] variedad_nombre: ${data['variedad_nombre']}');
    print('[PDF][FERTIRRIEGO] usuario_nombre: ${data['usuario_nombre']}');
    print('[PDF][FERTIRRIEGO] Todos los campos disponibles: ${data.keys.where((k) => k.contains('variedad') || k.contains('bloque') || k.contains('finca')).toList()}');
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_MEDIO, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('INFORMACIÓN GENERAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
          pw.SizedBox(height: 2),
          pw.Container(height: 2, width: 60, color: COLOR_ROJO_PRINCIPAL),
          pw.SizedBox(height: 12),
          _construirFila('Finca', data['finca_nombre'] ?? 'N/A'),
          _construirFila('Bloque', data['bloque_nombre'] ?? 'N/A'),
          _construirFila('Usuario', data['usuario_nombre'] ?? 'N/A'),
          _construirFila('Fecha', _formatearFecha(data['fecha_creacion'])),
        ],
      ),
    );
  }

  static pw.Widget _construirResumenCumplimiento(Map<String, dynamic> data) {
    // Usar el porcentaje que ya está calculado en la base de datos
    final porcentaje = data['porcentaje_cumplimiento']?.toDouble() ?? 0.0;
    final porcentajeRedondeado = porcentaje.round();
    
    print('[PDF][FERTIRRIEGO] Usando porcentaje de la base de datos: $porcentaje%');

    // Calcular conformes y no conformes para mostrar en el resumen
    int totalItems = 0;
    int conformes = 0;
    int noConformes = 0;
    
    for (int i in ITEMS_FERTIRRIEGO) {
      final respuesta = data['item_${i}_respuesta']?.toString();
      if (respuesta != null && respuesta.isNotEmpty && respuesta.toLowerCase() != 'n/a') {
        totalItems++;
        if (respuesta.toLowerCase() == 'sí' || respuesta.toLowerCase() == 'si') {
          conformes++;
        } else if (respuesta.toLowerCase() == 'no') {
          noConformes++;
        }
      }
    }
    
    print('[PDF][FERTIRRIEGO] Total items: $totalItems, Conformes: $conformes, No conformes: $noConformes, Porcentaje: $porcentajeRedondeado%');

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_MEDIO, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PORCENTAJE DE CUMPLIMIENTO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
          pw.SizedBox(height: 2),
          pw.Container(height: 2, width: 60, color: COLOR_ROJO_PRINCIPAL),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _buildGraficoCircular(porcentajeRedondeado, porcentajeRedondeado >= 80 ? COLOR_RESPUESTA_SI : porcentajeRedondeado >= 60 ? COLOR_RESPUESTA_NA : COLOR_RESPUESTA_NO),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Total Items: $totalItems', style: const pw.TextStyle(fontSize: 14)),
                  pw.Text('Conformes: $conformes', style: pw.TextStyle(fontSize: 14, color: COLOR_RESPUESTA_SI)),
                  pw.Text('No Conformes: $noConformes', style: pw.TextStyle(fontSize: 14, color: COLOR_RESPUESTA_NO)),
                  pw.SizedBox(height: 6),
                  pw.Text('$porcentajeRedondeado% de cumplimiento', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: porcentajeRedondeado >= 80 ? COLOR_RESPUESTA_SI : porcentajeRedondeado >= 60 ? COLOR_RESPUESTA_NA : COLOR_RESPUESTA_NO)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildGraficoCircular(int porcentaje, PdfColor color) {
    final pct = porcentaje.clamp(0, 100) / 100.0;
    return pw.Container(
      width: 72,
      height: 72,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.CustomPaint(
            size: const PdfPoint(72, 72),
            painter: (PdfGraphics canvas, PdfPoint size) {
              final double w = size.x;
              final double h = size.y;
              final double cx = w / 2;
              final double cy = h / 2;
              final double outerR = (w < h ? w : h) / 2;
              final double innerR = outerR - 6;
              final int totalTicks = 40;
              final int filled = (pct * totalTicks).round();

              for (int i = 0; i < totalTicks; i++) {
                final double ang = -math.pi / 2 + (2 * math.pi) * (i / totalTicks);
                final double x1 = cx + innerR * math.cos(ang);
                final double y1 = cy + innerR * math.sin(ang);
                final double x2 = cx + outerR * math.cos(ang);
                final double y2 = cy + outerR * math.sin(ang);
                canvas
                  ..setStrokeColor(i < filled ? color : COLOR_GRIS_CLARO)
                  ..setLineWidth(3)
                  ..setLineCap(PdfLineCap.round)
                  ..drawLine(x1, y1, x2, y2)
                  ..strokePath();
              }
            },
          ),
          pw.Text('$porcentaje%', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
        ],
      ),
    );
  }

  static pw.Widget _construirSeccionItemsRelevantes(List<Map<String, dynamic>> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_MEDIO, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ITEMS RELEVANTES', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
          pw.SizedBox(height: 2),
          pw.Container(height: 2, width: 60, color: COLOR_ROJO_PRINCIPAL),
          pw.SizedBox(height: 12),
          ...items.map((item) => _construirItemRelevante(item)).toList(),
        ],
      ),
    );
  }

  static pw.Widget _construirItemRelevante(Map<String, dynamic> item) {
    // Obtener la descripción del item basada en el número
    String descripcionItem = _obtenerDescripcionItemFertirriego(item['numero']);
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_CLARO),
        borderRadius: pw.BorderRadius.circular(6),
        color: COLOR_GRIS_MUY_CLARO,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Item ${item['numero']}: $descripcionItem', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
          if (item['respuesta'] != null && item['respuesta'].toString().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Respuesta: ${item['respuesta']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: COLOR_GRIS_OSCURO)),
          ],
          if ((item['observaciones'] ?? '').toString().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Observaciones: ${item['observaciones']}', style: const pw.TextStyle(fontSize: 12)),
          ],
          // Mostrar la imagen directamente aquí si existe
          if (item['tiene_foto'] == true && item['foto_base64'] != null && item['foto_base64'].toString().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Fotografía adjunta:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: COLOR_RESPUESTA_SI)),
            pw.SizedBox(height: 4),
            _construirImagenItem(item['foto_base64']),
          ],
        ],
      ),
    );
  }



  static pw.Widget _construirFila(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.SizedBox(width: 150, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text(value)),
      ]),
    );
  }

  static List<Map<String, dynamic>> _extraerItemsRelevantesFertirriego(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> relevantes = [];
    
    print('[PDF][FERTIRRIEGO] Extrayendo items relevantes...');
    print('[PDF][FERTIRRIEGO] Items a verificar: $ITEMS_FERTIRRIEGO');
    
    for (int i in ITEMS_FERTIRRIEGO) {
      String? respuesta = data['item_${i}_respuesta'];
      int? valorNumerico = data['item_${i}_valor_numerico'];
      String? observaciones = data['item_${i}_observaciones'];
      String? fotoBase64 = data['item_${i}_foto_base64'];
      
      print('[PDF][FERTIRRIEGO] Item $i: respuesta=$respuesta, obs=${observaciones?.isNotEmpty == true ? "SÍ" : "NO"}, foto=${fotoBase64?.isNotEmpty == true ? "SÍ" : "NO"}');
      
      // Solo incluir si:
      // 1. Tiene observaciones no vacías
      // 2. Tiene foto
      // 3. La respuesta es "NO"
      bool tieneObservaciones = observaciones != null && observaciones.trim().isNotEmpty;
      bool tieneFoto = fotoBase64 != null && fotoBase64.isNotEmpty;
      bool esRespuestaNo = respuesta != null && respuesta.toLowerCase() == 'no';
      
      if (tieneObservaciones || tieneFoto || esRespuestaNo) {
        relevantes.add({
          'numero': i,
          'respuesta': respuesta,
          'valor_numerico': valorNumerico,
          'observaciones': observaciones,
          'foto_base64': fotoBase64,
          'tiene_foto': tieneFoto,
        });
        
        print('[PDF][FERTIRRIEGO] ✅ Item $i incluido: respuesta=$respuesta, obs=${tieneObservaciones ? "SÍ" : "NO"}, foto=${tieneFoto ? "SÍ" : "NO"}');
      }
    }
    
    print('[PDF][FERTIRRIEGO] Total items relevantes encontrados: ${relevantes.length}');
    return relevantes;
  }

  static Uint8List _optimizarImagen(String b64) {
    try {
      final cleaned = b64.replaceAll(RegExp(r"\s+"), '');
      final String b64Only = cleaned.startsWith('data:') ? cleaned.substring(cleaned.indexOf('base64,') + 7) : cleaned;
      final raw = base64Decode(b64Only);
      final img.Image? decoded = img.decodeImage(raw);
      if (decoded == null) return raw;
      final resized = img.copyResize(decoded, width: decoded.width >= decoded.height ? 1024 : null, height: decoded.height > decoded.width ? 1024 : null);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 65));
    } catch (e) {
      print('[PDF][FERTIRRIEGO] Error optimizando imagen: $e');
      try {
        final cleaned = b64.replaceAll(RegExp(r"\s+"), '');
        final String b64Only = cleaned.startsWith('data:') ? cleaned.substring(cleaned.indexOf('base64,') + 7) : cleaned;
        return base64Decode(b64Only);
      } catch (_) {
        return Uint8List(0);
      }
    }
  }

  static String _formatearFecha(dynamic fecha) {
    if (fecha == null) return 'N/A';
    try {
      final d = DateTime.parse(fecha.toString());
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(d);
    } catch (_) {
      return fecha.toString();
    }
  }

  static String _obtenerDescripcionItemFertirriego(int numeroItem) {
    // Mapeo de items de fertirriego con sus descripciones reales
    Map<int, String> descripcionesItems = {
      1: 'Fórmula de riego actualizada',
      2: 'Fórmula de riego-Caseta',
      3: 'Programación semanal- Caseta',
      4: 'Consumos de fertilizantes vs fórmula de riego (kg) - Caseta',
      5: 'Registro consumo de fertilizantes',
      6: 'Pesas en casetas',
      7: 'Parámetros del agua',
      8: 'Lavado de tanques y filtros',
      9: 'Llenado de tanques inicial',
      10: 'Orden de colocación productos fertilizantes',
      11: 'Preparación quelato de hierro + nitrato de calcio',
      13: 'Nivel de solución en el tanque',
      14: 'Descarga homogénea',
      15: 'Llenado de tanques final',
      16: 'Lámina total (L/m2)',
      17: 'Variables programadas',
      18: 'CE y pH premix',
      20: 'CE y pH goteros',
      21: 'Presión de las válvulas',
      22: 'Aforos en las mangueras',
      23: 'Líneas de goteo',
      24: 'Mangueras rotas',
      25: 'Mangueras incompletas',
    };
    
    return descripcionesItems[numeroItem] ?? 'Item de fertirriego $numeroItem';
  }

  static pw.Widget _construirImagenItem(String fotoBase64) {
    try {
      final Uint8List imageBytes = _optimizarImagen(fotoBase64);
      
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Image(
          pw.MemoryImage(imageBytes),
          width: 200,
          height: 150,
          fit: pw.BoxFit.contain,
        ),
      );
    } catch (e) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: COLOR_ROJO_PRINCIPAL, width: 1),
          borderRadius: pw.BorderRadius.circular(4),
          color: COLOR_ROJO_CLARO,
        ),
        child: pw.Text(
          'Error al cargar imagen',
          style: pw.TextStyle(
            fontSize: 10,
            color: COLOR_ROJO_PRINCIPAL,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }
  }
}
