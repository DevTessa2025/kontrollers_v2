import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PDFService {
  
  // ==================== CONFIGURACIÓN DE ITEMS POR TIPO ====================
  
  // Definir los items que existen para cada tipo de checklist
  static  Map<String, List<int>> ITEMS_POR_TIPO = {
    'fertirriego': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25], // 23 items, falta 12 y 19
    'bodega': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], // 20 items
    'aplicaciones': List.generate(30, (index) => index + 1), // 30 items del 1 al 30
    'cosecha': List.generate(20, (index) => index + 1), // 20 items del 1 al 20
    'cosechas': List.generate(20, (index) => index + 1), // Alias para cosecha
  };
  
  /// Genera un PDF completo del checklist con todos los detalles
  static Future<Uint8List> generarReporteChecklist({
    required Map<String, dynamic> recordData,
    required String checklistType,
  }) async {
    final pdf = pw.Document();
    
    // Obtener datos específicos
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final PdfColor colorTema = _obtenerColorTema(checklistType);
    
    print('🎨 Generando PDF para $tipoChecklist...');
    
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
          _construirItemsRelevantes(recordData, checklistType, colorTema),
        ],
      ),
    );

    // Página adicional para fotos si existen
    final List<Map<String, dynamic>> itemsConFotos = _obtenerItemsConFotos(recordData, checklistType);
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

    print('✅ PDF generado exitosamente');
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
                'Finca: ${data['finca_nombre'] ?? 'N/A'}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
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
          _construirFilaInfo('Kontroller:', data['usuario_nombre'] ?? 'N/A'),
          _construirFilaInfo('Finca:', data['finca_nombre'] ?? 'N/A'),
          
          // Campos específicos según tipo
          ..._construirCamposEspecificos(data, checklistType),
          
          _construirFilaInfo('Fecha de Inicio de Auditoría :', _formatearFecha(data['fecha_creacion'])),
          _construirFilaInfo('Fecha de Sincronización:', _formatearFecha(data['fecha_envio'])),
        ],
      ),
    );
  }

  static List<pw.Widget> _construirCamposEspecificos(Map<String, dynamic> data, String checklistType) {
    List<pw.Widget> campos = [];
    
    switch (checklistType.toLowerCase()) {
      case 'fertirriego':
        // Fertirriego: finca y bloque
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        break;
        
      case 'bodega':
        // Bodega: finca, supervisor y pesador
        if (data['supervisor_nombre'] != null && data['supervisor_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Supervisor:', data['supervisor_nombre'].toString()));
        }
        if (data['pesador_nombre'] != null && data['pesador_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Pesador:', data['pesador_nombre'].toString()));
        }
        break;
        
      case 'aplicaciones':
        // Aplicaciones: finca, bloque y bomba
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        if (data['bomba_nombre'] != null && data['bomba_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bomba:', data['bomba_nombre'].toString()));
        }
        break;
        
      case 'cosecha':
      case 'cosechas':
        // Cosechas: finca, bloque y variedad
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        if (data['variedad_nombre'] != null && data['variedad_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Variedad:', data['variedad_nombre'].toString()));
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
    final PdfColor colorCumplimiento = _obtenerColorCumplimientoSuave(porcentaje);
    
    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#e1e5e9'), width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Información textual
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PORCENTAJE DE CUMPLIMIENTO',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _obtenerDescripcionCumplimiento(porcentaje),
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),
                pw.SizedBox(height: 12),
                // pw.Container(
                //   padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //   decoration: pw.BoxDecoration(
                //     color: PdfColors.white,
                //     borderRadius: pw.BorderRadius.circular(16),
                //     border: pw.Border.all(color: colorCumplimiento, width: 2),
                //   ),
                //   child: pw.Text(
                //     '${porcentaje.toStringAsFixed(1)}%',
                //     style: pw.TextStyle(
                //       fontSize: 16,
                //       fontWeight: pw.FontWeight.bold,
                //       color: colorCumplimiento,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          
          pw.SizedBox(width: 20),
          
          // Gráfico circular simplificado usando círculos concéntricos
          pw.Container(
            width: 100,
            height: 100,
            child: pw.Stack(
              children: [
                // Círculo de fondo completo
                pw.Container(
                  width: 100,
                  height: 100,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: PdfColor.fromHex('#f1f3f4'),
                  ),
                ),
                
                // Círculo interior blanco para crear el "donut"
                pw.Positioned(
                  left: 15,
                  top: 15,
                  child: pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                
                // Segmentos de progreso usando múltiples arcos simulados
                ..._construirSegmentosProgreso(porcentaje, colorCumplimiento),
                
                // Porcentaje en el centro
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${porcentaje.toStringAsFixed(0)}%',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: colorCumplimiento,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método para construir segmentos de progreso simulando un arco
  static List<pw.Widget> _construirSegmentosProgreso(double porcentaje, PdfColor color) {
    List<pw.Widget> segmentos = [];
    
    // Crear múltiples segmentos pequeños para simular un arco
    int totalSegmentos = 20; // Dividir en 20 segmentos para suavidad
    int segmentosCompletos = ((porcentaje / 100) * totalSegmentos).floor();
    
    double radio = 40; // Radio del círculo para los segmentos

    for (int i = 0; i < segmentosCompletos; i++) {
      // Calcular posición de cada segmento alrededor del círculo
      double angulo = (i / totalSegmentos) * 2 * 3.14159 - (3.14159 / 2); // Comenzar desde arriba
      double x = 50 + radio * 0.707 * cos(angulo); // Posición X aproximada
      double y = 50 + radio * 0.707 * sin(angulo); // Posición Y aproximada
      
      segmentos.add(
        pw.Positioned(
          left: x - 2,
          top: y - 2,
          child: pw.Container(
            width: 4,
            height: 8,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    
    return segmentos;
  }

  // Versión alternativa más simple usando barras radiales
  static List<pw.Widget> _construirBarrasRadiales(double porcentaje, PdfColor color) {
    List<pw.Widget> barras = [];
    
    // Crear 8 barras principales (cada 45 grados)
    int totalBarras = 8;
    int barrasActivas = ((porcentaje / 100) * totalBarras).round();
    
    List<Map<String, dynamic>> posiciones = [
      {'left': 48.0, 'top': 10.0}, // 12:00
      {'left': 70.0, 'top': 20.0}, // 1:30
      {'left': 80.0, 'top': 48.0}, // 3:00
      {'left': 70.0, 'top': 70.0}, // 4:30
      {'left': 48.0, 'top': 80.0}, // 6:00
      {'left': 20.0, 'top': 70.0}, // 7:30
      {'left': 10.0, 'top': 48.0}, // 9:00
      {'left': 20.0, 'top': 20.0}, // 10:30
    ];
    
    for (int i = 0; i < barrasActivas && i < posiciones.length; i++) {
      barras.add(
        pw.Positioned(
          left: posiciones[i]['left'],
          top: posiciones[i]['top'],
          child: pw.Container(
            width: 4,
            height: 12,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }
    
    return barras;
  }

  // Colores más contrastantes para mejor visibilidad
  static PdfColor _obtenerColorCumplimientoSuave(double porcentaje) {
    if (porcentaje >= 80) return PdfColor.fromHex('#198754'); // Verde más oscuro
    if (porcentaje >= 60) return PdfColor.fromHex('#fd7e14'); // Naranja
    return PdfColor.fromHex('#dc3545'); // Rojo
  }

  // Métodos auxiliares para categorización
  static String _obtenerCategoriaCumplimiento(double porcentaje) {
    if (porcentaje >= 95) return 'Excelencia Operacional';
    if (porcentaje >= 85) return 'Alto Rendimiento';
    if (porcentaje >= 70) return 'Rendimiento Satisfactorio';
    if (porcentaje >= 50) return 'Necesita Mejoras';
    return 'Requiere Atención Inmediata';
  }

  static pw.IconData _obtenerIconoCumplimiento(double porcentaje) {
    if (porcentaje >= 90) return pw.IconData(0xe86c); // check_circle
    if (porcentaje >= 70) return pw.IconData(0xe002); // check
    if (porcentaje >= 50) return pw.IconData(0xe002); // warning
    return pw.IconData(0xe001); // error
  }

  static String _obtenerEstadoTexto(double porcentaje) {
    if (porcentaje >= 90) return 'ÓPTIMO';
    if (porcentaje >= 70) return 'BUENO';
    if (porcentaje >= 50) return 'REGULAR';
    return 'CRÍTICO';
  }

  static String _obtenerNivelTexto(double porcentaje) {
    if (porcentaje >= 95) return 'A+';
    if (porcentaje >= 85) return 'A';
    if (porcentaje >= 70) return 'B';
    if (porcentaje >= 50) return 'C';
    return 'D';
  }

  static String _obtenerCalificacionTexto(double porcentaje) {
    if (porcentaje >= 90) return '★★★★★';
    if (porcentaje >= 80) return '★★★★☆';
    if (porcentaje >= 70) return '★★★☆☆';
    if (porcentaje >= 50) return '★★☆☆☆';
    return '★☆☆☆☆';
  }

  static PdfColor _obtenerColorEstado(double porcentaje) {
    if (porcentaje >= 90) return PdfColors.green700;
    if (porcentaje >= 70) return PdfColors.blue700;
    if (porcentaje >= 50) return PdfColors.orange700;
    return PdfColors.red700;
  }

  static pw.Widget _construirItemsRelevantes(Map<String, dynamic> data, String checklistType, PdfColor colorTema) {
    final List<Map<String, dynamic>> items = _extraerItemsRelevantes(data, checklistType);
    
    if (items.isEmpty) {
      return pw.Container(
        padding: pw.EdgeInsets.all(20),
        child: pw.Text(
          'No se encontraron items con observaciones, fotos o respuestas negativas.',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESULTADOS DEL CHECKLIST',
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

  /// Extrae solo los items relevantes: con observaciones, fotos o respuesta "NO"
  /// MEJORADO: Solo busca en los items que existen para el tipo de checklist
  static List<Map<String, dynamic>> _extraerItemsRelevantes(Map<String, dynamic> data, String checklistType) {
    List<Map<String, dynamic>> items = [];
    
    // Obtener los items que existen para este tipo de checklist
    List<int> itemsExistentes = ITEMS_POR_TIPO[checklistType.toLowerCase()] ?? [];
    
    print('📋 Extrayendo items relevantes para $checklistType');
    print('🔍 Items a verificar: $itemsExistentes');
    
    for (int i in itemsExistentes) {
      String? respuesta = data['item_${i}_respuesta'];
      int? valorNumerico = data['item_${i}_valor_numerico'];
      String? observaciones = data['item_${i}_observaciones'];
      String? fotoBase64 = data['item_${i}_foto_base64'];
      
      // Solo incluir si:
      // 1. Tiene observaciones no vacías
      // 2. Tiene foto
      // 3. La respuesta es "NO"
      bool tieneObservaciones = observaciones != null && observaciones.trim().isNotEmpty;
      bool tieneFoto = fotoBase64 != null && fotoBase64.isNotEmpty;
      bool esRespuestaNo = respuesta != null && respuesta.toLowerCase() == 'no';
      
      if (tieneObservaciones || tieneFoto || esRespuestaNo) {
        items.add({
          'numero': i,
          'respuesta': respuesta,
          'valor_numerico': valorNumerico,
          'observaciones': observaciones,
          'foto_base64': fotoBase64,
          'tiene_foto': tieneFoto,
        });
        
        print('✅ Item $i incluido: respuesta=$respuesta, obs=${tieneObservaciones ? "SÍ" : "NO"}, foto=${tieneFoto ? "SÍ" : "NO"}');
      }
    }
    
    print('📊 Total items relevantes encontrados: ${items.length}');
    return items;
  }

  static List<Map<String, dynamic>> _obtenerItemsConFotos(Map<String, dynamic> data, String checklistType) {
    return _extraerItemsRelevantes(data, checklistType).where((item) => item['tiene_foto'] == true).toList();
  }

  static String _formatearFecha(String? fechaString) {
    if (fechaString == null || fechaString.isEmpty) return 'N/A';
    
    try {
      DateTime fechaUTC = DateTime.parse(fechaString);
      
      // Ajusta a la zona horaria de Ecuador (UTC-5)
      DateTime fechaLocal = fechaUTC.subtract(const Duration(hours: 5));
      
      // Formatea la fecha ya ajustada
      return DateFormat('dd/MM/yyyy HH:mm:ss', 'es_EC').format(fechaLocal);

    } catch (e) {
      // Si falla el parseo, devuelve el string original
      print('Error al formatear fecha: $e');
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
      case 'cosecha':
      case 'cosechas':
        return 'Cosecha';
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
      case 'cosecha':
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
           data.containsKey('finca_nombre') && 
           data.containsKey('usuario_nombre');
  }

  static Map<String, String> obtenerEstadisticasReporte(Map<String, dynamic> data, String checklistType) {
    final items = _extraerItemsRelevantes(data, checklistType);
    final itemsConFotos = _obtenerItemsConFotos(data, checklistType);
    final itemsConObservaciones = items.where((item) => 
        item['observaciones'] != null && item['observaciones'].toString().trim().isNotEmpty).length;
    final itemsConNo = items.where((item) => 
        item['respuesta'] != null && item['respuesta'].toString().toLowerCase() == 'no').length;
    
    return {
      'items_relevantes': items.length.toString(),
      'items_con_fotos': itemsConFotos.length.toString(),
      'items_con_observaciones': itemsConObservaciones.toString(),
      'items_con_no': itemsConNo.toString(),
      'porcentaje_cumplimiento': (data['porcentaje_cumplimiento'] ?? 0.0).toStringAsFixed(1),
    };
  }
}