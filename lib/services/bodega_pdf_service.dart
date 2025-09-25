import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:image/image.dart' as img;

class BodegaPDFService {
  static const int _MAX_TOTAL_PAGES = 40;
  static const int _IMAGES_PER_PAGE = 4;
  static const int _IMAGES_PER_DOC = 24;

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

  // Items específicos para bodega
  static const List<int> ITEMS_BODEGA = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  static Future<Uint8List> generate({
    required Map<String, dynamic> data,
    bool obtenerDatosFrescos = false,
  }) async {
    print('[PDF][BODEGA] Generando PDF para bodega ID=${data['id']} finca=${data['finca_nombre']}');
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
        print('[PDF][BODEGA] Banner cargado desde: $ruta');
        break;
      } catch (_) {}
    }

    // Obtener items relevantes para bodega
    final List<Map<String, dynamic>> itemsRelevantes = _extraerItemsRelevantesBodega(data);
    final List<Map<String, dynamic>> itemsConFotos = itemsRelevantes.where((item) => item['tiene_foto'] == true).toList();
    final List<String> limitedImages = itemsConFotos.map((item) => item['foto_base64'] as String).take(_IMAGES_PER_DOC).toList();

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

          // Items relevantes
          if (itemsRelevantes.isNotEmpty) {
            widgets.add(_construirSeccionItemsRelevantes(itemsRelevantes));
            widgets.add(pw.SizedBox(height: 20));
          }

          // Fotografías si hay
          if (limitedImages.isNotEmpty) {
            widgets.add(_construirSeccionFotografias(limitedImages));
          }

          return widgets;
        },
      ),
    );

    // Páginas adicionales para imágenes si es necesario
    if (limitedImages.length > _IMAGES_PER_PAGE) {
      for (int i = _IMAGES_PER_PAGE; i < limitedImages.length; i += _IMAGES_PER_PAGE) {
        final batch = limitedImages.sublist(i, (i + _IMAGES_PER_PAGE).clamp(0, limitedImages.length));
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (context) => [_construirGridImagenes(batch)],
          ),
        );
      }
    }

    print('[PDF][BODEGA] PDF generado exitosamente');
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
          pw.Text('BODEGA', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
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
          _construirFila('Variedad', data['variedad_nombre'] ?? 'N/A'),
          _construirFila('Usuario', data['usuario_nombre'] ?? 'N/A'),
          _construirFila('Fecha', _formatearFecha(data['fecha_creacion'])),
        ],
      ),
    );
  }

  static pw.Widget _construirResumenCumplimiento(Map<String, dynamic> data) {
    int totalItems = 0;
    int conformes = 0;
    int noConformes = 0;

    for (int i in ITEMS_BODEGA) {
      final respuesta = data['item_$i']?.toString().toUpperCase();
      if (respuesta != null && respuesta.isNotEmpty) {
        totalItems++;
        if (respuesta == 'SÍ' || respuesta == 'SI') {
          conformes++;
        } else if (respuesta == 'NO') {
          noConformes++;
        }
      }
    }

    final porcentaje = totalItems > 0 ? (conformes / totalItems * 100).round() : 0;

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
            children: [
              pw.Text('Total Items: $totalItems', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Conformes: $conformes', style: pw.TextStyle(fontSize: 14, color: COLOR_RESPUESTA_SI)),
              pw.Text('No Conformes: $noConformes', style: pw.TextStyle(fontSize: 14, color: COLOR_RESPUESTA_NO)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            height: 20,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: COLOR_GRIS_CLARO),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Stack(children: [
              pw.Container(
                width: double.infinity,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: COLOR_GRIS_MUY_CLARO,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
              ),
              pw.Container(
                width: (porcentaje / 100) * 200,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: porcentaje >= 80 ? COLOR_RESPUESTA_SI : porcentaje >= 60 ? COLOR_RESPUESTA_NA : COLOR_RESPUESTA_NO,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
              ),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Text('$porcentaje% de cumplimiento', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: porcentaje >= 80 ? COLOR_RESPUESTA_SI : porcentaje >= 60 ? COLOR_RESPUESTA_NA : COLOR_RESPUESTA_NO)),
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
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_CLARO),
        borderRadius: pw.BorderRadius.circular(6),
        color: COLOR_GRIS_MUY_CLARO,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Item ${item['numero']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
          if ((item['observaciones'] ?? '').toString().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Observaciones: ${item['observaciones']}', style: const pw.TextStyle(fontSize: 12)),
          ],
          if (item['tiene_foto'] == true) ...[
            pw.SizedBox(height: 4),
            pw.Text('📷 Incluye fotografía', style: pw.TextStyle(fontSize: 12, color: COLOR_RESPUESTA_SI)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _construirSeccionFotografias(List<String> images) {
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
          pw.Text('FOTOGRAFÍAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO)),
          pw.SizedBox(height: 2),
          pw.Container(height: 2, width: 60, color: COLOR_ROJO_PRINCIPAL),
          pw.SizedBox(height: 12),
          _construirGridImagenes(images.take(_IMAGES_PER_PAGE).toList()),
        ],
      ),
    );
  }

  static pw.Widget _construirGridImagenes(List<String> images) {
    final children = <pw.Widget>[];
    for (final img in images) {
      try {
        final bytes = _optimizarImagen(img);
        children.add(
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: COLOR_GRIS_CLARO), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
            ),
          ),
        );
      } catch (e) {
        print('[PDF][BODEGA] Error procesando imagen: $e');
      }
    }

    return pw.GridView(
      crossAxisCount: 2,
      childAspectRatio: 1,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: children,
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

  static List<Map<String, dynamic>> _extraerItemsRelevantesBodega(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> relevantes = [];
    
    for (int i in ITEMS_BODEGA) {
      final respuesta = data['item_$i']?.toString().toUpperCase();
      final observaciones = data['observaciones_$i']?.toString() ?? '';
      final fotoBase64 = data['foto_$i']?.toString() ?? '';
      
      final tieneObservacion = observaciones.isNotEmpty;
      final tieneFoto = fotoBase64.isNotEmpty;
      final esNoConforme = respuesta == 'NO';
      
      if (tieneObservacion || tieneFoto || esNoConforme) {
        relevantes.add({
          'numero': i,
          'respuesta': respuesta ?? 'N/A',
          'observaciones': observaciones,
          'foto_base64': fotoBase64,
          'tiene_foto': tieneFoto,
        });
      }
    }
    
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
      print('[PDF][BODEGA] Error optimizando imagen: $e');
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
}
