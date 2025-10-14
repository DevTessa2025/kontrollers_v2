import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:image/image.dart' as img;

class ObservacionesAdicionalesPDFService {
  static const int _MAX_TOTAL_PAGES = 40; // paraguas global
  static const int _IMAGES_PER_PAGE = 4;  // 2x2 grilla
  static const int _IMAGES_PER_DOC = 24;  // 6 páginas de anexos máx

  static String _mapPctToNivel(double? pct) {
    if (pct == null) return 'Medio';
    if (pct >= 67) return 'Alto';
    if (pct >= 34) return 'Medio';
    return 'Bajo';
  }

  static Future<Uint8List> generate({
    required Map<String, dynamic> data,
  }) async {
    print('[PDF][OA] Generando PDF Observaciones Adicionales para ID=${data['id']} finca=${data['finca_nombre']} tipo=${data['tipo']}');
    final pdf = pw.Document();
    // Cargar banner (logo) desde assets igual que el servicio general
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
        break;
      } catch (_) {}
    }

    final List<String> images = _extractImages(data);
    print('[PDF][OA] Imágenes detectadas: ${images.length}');
    final int totalImages = images.length;
    final List<String> limitedImages = images.take(_IMAGES_PER_DOC).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: _MAX_TOTAL_PAGES,
        margin: const pw.EdgeInsets.all(20),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
        ),
        build: (context) {
          final List<pw.Widget> widgets = [];

          // Header con logo
          widgets.add(_buildHeader(data, bannerImage));
          widgets.add(pw.SizedBox(height: 16));

          // Información general
          widgets.add(_buildInfo(data));
          widgets.add(pw.SizedBox(height: 16));

          // Observación
          widgets.add(_buildObservation(data));

          // Imágenes paginadas
          if (limitedImages.isNotEmpty) {
            widgets.add(pw.SizedBox(height: 16));
            widgets.add(pw.Text('Anexos Fotográficos', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 8));

            for (int i = 0; i < limitedImages.length; i += _IMAGES_PER_PAGE) {
              final batch = limitedImages.sublist(i, (i + _IMAGES_PER_PAGE).clamp(0, limitedImages.length));
              print('[PDF][OA] Renderizando batch de imágenes ${i + 1}-${(i + _IMAGES_PER_PAGE).clamp(0, limitedImages.length)}');
              widgets.add(_buildImageGrid(batch, data['observacion']?.toString() ?? ''));
              if (i + _IMAGES_PER_PAGE < limitedImages.length) widgets.add(pw.NewPage());
            }

            if (totalImages > _IMAGES_PER_DOC) {
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Text('Se omitieron ${totalImages - _IMAGES_PER_DOC} imágenes por tamaño del documento.', style: const pw.TextStyle(fontSize: 10)));
            }
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(Map<String, dynamic> data, pw.MemoryImage? banner) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.black, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            pw.Container(
              width: 120,
              height: 36,
              child: banner != null
                  ? pw.Image(banner, fit: pw.BoxFit.contain)
                  : pw.Center(
                      child: pw.Text('TESSA', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    ),
            ),
            pw.SizedBox(width: 10),
            pw.Text('SISTEMA KONTROLLERS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 16)),
          ]),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Finca: ${data['finca_nombre'] ?? 'N/A'}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  static pw.Widget _buildInfo(Map<String, dynamic> data) {
    final List<pw.Widget> rows = [];
    rows.add(_row('Kontroller', data['usuario_nombre'] ?? data['usuario_id'] ?? 'N/A'));
    rows.add(_row('Finca', data['finca_nombre'] ?? 'N/A'));
    if ((data['bloque_nombre'] ?? '').toString().isNotEmpty) rows.add(_row('Bloque', data['bloque_nombre'].toString()));
    if ((data['variedad_nombre'] ?? '').toString().isNotEmpty) rows.add(_row('Variedad', data['variedad_nombre'].toString()));
    if ((data['tipo'] ?? '').toString().isNotEmpty) rows.add(_row('Tipo', data['tipo'].toString()));

    if ((data['tipo']?.toString().toUpperCase() ?? '') == 'MIPE') {
      if ((data['blanco_biologico'] ?? '').toString().isNotEmpty) rows.add(_row('Blanco Biológico', data['blanco_biologico'].toString()));
      if (data['incidencia'] != null) rows.add(_row('Incidencia', _mapPctToNivel(data['incidencia']?.toDouble())));
      if (data['severidad'] != null) rows.add(_row('Severidad', _mapPctToNivel(data['severidad']?.toDouble())));
      if ((data['tercio'] ?? '').toString().isNotEmpty) rows.add(_row('Tercio', data['tercio'].toString()));
    }

    rows.add(_row('Fecha de Auditoría', _fmt(data['fecha_creacion'])));
    // Sin 'Fecha de Sincronización' según requerimiento

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('INFORMACIÓN GENERAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...rows,
      ]),
    );
  }

  static pw.Widget _row(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.SizedBox(width: 150, child: pw.Text('$k:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text(v)),
      ]),
    );
  }

  static pw.Widget _buildObservation(Map<String, dynamic> data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Observación', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text((data['observacion'] ?? '').toString().isEmpty ? 'N/A' : data['observacion'].toString()),
      ]),
    );
  }

  static pw.Widget _buildImageGrid(List<String> base64List, String caption) {
    final children = <pw.Widget>[];
    for (int i = 0; i < base64List.length; i++) {
      final bytes = _opt(base64List[i]);
      children.add(
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        ),
      );
    }

    // Completar grilla a 4 items
    while (children.length < _IMAGES_PER_PAGE) {
      children.add(pw.Container());
    }

    return pw.Column(children: [
      pw.Container(
        height: 420,
        child: pw.GridView(
        crossAxisCount: 2,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
          children: children,
        ),
      ),
      if (caption.isNotEmpty) pw.SizedBox(height: 6),
      if (caption.isNotEmpty) pw.Text('Obs: $caption', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
    ]);
  }

  static Uint8List _opt(String b64) {
    try {
      print('[PDF][OA] _opt procesando imagen, longitud b64: ${b64.length}');
      final cleaned = b64.replaceAll(RegExp(r"\s+"), '');
      final String b64Only = cleaned.startsWith('data:')
          ? cleaned.substring(cleaned.indexOf('base64,') + 7)
          : cleaned;
      print('[PDF][OA] _opt b64 limpio, longitud: ${b64Only.length}');
      
      final raw = base64Decode(b64Only);
      print('[PDF][OA] _opt bytes decodificados: ${raw.length}');
      
      final img.Image? decoded = img.decodeImage(raw);
      if (decoded == null) {
        print('[PDF][OA] _opt no se pudo decodificar imagen, devolviendo bytes originales');
        return raw;
      }
      
      print('[PDF][OA] _opt imagen decodificada: ${decoded.width}x${decoded.height}');
      final resized = img.copyResize(decoded, width: decoded.width >= decoded.height ? 1024 : null, height: decoded.height > decoded.width ? 1024 : null);
      final compressed = img.encodeJpg(resized, quality: 65);
      print('[PDF][OA] _opt imagen optimizada: ${compressed.length} bytes');
      return Uint8List.fromList(compressed);
    } catch (e) {
      print('[PDF][OA] _opt ERROR: $e (intentando fallback)');
      try {
        final cleaned = b64.replaceAll(RegExp(r"\s+"), '');
        final String b64Only = cleaned.startsWith('data:')
            ? cleaned.substring(cleaned.indexOf('base64,') + 7)
            : cleaned;
        final raw = base64Decode(b64Only);
        print('[PDF][OA] _opt fallback exitoso: ${raw.length} bytes');
        return raw;
      } catch (e2) {
        print('[PDF][OA] _opt fallback falló: $e2');
        return Uint8List(0);
      }
    }
  }

  static List<String> _extractImages(Map<String, dynamic> data) {
    try {
      final imgs = data['imagenes_json'];
      if (imgs == null) return [];
      if (imgs is String) {
        try {
          final parsed = jsonDecode(imgs);
          if (parsed is List) {
            final out = parsed.map((e) => e is String ? e : (e is Map ? (e['base64'] ?? e['fotoBase64'] ?? e['data'] ?? e['src'] ?? '').toString() : '')).where((s) => s.toString().trim().isNotEmpty).map((s) => s.toString()).toList();
            return out;
          }
        } catch (_) {
          // podría ser base64 plano
          final s = imgs.trim();
          final looksB64 = s.length > 100 && RegExp(r'^[A-Za-z0-9+/=\s]+').hasMatch(s);
          if (looksB64) return [s];
        }
      } else if (imgs is List) {
        final out = <String>[];
        for (final e in imgs) {
          if (e is String && e.trim().isNotEmpty) out.add(e.trim());
          if (e is Map) {
            final cand = (e['base64'] ?? e['fotoBase64'] ?? e['data'] ?? e['src'] ?? '').toString();
            if (cand.trim().isNotEmpty) out.add(cand.trim());
          }
        }
        return out;
      }
    } catch (_) {}
    return [];
  }

  static String _fmt(dynamic v) {
    if (v == null) return 'N/A';
    try {
      final d = DateTime.parse(v.toString());
      try {
        return DateFormat('dd/MM/yyyy HH:mm:ss', 'es_EC').format(d);
      } catch (_) {
        return DateFormat('dd/MM/yyyy HH:mm:ss').format(d);
      }
    } catch (_) {
      return v.toString();
    }
  }
}


