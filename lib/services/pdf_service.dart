import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  // ==================== COLORES DE LA NUEVA PALETA ====================
  
  // Colores principales - Negro, gris y rojo
  static const PdfColor COLOR_NEGRO = PdfColors.black;
  static const PdfColor COLOR_GRIS_OSCURO = PdfColor.fromInt(0xFF424242);
  static const PdfColor COLOR_GRIS_MEDIO = PdfColor.fromInt(0xFF757575);
  static const PdfColor COLOR_GRIS_CLARO = PdfColor.fromInt(0xFFBDBDBD);
  static const PdfColor COLOR_GRIS_MUY_CLARO = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor COLOR_ROJO_PRINCIPAL = PdfColor.fromInt(0xFFD32F2F);
  static const PdfColor COLOR_ROJO_CLARO = PdfColor.fromInt(0xFFFFEBEE);
  
  // Colores para respuestas (únicos elementos con color)
  static const PdfColor COLOR_RESPUESTA_SI = PdfColor.fromInt(0xFF2E7D32);      // Verde para SÍ
  static const PdfColor COLOR_RESPUESTA_NO = PdfColor.fromInt(0xFFD32F2F);      // Rojo para NO
  static const PdfColor COLOR_RESPUESTA_NA = PdfColor.fromInt(0xFFFF8F00);      // Naranja para N/A
  static const PdfColor COLOR_RESPUESTA_SI_FONDO = PdfColor.fromInt(0xFFE8F5E8);
  static const PdfColor COLOR_RESPUESTA_NO_FONDO = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor COLOR_RESPUESTA_NA_FONDO = PdfColor.fromInt(0xFFFFF3E0);

  // Colores para porcentajes de cumplimiento
  static const PdfColor COLOR_CUMPLIMIENTO_EXCELENTE = PdfColor.fromInt(0xFF1B5E20); // Verde oscuro ≥90%
  static const PdfColor COLOR_CUMPLIMIENTO_BUENO = PdfColor.fromInt(0xFF2E7D32);     // Verde medio ≥70%
  static const PdfColor COLOR_CUMPLIMIENTO_REGULAR = PdfColor.fromInt(0xFFFF8F00);   // Naranja ≥50%
  static const PdfColor COLOR_CUMPLIMIENTO_MALO = PdfColor.fromInt(0xFFD32F2F);      // Rojo <50%
  
  /// Genera un PDF completo del checklist con todos los detalles
  static Future<Uint8List> generarReporteChecklist({
    required Map<String, dynamic> recordData,
    required String checklistType,
  }) async {
    final pdf = pw.Document();
    
    // Intentar cargar imagen del banner desde diferentes rutas posibles
    pw.MemoryImage? bannerImage;
    List<String> rutasPosibles = [
      'assets/images/Tessa_banner.png',
      'assets/images/tessa_banner.png',
      'assets/Tessa_banner.png',
      'images/Tessa_banner.png',
    ];
    
    for (String ruta in rutasPosibles) {
      try {
        final ByteData data = await rootBundle.load(ruta);
        final Uint8List bytes = data.buffer.asUint8List();
        bannerImage = pw.MemoryImage(bytes);
        print('✅ Imagen del banner cargada desde: $ruta');
        break; // Salir del bucle si encuentra la imagen
      } catch (e) {
        print('❌ No se encontró imagen en: $ruta');
        continue; // Intentar siguiente ruta
      }
    }
    
    if (bannerImage == null) {
      print('⚠️ No se pudo cargar la imagen del banner desde ninguna ruta');
      print('📝 Continuando con header solo de texto...');
    }
    
    // Obtener datos específicos
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    
    print('🎨 Generando PDF para $tipoChecklist con nueva paleta de colores...');
    
    // Obtener items con fotos
    final List<Map<String, dynamic>> itemsConFotos = _obtenerItemsConFotos(recordData, checklistType);
    
    // Página principal con información general
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        header: (context) => _construirHeader(tipoChecklist, recordData, bannerImage),
        footer: (context) => _construirFooter(context),
        build: (context) => [
          _construirInformacionGeneral(recordData, checklistType),
          pw.SizedBox(height: 20),
          _construirResumenCumplimiento(recordData),
          pw.SizedBox(height: 20),
          // Mostrar items con fotos en lugar de items relevantes
          if (itemsConFotos.isNotEmpty) ...[
            _construirSeccionFotografias(itemsConFotos),
          ],
        ],
      ),
    );

    print('✅ PDF generado exitosamente con nueva paleta de colores');
    return pdf.save();
  }

  // ==================== CONSTRUCCIÓN DE COMPONENTES ====================

  static pw.Widget _construirHeader(String tipoChecklist, Map<String, dynamic> data, pw.MemoryImage? bannerImage) {
    return pw.Container(
      height: 80,
      decoration: pw.BoxDecoration(
        color: COLOR_NEGRO,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Padding(
        padding: pw.EdgeInsets.all(16),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // IZQUIERDA: Imagen del banner (si existe)
            pw.Container(
              width: 120,
              height: 48,
              child: bannerImage != null 
                ? pw.Image(
                    bannerImage,
                    fit: pw.BoxFit.contain,
                  )
                : pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'TESSA',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            ),
            
            // CENTRO: Sistema Kontrollers
            pw.Expanded(
              child: pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'SISTEMA KONTROLLERS',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Reporte de $tipoChecklist',
                      style: pw.TextStyle(
                        color: COLOR_GRIS_CLARO,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.normal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            // DERECHA: Finca y fecha
            pw.Container(
              width: 140,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Finca: ${data['finca_nombre'] ?? 'N/A'}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(
                      color: COLOR_GRIS_CLARO,
                      fontSize: 9,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _construirHeaderFotos(String tipoChecklist, pw.MemoryImage? bannerImage) {
    return pw.Container(
      height: 60,
      decoration: pw.BoxDecoration(
        color: COLOR_NEGRO,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Padding(
        padding: pw.EdgeInsets.all(12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // IZQUIERDA: Imagen pequeña del banner (si existe)
            pw.Container(
              width: 80,
              height: 36,
              child: bannerImage != null 
                ? pw.Image(
                    bannerImage,
                    fit: pw.BoxFit.contain,
                  )
                : pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'TESSA',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            ),
            
            // CENTRO: Título de fotografías
            pw.Expanded(
              child: pw.Center(
                child: pw.Text(
                  'FOTOGRAFÍAS ADJUNTAS - $tipoChecklist',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
            
            // DERECHA: Etiqueta de anexos
            pw.Container(
              width: 80,
              child: pw.Text(
                'Página de Anexos',
                style: pw.TextStyle(
                  color: COLOR_GRIS_CLARO,
                  fontSize: 10,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _construirFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 10, color: COLOR_GRIS_MEDIO),
      ),
    );
  }

  static pw.Widget _construirInformacionGeneral(Map<String, dynamic> data, String checklistType) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_MEDIO, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
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
          pw.SizedBox(height: 2),
          pw.Container(
            height: 2,
            width: 60,
            color: COLOR_ROJO_PRINCIPAL,
          ),
          pw.SizedBox(height: 12),
          
          // Información básica
          _construirFilaInfo('Kontroller:', data['usuario_nombre'] ?? 'N/A'),
          _construirFilaInfo('Finca:', data['finca_nombre'] ?? 'N/A'),
          
          // Campos específicos según tipo
          ..._construirCamposEspecificos(data, checklistType),
          
          _construirFilaInfo('Fecha de Auditoría:', _formatearFecha(data['fecha_creacion'])),
          _construirFilaInfo('Fecha de Sincronización:', _formatearFecha(data['fecha_envio'])),
        ],
      ),
    );
  }

  static List<pw.Widget> _construirCamposEspecificos(Map<String, dynamic> data, String checklistType) {
    List<pw.Widget> campos = [];
    
    switch (checklistType.toLowerCase()) {
      case 'fertirriego':
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        break;
        
      case 'bodega':
        if (data['supervisor_nombre'] != null && data['supervisor_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Supervisor:', data['supervisor_nombre'].toString()));
        }
        if (data['pesador_nombre'] != null && data['pesador_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Pesador:', data['pesador_nombre'].toString()));
        }
        break;
        
      case 'aplicaciones':
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        if (data['bomba_nombre'] != null && data['bomba_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bomba:', data['bomba_nombre'].toString()));
        }
        break;
        
      case 'cosecha':
      case 'cosechas':
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
      padding: pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              etiqueta,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: COLOR_GRIS_OSCURO,
                fontSize: 11,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(
                color: COLOR_NEGRO,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirResumenCumplimiento(Map<String, dynamic> data) {
  final double porcentaje = (data['porcentaje_cumplimiento'] ?? 0.0).toDouble();
  final PdfColor colorCumplimiento = _obtenerColorCumplimiento(porcentaje);
  
  return pw.Container(
    padding: pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      color: COLOR_GRIS_MUY_CLARO,
      border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
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
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: COLOR_NEGRO,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                height: 3,
                width: 80,
                color: COLOR_ROJO_PRINCIPAL,
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                _obtenerDescripcionCumplimiento(porcentaje),
                style: pw.TextStyle(
                  fontSize: 12,
                  color: COLOR_GRIS_OSCURO,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _obtenerCategoriaCumplimiento(porcentaje),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: COLOR_GRIS_MEDIO,
                  fontWeight: pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        
        pw.SizedBox(width: 30),
        
        // Gráfico circular de progreso mejorado (NUEVO)
        _construirGraficoCircularProgreso(porcentaje, colorCumplimiento),
      ],
    ),
  );
}
static pw.Widget _construirGraficoCircularProgreso(double porcentaje, PdfColor colorCumplimiento) {
  return pw.Container(
    width: 120,
    height: 120,
    child: pw.Stack(
      children: [
        // Círculo de fondo completo
        pw.Container(
          width: 120,
          height: 120,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(
              color: PdfColors.grey100,
              width: 8,
            ),
          ),
        ),
        
        // Círculo de progreso (usando ClipPath para el arco)
        if (porcentaje > 0)
          pw.Transform.rotate(
            angle: -3.14159 / 2, // Rotar para comenzar desde arriba
            child: pw.Container(
              width: 120,
              height: 120,
              child: pw.CircularProgressIndicator(
                value: porcentaje / 100,
                strokeWidth: 8,
                color: colorCumplimiento,
                backgroundColor: PdfColors.grey100,
              ),
            ),
          ),
        
        // Círculo interior con texto
        pw.Positioned(
          left: 20,
          top: 20,
          child: pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColors.white,
              border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
            ),
            child: pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    '${porcentaje.toStringAsFixed(0)}%',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: colorCumplimiento,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  // pw.Text(
                  //   _obtenerNivelTexto(porcentaje),
                  //   style: pw.TextStyle(
                  //     fontSize: 12,
                  //     fontWeight: pw.FontWeight.bold,
                  //     color: COLOR_GRIS_MEDIO,
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  static List<pw.Widget> _construirBarrasProgreso(double porcentaje, PdfColor color) {
    List<pw.Widget> barras = [];
    
    // 12 barras alrededor del círculo
    int totalBarras = 12;
    int barrasActivas = ((porcentaje / 100) * totalBarras).round();
    
    for (int i = 0; i < totalBarras; i++) {
      double angulo = (i / totalBarras) * 2 * 3.14159 - (3.14159 / 2); // Comenzar desde arriba
      double radio = 50;
      double x = 60 + radio * cos(angulo);
      double y = 60 + radio * sin(angulo);
      
      bool esActiva = i < barrasActivas;
      
      barras.add(
        pw.Positioned(
          left: x - 3,
          top: y - 6,
          child: pw.Transform.rotate(
            angle: angulo + (3.14159 / 2), // Rotar para que apunte al centro
            child: pw.Container(
              width: 6,
              height: 12,
              decoration: pw.BoxDecoration(
                color: esActiva ? color : COLOR_GRIS_CLARO,
                borderRadius: pw.BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      );
    }
    
    return barras;
  }

  static pw.Widget _construirItemsRelevantes(Map<String, dynamic> data, String checklistType) {
    final List<Map<String, dynamic>> items = _extraerItemsRelevantes(data, checklistType);
    
    if (items.isEmpty) {
      return pw.Container(
        padding: pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: COLOR_GRIS_MUY_CLARO,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            'No se encontraron items con observaciones, fotos o respuestas negativas.',
            style: pw.TextStyle(fontSize: 12, color: COLOR_GRIS_MEDIO),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              'RESULTADOS DEL CHECKLIST',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: COLOR_NEGRO,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: pw.BoxDecoration(
                color: COLOR_ROJO_PRINCIPAL,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                '${items.length} items',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        
        // Tabla de items
        pw.Table(
          border: pw.TableBorder.all(color: COLOR_GRIS_CLARO),
          columnWidths: {
            0: pw.FixedColumnWidth(50),
            1: pw.FixedColumnWidth(70),
            2: pw.FixedColumnWidth(80),
            3: pw.FlexColumnWidth(2),
            4: pw.FixedColumnWidth(60),
          },
          children: [
            // Header de la tabla
            pw.TableRow(
              decoration: pw.BoxDecoration(color: COLOR_GRIS_MUY_CLARO),
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
          color: COLOR_NEGRO,
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
            style: pw.TextStyle(fontSize: 9, color: COLOR_NEGRO),
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
            style: pw.TextStyle(fontSize: 9, color: COLOR_NEGRO),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(6),
          child: pw.Text(
            item['observaciones'] ?? '-',
            style: pw.TextStyle(fontSize: 8, color: COLOR_GRIS_OSCURO),
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
              color: item['tiene_foto'] ? COLOR_RESPUESTA_SI : COLOR_GRIS_MEDIO,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  static pw.Widget _construirSeccionFotografias(List<Map<String, dynamic>> itemsConFotos) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FOTOGRAFÍAS ADJUNTAS',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: COLOR_NEGRO,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          height: 3,
          width: 80,
          color: COLOR_ROJO_PRINCIPAL,
        ),
        pw.SizedBox(height: 15),
        
        ...itemsConFotos.map((item) => _construirSeccionFoto(item)).toList(),
      ],
    );
  }

  static pw.Widget _construirSeccionFoto(Map<String, dynamic> item) {
    try {
      final Uint8List imageBytes = base64Decode(item['foto_base64']);
      
      return pw.Container(
        margin: pw.EdgeInsets.only(bottom: 20),
        padding: pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
          color: PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: COLOR_NEGRO,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Item ${item['numero']}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (item['observaciones'] != null && item['observaciones'].isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Observaciones: ${item['observaciones']}',
                style: pw.TextStyle(fontSize: 10, color: COLOR_GRIS_OSCURO),
              ),
            ],
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  width: 300,
                  height: 200,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return pw.Container(
        margin: pw.EdgeInsets.only(bottom: 20),
        padding: pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: COLOR_ROJO_PRINCIPAL, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
          color: COLOR_ROJO_CLARO,
        ),
        child: pw.Column(
          children: [
            pw.Row(
              children: [
                pw.Icon(
                  pw.IconData(0xe002), // warning icon
                  color: COLOR_ROJO_PRINCIPAL,
                  size: 16,
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'Item ${item['numero']} - Error al cargar imagen',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: COLOR_ROJO_PRINCIPAL,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'La imagen no pudo ser procesada correctamente.',
              style: pw.TextStyle(fontSize: 10, color: COLOR_GRIS_OSCURO),
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

  // ==================== MÉTODOS DE COLORES ====================

  /// Obtiene el color del cumplimiento basado en el porcentaje
  static PdfColor _obtenerColorCumplimiento(double porcentaje) {
    if (porcentaje >= 90) return COLOR_CUMPLIMIENTO_EXCELENTE;
    if (porcentaje >= 70) return COLOR_CUMPLIMIENTO_BUENO;
    if (porcentaje >= 50) return COLOR_CUMPLIMIENTO_REGULAR;
    return COLOR_CUMPLIMIENTO_MALO;
  }

  /// Obtiene el color de la respuesta (SÍ, NO, N/A)
  static PdfColor _obtenerColorRespuesta(String? respuesta) {
    if (respuesta == null) return COLOR_GRIS_MEDIO;
    switch (respuesta.toLowerCase()) {
      case 'si':
      case 'sí':
        return COLOR_RESPUESTA_SI;
      case 'no':
        return COLOR_RESPUESTA_NO;
      case 'na':
      case 'n/a':
        return COLOR_RESPUESTA_NA;
      default:
        return COLOR_GRIS_MEDIO;
    }
  }

  /// Obtiene el color de fondo de la respuesta
  static PdfColor _obtenerColorFondoRespuesta(String? respuesta) {
    if (respuesta == null) return COLOR_GRIS_MUY_CLARO;
    switch (respuesta.toLowerCase()) {
      case 'si':
      case 'sí':
        return COLOR_RESPUESTA_SI_FONDO;
      case 'no':
        return COLOR_RESPUESTA_NO_FONDO;
      case 'na':
      case 'n/a':
        return COLOR_RESPUESTA_NA_FONDO;
      default:
        return COLOR_GRIS_MUY_CLARO;
    }
  }

  /// Obtiene la descripción textual del cumplimiento
  static String _obtenerDescripcionCumplimiento(double porcentaje) {
    if (porcentaje >= 95) return 'Cumplimiento excepcional - Excelencia operacional';
    if (porcentaje >= 85) return 'Cumplimiento excelente - Alto rendimiento';
    if (porcentaje >= 70) return 'Cumplimiento satisfactorio - Buen desempeño';
    if (porcentaje >= 50) return 'Cumplimiento regular - Requiere atención';
    if (porcentaje >= 25) return 'Cumplimiento bajo - Necesita mejoras urgentes';
    return 'Cumplimiento crítico - Atención inmediata requerida';
  }

  /// Obtiene la categoría del cumplimiento
  static String _obtenerCategoriaCumplimiento(double porcentaje) {
    if (porcentaje >= 95) return 'Excelencia Operacional';
    if (porcentaje >= 85) return 'Alto Rendimiento';
    if (porcentaje >= 70) return 'Desempeño Satisfactorio';
    if (porcentaje >= 50) return 'Necesita Mejoras';
    if (porcentaje >= 25) return 'Requiere Atención';
    return 'Situación Crítica';
  }

  /// Obtiene el nivel textual (A+, A, B, C, D)
  static String _obtenerNivelTexto(double porcentaje) {
    if (porcentaje >= 95) return 'A+';
    if (porcentaje >= 85) return 'A';
    if (porcentaje >= 70) return 'B';
    if (porcentaje >= 50) return 'C';
    return 'D';
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

  // ==================== MÉTODOS AUXILIARES DE DISEÑO ====================

  /// Crea un separador visual con la línea roja característica
  static pw.Widget _crearSeparador({double width = 60}) {
    return pw.Container(
      height: 3,
      width: width,
      color: COLOR_ROJO_PRINCIPAL,
    );
  }

  /// Crea un badge o etiqueta con el estilo de la marca
  static pw.Widget _crearBadge(String texto, {PdfColor? colorFondo, PdfColor? colorTexto}) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: colorFondo ?? COLOR_NEGRO,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          color: colorTexto ?? PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// Crea un contenedor con el estilo de tarjeta estándar
  static pw.Widget _crearTarjeta({
    required pw.Widget child,
    pw.EdgeInsets? padding,
    PdfColor? colorBorde,
  }) {
    return pw.Container(
      padding: padding ?? pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: colorBorde ?? COLOR_GRIS_CLARO, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}