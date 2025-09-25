import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle, ByteData;

class ObservacionesAdicionalesExportService {
  static Future<Uint8List> buildWordDocHtml({
    required List<Map<String, dynamic>> records,
    required List<String> fincas,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    print('[WORD][OA] Iniciando generación de Word. Registros: ${records.length}, Fincas sel: ${fincas.join(', ')}');
    // Cargar logo como base64 para incrustarlo en el .doc (HTML)
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
        print('[WORD][OA] Logo cargado desde: $r (bytes=${bytes.length})');
        break;
      } catch (e) {
        // continuar
      }
    }
    final String fechaRango = _fmtRange(fechaInicio, fechaFin);
    final String fincasTexto = fincas.isEmpty ? 'Todas' : fincas.join(', ');

    final StringBuffer sb = StringBuffer();
    sb.writeln('<!DOCTYPE html>');
    sb.writeln('<html><head><meta charset="utf-8"><style>');
    sb.writeln('body{font-family:Arial,Helvetica,sans-serif;color:#222;}');
    sb.writeln('.header{background:#000;color:#fff;padding:10px 14px;border-radius:8px;}');
    sb.writeln('.small{font-size:12px;opacity:.9;}');
    sb.writeln('.card{border:1px solid #e0e0e0;border-radius:8px;padding:12px;margin:12px 0;background:#fff;}');
    sb.writeln('.tag{display:inline-block;background:#f5f5f5;border:1px solid #ddd;border-radius:12px;padding:2px 8px;margin-right:6px;font-size:12px;}');
    sb.writeln('table{border-collapse:collapse;width:100%;margin-top:6px;}');
    sb.writeln('td,th{padding:6px 8px;vertical-align:top;border:1px solid #eee;}');
    sb.writeln('.label{background:#fafafa;font-weight:bold;width:180px;}');
    sb.writeln('</style></head><body>');

    // Header (tabla compatible con Word)
    sb.writeln('<table class="header" cellpadding="0" cellspacing="0" width="100%"><tr>');
    sb.writeln('<td style="width:140px">');
    if (logoB64 != null) {
      sb.writeln('<img src="data:image/png;base64,$logoB64" style="height:36px" />');
    } else {
      sb.writeln('<div style="font-weight:bold;font-size:18px;">TESSA</div>');
    }
    sb.writeln('</td>');
    sb.writeln('<td style="text-align:left;font-weight:bold;font-size:18px;">SISTEMA KONTROLLERS</td>');
    sb.writeln('<td style="text-align:right" class="small">${DateTime.now().toString().substring(0,16)}</td>');
    sb.writeln('</tr></table>');
    sb.writeln('<h2 style="margin:12px 0;">Observaciones Adicionales</h2>');
    sb.writeln('<div class="card"><span class="tag">Fincas: $fincasTexto</span>'
        '<span class="tag">Rango: $fechaRango</span>'
        '<span class="tag">Total: ${records.length}</span></div>');

    for (final r in records) {
      try {
        print('[WORD][OA] Registro ID=${r['id']} finca=${r['finca_nombre']} tipo=${r['tipo']} usuario=${r['usuario_nombre']}');
      } catch (_) {}
      final String tipo = (r['tipo'] ?? '').toString();
      final bool esMIPE = tipo.toUpperCase() == 'MIPE';

      sb.writeln('<div class="card">');
      sb.writeln('<div>');
      sb.writeln('<span class="tag">ID ${r['id']}</span>');
      if (tipo.isNotEmpty) sb.writeln('<span class="tag">$tipo</span>');
      if ((r['usuario_nombre'] ?? '').toString().isNotEmpty) sb.writeln('<span class="tag">${r['usuario_nombre']}</span>');
      sb.writeln('</div>');
      sb.writeln('<table>');
      _row(sb, 'Finca', r['finca_nombre']);
      _row(sb, 'Bloque', r['bloque_nombre']);
      _row(sb, 'Variedad', r['variedad_nombre']);
      _row(sb, 'Fecha creación', r['fecha_creacion']);
      if (esMIPE) {
        _row(sb, 'Blanco Biológico', r['blanco_biologico']);
        _row(sb, 'Incidencia', r['incidencia'] != null ? '${r['incidencia']}%' : null);
        _row(sb, 'Severidad', r['severidad'] != null ? '${r['severidad']}%' : null);
        _row(sb, 'Tercio', r['tercio']);
      }
      _row(sb, 'Observación', r['observacion']);
      sb.writeln('</table>');

      final List<String> imgs = _extractImages(r);
      print('[WORD][OA]  ID=${r['id']} imágenes detectadas: ${imgs.length}');
      if (imgs.isNotEmpty) {
        // 2xN tabla (más compatible que CSS grid)
        sb.writeln('<table style="width:100%;margin-top:8px;border:0;">');
        for (int i = 0; i < imgs.length; i += 2) {
          sb.writeln('<tr>');
          for (int j = 0; j < 2; j++) {
            if (i + j < imgs.length) {
              final norm = _optimizeForWord(_normalizeImage(imgs[i + j]));
              print('[WORD][OA]   img ${(i + j) + 1}/${imgs.length} mime=${norm['mime']} b64len=${(norm['b64'] ?? '').toString().length}');
              sb.writeln('<td style="width:50%;padding:4px;border:0;">');
              sb.writeln('<img src="data:${norm['mime']};base64,${norm['b64']}" style="width:100%;height:auto;border:1px solid #ddd;border-radius:6px" alt="img"/>');
              sb.writeln('</td>');
            } else {
              sb.writeln('<td style="width:50%;padding:4px;border:0;"></td>');
            }
          }
          sb.writeln('</tr>');
        }
        sb.writeln('</table>');
      }
      sb.writeln('</div>');
    }

    sb.writeln('</body></html>');
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  static void _row(StringBuffer sb, String k, dynamic v) {
    final val = (v ?? '').toString();
    if (val.isEmpty) return;
    sb.writeln('<tr><td class="label">$k:</td><td>${_escape(val)}</td></tr>');
  }

  static List<String> _extractImages(Map<String, dynamic> r) {
    try {
      final imgs = r['imagenes_json'];
      print('[WORD][OA] _extractImages tipo=${imgs.runtimeType}');
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
            print('[WORD][OA] _extractImages(list-from-string) -> ${out.length} imgs');
            return out;
          }
        } catch (e) {
          final s = imgs.trim();
          final looksB64 = s.length > 100 && RegExp(r'^[A-Za-z0-9+/=\s]+').hasMatch(s);
          if (looksB64) {
            print('[WORD][OA] _extractImages(plain-b64-string) -> 1 img, len=${s.length}');
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
        print('[WORD][OA] _extractImages(list-dynamic) -> ${out.length} imgs');
        return out;
      }
    } catch (e) {
      print('[WORD][OA] _extractImages ERROR: $e');
    }
    return [];
  }

  static String _detectMime(String b64) {
    // JPEG suele empezar con /9j, PNG con iVBOR
    if (b64.startsWith('/9j')) return 'image/jpeg';
    if (b64.startsWith('iVBOR')) return 'image/png';
    return 'image/jpeg';
  }

  // Normaliza la cadena base64 (quita prefijos data: y detecta mime)
  // Retorna (mime, base64Puro)
  static Map<String, String> _normalizeImage(String raw) {
    String r = raw.trim();
    String mime = 'image/jpeg';
    if (r.startsWith('data:')) {
      final idx = r.indexOf('base64,');
      if (idx != -1) {
        final header = r.substring(5, idx - 1); // data:...;
        if (header.contains('png')) mime = 'image/png';
        if (header.contains('jpeg') || header.contains('jpg')) mime = 'image/jpeg';
        r = r.substring(idx + 7);
      }
    } else {
      mime = _detectMime(r);
    }
    // Eliminar cualquier whitespace (Word puede fallar con saltos de línea en base64)
    r = r.replaceAll(RegExp(r"\s+"), '');
    print('[WORD][OA] _normalizeImage mime=$mime b64len=${r.length} head=${r.substring(0, r.length > 30 ? 30 : r.length)}');
    return {'mime': mime, 'b64': r};
  }

  // Redimensiona y recomprime a JPG (max 1024px lado mayor, calidad ~70)
  static Map<String, String> _optimizeForWord(Map<String, String> norm) {
    try {
      final bytes = base64Decode(norm['b64']!);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return norm;
      final int w = decoded.width;
      final int h = decoded.height;
      final int maxSide = 1024;
      img.Image resized = decoded;
      if (w > maxSide || h > maxSide) {
        resized = img.copyResize(decoded, width: w >= h ? maxSide : null, height: h > w ? maxSide : null, interpolation: img.Interpolation.cubic);
      }
      final jpg = img.encodeJpg(resized, quality: 70);
      final out = {'mime': 'image/jpeg', 'b64': base64Encode(jpg)};
      return out;
    } catch (e) {
      print('[WORD][OA] _optimizeForWord ERROR: $e (devolviendo original)');
      return norm;
    }
  }

  static String _fmtRange(DateTime? i, DateTime? f) {
    String fi = i == null ? 'Inicio' : _fmt(i);
    String ff = f == null ? 'Fin' : _fmt(f);
    return '$fi - $ff';
  }

  static String _fmt(DateTime d) {
    final two = (int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  static String _escape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}


