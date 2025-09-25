import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:intl/intl.dart';

class ObservacionesAdicionalesExcelService {
  static Future<Uint8List> buildExcelHtml({
    required List<Map<String, dynamic>> records,
    required List<String> fincas,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    print('[EXCEL][OA] Iniciando generación de Excel. Registros: ${records.length}, Fincas sel: ${fincas.join(', ')}');
    
    // Cargar logo como base64 para incrustarlo en el HTML
    String? logoB64;
    final rutas = [
      'assets/images/Tessa_banner.png',
      'assets/images/tessa_banner.png',
      'assets/Tessa_banner.png',
      'images/Tessa_banner.png',
    ];
    for (final r in rutas) {
      try {
        final ByteData bd = await rootBundle.load(r);
        final bytes = bd.buffer.asUint8List();
        logoB64 = base64Encode(bytes);
        print('[EXCEL][OA] Logo cargado desde: $r (bytes=${bytes.length})');
        break;
      } catch (e) {
        // continuar
      }
    }
    
    final String fechaRango = _fmtRange(fechaInicio, fechaFin);
    final String fincasTexto = fincas.isEmpty ? 'Todas' : fincas.join(', ');

    final StringBuffer sb = StringBuffer();
    sb.writeln('<!DOCTYPE html>');
    sb.writeln('<html>');
    sb.writeln('<head>');
    sb.writeln('<meta charset="UTF-8">');
    sb.writeln('<meta name="ProgId" content="Excel.Sheet">');
    sb.writeln('<meta name="Generator" content="Microsoft Excel 15">');
    sb.writeln('<style>');
    sb.writeln('body { font-family: Arial, sans-serif; margin: 20px; }');
    sb.writeln('.header { text-align: center; margin-bottom: 30px; border-bottom: 2px solid #2E7D32; padding-bottom: 15px; }');
    sb.writeln('.logo { max-height: 60px; margin-bottom: 10px; }');
    sb.writeln('.title { font-size: 24px; font-weight: bold; color: #2E7D32; margin: 10px 0; }');
    sb.writeln('.subtitle { font-size: 16px; color: #666; margin: 5px 0; }');
    sb.writeln('.record { margin-bottom: 30px; border: 1px solid #ddd; border-radius: 8px; overflow: hidden; }');
    sb.writeln('.record-header { background: #E8F5E8; padding: 15px; border-bottom: 1px solid #ddd; }');
    sb.writeln('.record-title { font-size: 18px; font-weight: bold; color: #2E7D32; margin: 0; }');
    sb.writeln('.record-content { padding: 20px; }');
    sb.writeln('.info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px; }');
    sb.writeln('.info-item { display: flex; flex-direction: column; }');
    sb.writeln('.info-label { font-weight: bold; color: #2E7D32; margin-bottom: 5px; font-size: 14px; }');
    sb.writeln('.info-value { color: #333; font-size: 14px; padding: 8px; background: #f9f9f9; border-radius: 4px; }');
    sb.writeln('.observation { background: #f0f8ff; padding: 15px; border-radius: 6px; margin: 15px 0; border-left: 4px solid #2196F3; }');
    sb.writeln('.observation-label { font-weight: bold; color: #1976D2; margin-bottom: 8px; }');
    sb.writeln('.observation-text { color: #333; line-height: 1.5; }');
    sb.writeln('.mipe-details { background: #fff3e0; padding: 15px; border-radius: 6px; margin: 15px 0; border-left: 4px solid #FF9800; }');
    sb.writeln('.mipe-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }');
    sb.writeln('.mipe-item { display: flex; flex-direction: column; }');
    sb.writeln('.mipe-label { font-weight: bold; color: #F57C00; font-size: 12px; margin-bottom: 3px; }');
    sb.writeln('.mipe-value { color: #333; font-size: 13px; padding: 6px; background: #fff; border-radius: 3px; }');
    sb.writeln('.images-section { margin-top: 20px; }');
    sb.writeln('.images-title { font-weight: bold; color: #2E7D32; margin-bottom: 15px; font-size: 16px; }');
    sb.writeln('.images-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }');
    sb.writeln('.image-container { text-align: center; }');
    sb.writeln('.image-container img { max-width: 100%; height: auto; border: 2px solid #ddd; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }');
    sb.writeln('.image-caption { font-size: 12px; color: #666; margin-top: 5px; }');
    sb.writeln('</style>');
    sb.writeln('</head>');
    sb.writeln('<body>');

    // Header con logo
    sb.writeln('<div class="header">');
    if (logoB64 != null) {
      sb.writeln('<img src="data:image/png;base64,$logoB64" class="logo" alt="Logo">');
    }
    sb.writeln('<div class="title">OBSERVACIONES ADICIONALES</div>');
    sb.writeln('<div class="subtitle">Fincas: $fincasTexto</div>');
    sb.writeln('<div class="subtitle">Período: $fechaRango</div>');
    sb.writeln('<div class="subtitle">Total de registros: ${records.length}</div>');
    sb.writeln('</div>');

    // Contenido de registros
    for (final r in records) {
      sb.writeln('<div class="record">');
      sb.writeln('<div class="record-header">');
      sb.writeln('<h3 class="record-title">Registro #${r['id']} - ${r['finca_nombre']} - ${r['bloque_nombre']}</h3>');
      sb.writeln('</div>');
      sb.writeln('<div class="record-content">');
      
      // Información básica en grid
      sb.writeln('<div class="info-grid">');
      _infoItem(sb, 'Variedad', r['variedad_nombre']);
      _infoItem(sb, 'Usuario', r['usuario_nombre']);
      _infoItem(sb, 'Tipo', r['tipo']);
      _infoItem(sb, 'Fecha', r['fecha_creacion']);
      sb.writeln('</div>');

      // Observación
      if ((r['observacion'] ?? '').toString().isNotEmpty) {
        sb.writeln('<div class="observation">');
        sb.writeln('<div class="observation-label">Observación:</div>');
        sb.writeln('<div class="observation-text">${_escape(r['observacion'].toString())}</div>');
        sb.writeln('</div>');
      }

      // Detalles MIPE si aplica
      if ((r['tipo'] ?? '').toString().toUpperCase() == 'MIPE') {
        sb.writeln('<div class="mipe-details">');
        sb.writeln('<div class="observation-label">Detalles MIPE:</div>');
        sb.writeln('<div class="mipe-grid">');
        _mipeItem(sb, 'Blanco Biológico', r['blanco_biologico']);
        _mipeItem(sb, 'Incidencia', r['incidencia']);
        _mipeItem(sb, 'Severidad', r['severidad']);
        _mipeItem(sb, 'Tercio', r['tercio']);
        sb.writeln('</div>');
        sb.writeln('</div>');
      }

      // Imágenes
      final List<String> imgs = _extractImages(r);
      print('[EXCEL][OA] ID=${r['id']} imágenes detectadas: ${imgs.length}');
      if (imgs.isNotEmpty) {
        sb.writeln('<div class="images-section">');
        sb.writeln('<div class="images-title">Imágenes (${imgs.length})</div>');
        sb.writeln('<div class="images-grid">');
        for (int i = 0; i < imgs.length; i++) {
          final norm = _optimizeForExcel(_normalizeImage(imgs[i]));
          print('[EXCEL][OA]   img ${(i + 1)}/${imgs.length} mime=${norm['mime']} b64len=${(norm['b64'] ?? '').toString().length}');
          sb.writeln('<div class="image-container">');
          sb.writeln('<img src="data:${norm['mime']};base64,${norm['b64']}" alt="Imagen ${i + 1}">');
          sb.writeln('<div class="image-caption">Imagen ${i + 1}</div>');
          sb.writeln('</div>');
        }
        sb.writeln('</div>');
        sb.writeln('</div>');
      }
      
      sb.writeln('</div>');
      sb.writeln('</div>');
    }

    sb.writeln('</body></html>');
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  static void _infoItem(StringBuffer sb, String label, dynamic value) {
    sb.writeln('<div class="info-item">');
    sb.writeln('<div class="info-label">$label:</div>');
    sb.writeln('<div class="info-value">${_escape((value ?? '').toString())}</div>');
    sb.writeln('</div>');
  }

  static void _mipeItem(StringBuffer sb, String label, dynamic value) {
    sb.writeln('<div class="mipe-item">');
    sb.writeln('<div class="mipe-label">$label:</div>');
    sb.writeln('<div class="mipe-value">${_escape((value ?? '').toString())}</div>');
    sb.writeln('</div>');
  }

  static String _fmtRange(DateTime? fi, DateTime? ff) {
    if (fi == null && ff == null) return 'Todas las fechas';
    if (fi == null) return 'Hasta ${DateFormat('dd/MM/yyyy').format(ff!)}';
    if (ff == null) return 'Desde ${DateFormat('dd/MM/yyyy').format(fi)}';
    return '${DateFormat('dd/MM/yyyy').format(fi)} - ${DateFormat('dd/MM/yyyy').format(ff)}';
  }

  static String _escape(String s) {
    return s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  }

  static List<String> _extractImages(Map<String, dynamic> r) {
    try {
      final imgs = r['imagenes_json'];
      print('[EXCEL][OA] _extractImages tipo=${imgs.runtimeType}');
      if (imgs == null) return [];
      if (imgs is String) {
        try {
          final parsed = jsonDecode(imgs);
          if (parsed is List) {
            final List<String> out = [];
            for (final e in parsed) {
              if (e is String) {
                if (e.trim().isNotEmpty) out.add(e.trim());
              } else if (e is Map) {
                final cand = (e['base64'] ?? e['fotoBase64'] ?? e['data'] ?? e['src'] ?? '').toString();
                if (cand.trim().isNotEmpty) out.add(cand.trim());
              }
            }
            print('[EXCEL][OA] _extractImages(list-from-string) -> ${out.length} imgs');
            return out;
          }
        } catch (e) {
          final s = imgs.trim();
          final looksB64 = s.length > 100 && RegExp(r'^[A-Za-z0-9+/=\s]+').hasMatch(s);
          if (looksB64) {
            print('[EXCEL][OA] _extractImages(plain-b64-string) -> 1 img, len=${s.length}');
            return [s];
          }
        }
      } else if (imgs is List) {
        final List<String> out = [];
        for (final e in imgs) {
          if (e is String && e.trim().isNotEmpty) out.add(e.trim());
          if (e is Map) {
            final cand = (e['base64'] ?? e['fotoBase64'] ?? e['data'] ?? e['src'] ?? '').toString();
            if (cand.trim().isNotEmpty) out.add(cand.trim());
          }
        }
        print('[EXCEL][OA] _extractImages(list-dynamic) -> ${out.length} imgs');
        return out;
      }
    } catch (e) {
      print('[EXCEL][OA] _extractImages ERROR: $e');
    }
    return [];
  }


  static Map<String, String> _normalizeImage(String b64) {
    String clean = b64.trim();
    String mime = 'image/jpeg';
    
    if (clean.startsWith('data:')) {
      final match = RegExp(r'data:([^;]+);base64,(.+)').firstMatch(clean);
      if (match != null) {
        mime = match.group(1) ?? 'image/jpeg';
        clean = match.group(2) ?? clean;
      }
    }
    
    return {'b64': clean, 'mime': mime};
  }

  static Map<String, String> _optimizeForExcel(Map<String, String> norm) {
    try {
      final b64 = norm['b64'] ?? '';
      if (b64.isEmpty) return norm;
      
      final bytes = base64Decode(b64);
      final img.Image? original = img.decodeImage(bytes);
      if (original == null) return norm;
      
      // Redimensionar para Excel (máximo 800px de ancho, mantener proporción)
      img.Image resized = original;
      if (original.width > 800) {
        final ratio = 800.0 / original.width;
        final newHeight = (original.height * ratio).round();
        resized = img.copyResize(original, width: 800, height: newHeight);
      }
      
      // Comprimir como JPEG con calidad 70 para Excel
      final compressed = img.encodeJpg(resized, quality: 70);
      final newB64 = base64Encode(compressed);
      
      print('[EXCEL][OA] Imagen optimizada: ${bytes.length} -> ${compressed.length} bytes');
      return {'b64': newB64, 'mime': 'image/jpeg'};
    } catch (e) {
      print('[EXCEL][OA] Error optimizando imagen: $e');
      return norm;
    }
  }
}
