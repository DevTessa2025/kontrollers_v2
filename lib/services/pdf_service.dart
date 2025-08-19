import 'dart:typed_data';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PDFService {
  
  /// Genera un PDF completo del checklist con todos los detalles
  static Future<Uint8List> generarReporteChecklist({
    required Map<String, dynamic> recordData,
    required String checklistType,
  }) async {
    final pdf = pw.Document();
    
    // Obtener datos específicos
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final PdfColor colorTema = _obtenerColorTema(checklistType);
    
    // Página principal con información general
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        header: (context) => _construirHeader(tipoChecklist, colorTema, recordData),
        footer: (context) => _construirFooter(context),
        build: (context) => [
          _construirInformacionGeneral(recordData, checklistType, colorTema),
          pw.SizedBox(height: 20),
          _construirResumenCumplimiento(recordData, colorTema),
          pw.SizedBox(height: 20),
          _construirItemsChecklist(recordData, colorTema),
        ],
      ),
    );

    // Página adicional para fotos si existen
    final List<Map<String, dynamic>> itemsConFotos = _obtenerItemsConFotos(recordData);
    if (itemsConFotos.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          header: (context) => _construirHeaderFotos(tipoChecklist, colorTema),
          footer: (context) => _construirFooter(context),
          build: (context) => [
            _construirSeccionFotografias(itemsConFotos, colorTema),
          ],
        ),
      );
    }

    return pdf.save();
  }

  // ==================== CONSTRUCCIÓN DE COMPONENTES ====================

  static pw.Widget _construirHeader(String tipoChecklist, PdfColor colorTema, Map<String, dynamic> data) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: colorTema,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SISTEMA KONTROLLERS',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Reporte de $tipoChecklist',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'ID: ${data['id']}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirHeaderFotos(String tipoChecklist, PdfColor colorTema) {
    return pw.Container(
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: colorTema,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'FOTOGRAFÍAS ADJUNTAS - $tipoChecklist',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Página de Anexos',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _construirInformacionGeneral(Map<String, dynamic> data, String checklistType, PdfColor colorTema) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: colorTema, width: 2),
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
              color: colorTema,
            ),
          ),
          pw.SizedBox(height: 10),
          
          // Información básica
          _construirFilaInfo('ID del Registro:', data['id'].toString()),
          _construirFilaInfo('UUID:', data['checklist_uuid'] ?? 'N/A'),
          _construirFilaInfo('Usuario:', data['usuario_nombre'] ?? 'N/A'),
          _construirFilaInfo('Finca:', data['finca_nombre'] ?? 'N/A'),
          
          // Campos específicos según tipo
          ..._construirCamposEspecificos(data, checklistType),
          
          _construirFilaInfo('Fecha de Creación:', _formatearFecha(data['fecha_creacion'])),
          _construirFilaInfo('Fecha de Envío:', _formatearFecha(data['fecha_envio'])),
        ],
      ),
    );
  }

  static List<pw.Widget> _construirCamposEspecificos(Map<String, dynamic> data, String checklistType) {
    List<pw.Widget> campos = [];
    
    switch (checklistType.toLowerCase()) {
      case 'fertirriego':
        if (data['bloque_nombre'] != null) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre']));
        }
        break;
        
      case 'bodega':
        if (data['supervisor_nombre'] != null) {
          campos.add(_construirFilaInfo('Supervisor:', data['supervisor_nombre']));
        }
        if (data['pesador_nombre'] != null) {
          campos.add(_construirFilaInfo('Pesador:', data['pesador_nombre']));
        }
        break;
        
      case 'aplicaciones':
        if (data['bloque_nombre'] != null) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre']));
        }
        if (data['bomba_nombre'] != null) {
          campos.add(_construirFilaInfo('Bomba:', data['bomba_nombre']));
        }
        break;
        
      case 'cosechas':
        if (data['bloque_nombre'] != null) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre']));
        }
        if (data['variedad_nombre'] != null) {
          campos.add(_construirFilaInfo('Variedad:', data['variedad_nombre']));
        }
        break;
    }
    
    return campos;
  }

  static pw.Widget _construirFilaInfo(String etiqueta, String valor) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(valor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirResumenCumplimiento(Map<String, dynamic> data, PdfColor colorTema) {
    final double porcentaje = (data['porcentaje_cumplimiento'] ?? 0.0).toDouble();
    final PdfColor colorCumplimiento = _obtenerColorCumplimiento(porcentaje);
    
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#f5f5f5'), // Color de fondo neutro
        border: pw.Border.all(color: colorCumplimiento, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PORCENTAJE DE CUMPLIMIENTO',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: colorCumplimiento,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                _obtenerDescripcionCumplimiento(porcentaje),
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.Container(
            width: 80,
            height: 80,
            child: pw.Stack(
              children: [
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.grey300, width: 6),
                  ),
                ),
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: colorCumplimiento, width: 6),
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            '${porcentaje.toStringAsFixed(1)}%',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: colorCumplimiento,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirItemsChecklist(Map<String, dynamic> data, PdfColor colorTema) {
    final List<Map<String, dynamic>> items = _extraerItems(data);
    
    if (items.isEmpty) {
      return pw.Container(
        padding: pw.EdgeInsets.all(20),
        child: pw.Text(
          'No se encontraron items completados en este checklist.',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ITEMS DEL CHECKLIST (${items.length} items)',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: colorTema,
          ),
        ),
        pw.SizedBox(height: 10),
        
        // Tabla de items
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: pw.FixedColumnWidth(50),
            1: pw.FixedColumnWidth(60),
            2: pw.FixedColumnWidth(80),
            3: pw.FlexColumnWidth(2),
            4: pw.FixedColumnWidth(60),
          },
          children: [
            // Header de la tabla
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f0f0f0')),
              children: [
                _construirCeldaHeader('Item'),
                _construirCeldaHeader('Respuesta'),
                _construirCeldaHeader('Valor'),
                _construirCeldaHeader('Observaciones'),
                _construirCeldaHeader('Foto'),
              ],
            ),
            
            // Filas de items
            ...items.map((item) => _construirFilaItem(item)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _construirCeldaHeader(String texto) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.TableRow _construirFilaItem(Map<String, dynamic> item) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(
            item['numero'].toString(),
            style: pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: pw.BoxDecoration(
              color: _obtenerColorFondoRespuesta(item['respuesta']),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              (item['respuesta'] ?? 'N/A').toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _obtenerColorRespuesta(item['respuesta']),
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(
            item['valor_numerico']?.toString() ?? '-',
            style: pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(
            item['observaciones'] ?? '-',
            style: pw.TextStyle(fontSize: 8),
            maxLines: 3,
            overflow: pw.TextOverflow.clip,
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(
            item['tiene_foto'] ? 'SÍ' : 'NO',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: item['tiene_foto'] ? PdfColors.green : PdfColors.grey,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  static pw.Widget _construirSeccionFotografias(List<Map<String, dynamic>> itemsConFotos, PdfColor colorTema) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FOTOGRAFÍAS ADJUNTAS',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: colorTema,
          ),
        ),
        pw.SizedBox(height: 15),
        
        ...itemsConFotos.map((item) => _construirSeccionFoto(item, colorTema)).toList(),
      ],
    );
  }

  static pw.Widget _construirSeccionFoto(Map<String, dynamic> item, PdfColor colorTema) {
    try {
      final Uint8List imageBytes = base64Decode(item['foto_base64']);
      
      return pw.Container(
        margin: pw.EdgeInsets.only(bottom: 20),
        padding: pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: colorTema, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Item ${item['numero']}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: colorTema,
              ),
            ),
            if (item['observaciones'] != null && item['observaciones'].isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                'Observaciones: ${item['observaciones']}',
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                width: 300,
                height: 200,
                fit: pw.BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return pw.Container(
        margin: pw.EdgeInsets.only(bottom: 20),
        padding: pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.red, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              'Item ${item['numero']} - Error al cargar imagen',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red,
              ),
            ),
            pw.Text(
              'La imagen no pudo ser procesada correctamente.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
      );
    }
  }

  // ==================== MÉTODOS DE UTILIDAD ====================

  static List<Map<String, dynamic>> _extraerItems(Map<String, dynamic> data) {
    List<Map<String, dynamic>> items = [];
    
    for (int i = 1; i <= 50; i++) {
      String? respuesta = data['item_${i}_respuesta'];
      int? valorNumerico = data['item_${i}_valor_numerico'];
      String? observaciones = data['item_${i}_observaciones'];
      String? fotoBase64 = data['item_${i}_foto_base64'];
      
      if (respuesta != null || valorNumerico != null || 
          (observaciones != null && observaciones.isNotEmpty) || 
          (fotoBase64 != null && fotoBase64.isNotEmpty)) {
        
        items.add({
          'numero': i,
          'respuesta': respuesta,
          'valor_numerico': valorNumerico,
          'observaciones': observaciones,
          'foto_base64': fotoBase64,
          'tiene_foto': fotoBase64 != null && fotoBase64.isNotEmpty,
        });
      }
    }
    
    return items;
  }

  static List<Map<String, dynamic>> _obtenerItemsConFotos(Map<String, dynamic> data) {
    return _extraerItems(data).where((item) => item['tiene_foto'] == true).toList();
  }

  static String _formatearFecha(String? fechaString) {
    if (fechaString == null) return 'N/A';
    try {
      DateTime fecha = DateTime.parse(fechaString);
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha);
    } catch (e) {
      return fechaString;
    }
  }

  static String _obtenerNombreChecklist(String checklistType) {
    switch (checklistType.toLowerCase()) {
      case 'fertirriego':
        return 'Fertirriego';
      case 'bodega':
        return 'Bodega';
      case 'aplicaciones':
        return 'Aplicaciones';
      case 'cosechas':
        return 'Cosechas';
      default:
        return checklistType.toUpperCase();
    }
  }

  static PdfColor _obtenerColorTema(String checklistType) {
    switch (checklistType.toLowerCase()) {
      case 'fertirriego':
        return PdfColors.blue700;
      case 'bodega':
        return PdfColors.orange700;
      case 'aplicaciones':
        return PdfColors.green700;
      case 'cosechas':
        return PdfColors.purple700;
      default:
        return PdfColors.red700;
    }
  }

  static PdfColor _obtenerColorCumplimiento(double porcentaje) {
    if (porcentaje >= 80) return PdfColors.green;
    if (porcentaje >= 60) return PdfColors.orange;
    return PdfColors.red;
  }

  static String _obtenerDescripcionCumplimiento(double porcentaje) {
    if (porcentaje >= 90) return 'Excelente cumplimiento';
    if (porcentaje >= 80) return 'Buen cumplimiento';
    if (porcentaje >= 60) return 'Cumplimiento regular';
    if (porcentaje >= 40) return 'Cumplimiento bajo';
    return 'Cumplimiento deficiente';
  }

  static PdfColor _obtenerColorRespuesta(String? respuesta) {
    if (respuesta == null) return PdfColors.grey;
    switch (respuesta.toLowerCase()) {
      case 'si':
        return PdfColors.green;
      case 'no':
        return PdfColors.red;
      case 'na':
        return PdfColors.orange;
      default:
        return PdfColors.grey;
    }
  }

  static PdfColor _obtenerColorFondoRespuesta(String? respuesta) {
    if (respuesta == null) return PdfColor.fromHex('#f5f5f5');
    switch (respuesta.toLowerCase()) {
      case 'si':
        return PdfColor.fromHex('#e8f5e8'); // Verde claro
      case 'no':
        return PdfColor.fromHex('#ffeaea'); // Rojo claro
      case 'na':
        return PdfColor.fromHex('#fff3e0'); // Naranja claro
      default:
        return PdfColor.fromHex('#f5f5f5'); // Gris claro
    }
  }

  // ==================== MÉTODOS DE VALIDACIÓN ====================

  static bool validarDatosParaPDF(Map<String, dynamic> data) {
    return data.isNotEmpty && 
           data.containsKey('id') && 
           data.containsKey('checklist_uuid');
  }

  static Map<String, String> obtenerEstadisticasReporte(Map<String, dynamic> data) {
    final items = _extraerItems(data);
    final itemsConFotos = _obtenerItemsConFotos(data);
    final itemsConObservaciones = items.where((item) => 
        item['observaciones'] != null && item['observaciones'].isNotEmpty).length;
    
    return {
      'total_items': items.length.toString(),
      'items_con_fotos': itemsConFotos.length.toString(),
      'items_con_observaciones': itemsConObservaciones.toString(),
      'porcentaje_cumplimiento': (data['porcentaje_cumplimiento'] ?? 0.0).toStringAsFixed(1),
    };
  }
}