import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'admin_service.dart';
import 'package:image/image.dart' as img;

class PDFService {
  
  // ==================== CONFIGURACIÓN DE ITEMS POR TIPO ====================
  
  // Definir los items que existen para cada tipo de checklist
  static  Map<String, List<int>> ITEMS_POR_TIPO = {
    'fertirriego': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25], // 23 items, falta 12 y 19
    'bodega': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20], // 20 items
    'aplicaciones': List.generate(30, (index) => index + 1), // 30 items del 1 al 30
    'cosecha': List.generate(20, (index) => index + 1), // 20 items del 1 al 20
    'cosechas': List.generate(20, (index) => index + 1), // Alias para cosecha
    'cortes': List.generate(12, (index) => index + 1), // 12 items del 1 al 12
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
    bool obtenerDatosFrescos = false,
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
    
    // Si se solicita obtener datos frescos, hacer consulta al servidor
    Map<String, dynamic> datosParaPDF = recordData;
    if (obtenerDatosFrescos) {
      print('🔄 Obteniendo datos frescos del servidor...');
      try {
        datosParaPDF = await _obtenerDatosFrescosDelServidor(recordData, checklistType);
        print('✅ Datos frescos obtenidos exitosamente');
      } catch (e) {
        print('⚠️ Error obteniendo datos frescos, usando datos en caché: $e');
        // Continuar con los datos en caché si falla la consulta fresca
      }
    }
    
    // Obtener items relevantes (con observaciones, fotos o respuestas "NO")
    final List<Map<String, dynamic>> itemsRelevantes = _extraerItemsRelevantes(datosParaPDF, checklistType);
    final List<Map<String, dynamic>> itemsConFotos = itemsRelevantes.where((item) => item['tiene_foto'] == true).toList();
    
    // Página principal con información general
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        header: (context) => _construirHeader(tipoChecklist, datosParaPDF, bannerImage),
        footer: (context) => _construirFooter(context),
        build: (context) => [
          _construirInformacionGeneral(datosParaPDF, checklistType),
          pw.SizedBox(height: 20),
          // Solo mostrar porcentaje de cumplimiento para ciertos tipos de checklist
          if (checklistType.toLowerCase() != 'cortes' && 
              checklistType.toLowerCase() != 'labores_permanentes' && 
              checklistType.toLowerCase() != 'labores_temporales' &&
              checklistType.toLowerCase() != 'observaciones_adicionales') ...[
            _construirResumenCumplimiento(datosParaPDF),
            pw.SizedBox(height: 20),
          ],
          // Observaciones adicionales: sección dedicada
          if (checklistType.toLowerCase() == 'observaciones_adicionales') ...[
            _construirSeccionObservacionesAdicionales(datosParaPDF),
            pw.SizedBox(height: 20),
          ]
          // Mostrar items relevantes (otros tipos)
          else if (itemsRelevantes.isNotEmpty) ...[
            _construirSeccionItemsRelevantes(itemsRelevantes, checklistType),
            pw.SizedBox(height: 20),
          ],
          // Mostrar sección de fotografías si hay items con fotos (no aplica a observaciones_adicionales)
          if (checklistType.toLowerCase() != 'observaciones_adicionales' && itemsConFotos.isNotEmpty) ...[
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
    // Debug: verificar qué datos están llegando
    print('🔍 DEBUG PDF - Datos recibidos:');
    print('🔍 usuario_nombre: ${data['usuario_nombre']}');
    print('🔍 usuario_id: ${data['usuario_id']}');
    print('🔍 usuario_creacion: ${data['usuario_creacion']}');
    print('🔍 Todos los campos de usuario: ${data.keys.where((k) => k.contains('usuario')).toList()}');
    
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
          _construirFilaInfo('Kontroller:', _obtenerNombreUsuarioReal(data)),
          _construirFilaInfo('Finca:', data['finca_nombre'] ?? 'N/A'),
          
          // Campos específicos según tipo
          ..._construirCamposEspecificos(data, checklistType),
          
          _construirFilaInfo('Fecha de Auditoría:', _formatearFecha(data['fecha_creacion'])),
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
        
      case 'cortes':
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        if (data['variedad_nombre'] != null && data['variedad_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Variedad:', data['variedad_nombre'].toString()));
        }
        break;
      case 'observaciones_adicionales':
        if (data['bloque_nombre'] != null && data['bloque_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Bloque:', data['bloque_nombre'].toString()));
        }
        if (data['variedad_nombre'] != null && data['variedad_nombre'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Variedad:', data['variedad_nombre'].toString()));
        }
        if (data['tipo'] != null && data['tipo'].toString().isNotEmpty) {
          campos.add(_construirFilaInfo('Tipo de Observación:', data['tipo'].toString()));
        }
        // Datos MIPE si aplica
        if ((data['tipo']?.toString().toUpperCase() ?? '') == 'MIPE') {
          if (data['blanco_biologico'] != null && data['blanco_biologico'].toString().isNotEmpty) {
            campos.add(_construirFilaInfo('Blanco Biológico:', data['blanco_biologico'].toString()));
          }
          if (data['incidencia'] != null) {
            campos.add(_construirFilaInfo('Incidencia:', '${data['incidencia']}%'));
          }
          if (data['severidad'] != null) {
            campos.add(_construirFilaInfo('Severidad:', '${data['severidad']}%'));
          }
          if (data['tercio'] != null && data['tercio'].toString().isNotEmpty) {
            campos.add(_construirFilaInfo('Tercio:', data['tercio'].toString()));
          }
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

  static pw.Widget _construirSeccionItemsRelevantes(List<Map<String, dynamic>> items, String checklistType) {
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
            checklistType.toLowerCase() == 'cortes' ? 'EVALUACIONES POR MUESTRA' : 
            checklistType.toLowerCase() == 'labores_permanentes' ? 'EVALUACIONES POR PARADA' : 
            checklistType.toLowerCase() == 'labores_temporales' ? 'EVALUACIONES POR PARADA' : 
            'ITEMS RELEVANTES',
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
          
          // Lista de items, muestras o paradas
          if (checklistType.toLowerCase() == 'cortes')
            ...items.map((muestra) => _construirMuestraCortes(muestra)).toList()
          else if (checklistType.toLowerCase() == 'labores_permanentes')
            ...items.map((parada) => _construirParadaLaboresPermanentes(parada)).toList()
          else if (checklistType.toLowerCase() == 'labores_temporales')
            ...items.map((parada) => _construirParadaLaboresTemporales(parada)).toList()
          else
            ...items.map((item) => _construirItemRelevante(item, checklistType)).toList(),
        ],
      ),
    );
  }

  static pw.Widget _construirParadaLaboresTemporales(Map<String, dynamic> parada) {
    String nombreParada = parada['parada']?.toString() ?? '';
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(parada['items'] ?? []);
    int totalItems = parada['total_items'] ?? 0;
    int conformes = parada['conformes'] ?? 0;
    int noConformes = parada['no_conformes'] ?? 0;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 16),
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_MUY_CLARO,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header de la parada
          pw.Row(
            children: [
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: COLOR_ROJO_PRINCIPAL,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  nombreParada,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 8),
          
          // Lista de items de la parada
          ...items.map((item) => _construirItemParadaLaboresTemporales(item)).toList(),
        ],
      ),
    );
  }

  static pw.Widget _construirItemParadaLaboresTemporales(Map<String, dynamic> item) {
    int itemId = item['item_id'] ?? 0;
    String proceso = item['proceso']?.toString() ?? 'Item $itemId';
    String cuadranteParada = item['cuadrante_parada']?.toString() ?? '';
    String resultado = item['resultado']?.toString() ?? '';
    bool tieneFoto = item['tiene_foto'] == true;
    bool tieneObservaciones = item['tiene_observaciones'] == true;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 8),
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 0.5),
      ),
      child: pw.Row(
        children: [
          // Información del item
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Item $itemId: $proceso',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: COLOR_NEGRO,
                  ),
                ),
                if (cuadranteParada.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Cuadrante: $cuadranteParada',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: COLOR_GRIS_OSCURO,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Resultado
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: resultado == '0' ? COLOR_RESPUESTA_NO_FONDO : COLOR_RESPUESTA_SI_FONDO,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              resultado == '1' ? 'C' : 'NC',
              style: pw.TextStyle(
                color: resultado == '0' ? COLOR_RESPUESTA_NO : COLOR_RESPUESTA_SI,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          
          pw.SizedBox(width: 8),
          
          // Indicadores
          pw.Row(
            children: [
              if (tieneFoto) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_SI_FONDO,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'FOTO',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_SI,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
              ],
              if (tieneObservaciones) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_NA_FONDO,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'OBS',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_NA,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirParadaLaboresPermanentes(Map<String, dynamic> parada) {
    String nombreParada = parada['parada']?.toString() ?? '';
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(parada['items'] ?? []);
    int totalItems = parada['total_items'] ?? 0;
    int conformes = parada['conformes'] ?? 0;
    int noConformes = parada['no_conformes'] ?? 0;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 16),
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_MUY_CLARO,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header de la parada
          pw.Row(
            children: [
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: COLOR_ROJO_PRINCIPAL,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  nombreParada,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 8),
          
          // Lista de items de la parada
          ...items.map((item) => _construirItemParadaLaboresPermanentes(item)).toList(),
        ],
      ),
    );
  }

  static pw.Widget _construirItemParadaLaboresPermanentes(Map<String, dynamic> item) {
    int itemId = item['item_id'] ?? 0;
    String proceso = item['proceso']?.toString() ?? 'Item $itemId';
    String cuadranteParada = item['cuadrante_parada']?.toString() ?? '';
    String resultado = item['resultado']?.toString() ?? '';
    bool tieneFoto = item['tiene_foto'] == true;
    bool tieneObservaciones = item['tiene_observaciones'] == true;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 8),
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 0.5),
      ),
      child: pw.Row(
        children: [
          // Información del item
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Item $itemId: $proceso',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: COLOR_NEGRO,
                  ),
                ),
                if (cuadranteParada.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Cuadrante: $cuadranteParada',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: COLOR_GRIS_OSCURO,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Resultado
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: resultado == '0' ? COLOR_RESPUESTA_NO_FONDO : COLOR_RESPUESTA_SI_FONDO,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              resultado == '1' ? 'C' : 'NC',
              style: pw.TextStyle(
                color: resultado == '0' ? COLOR_RESPUESTA_NO : COLOR_RESPUESTA_SI,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          
          pw.SizedBox(width: 8),
          
          // Indicadores
          pw.Row(
            children: [
              if (tieneFoto) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_SI_FONDO,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'FOTO',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_SI,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
              ],
              if (tieneObservaciones) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_NA_FONDO,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'OBS',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_NA,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirMuestraCortes(Map<String, dynamic> muestra) {
    String nombreMuestra = muestra['muestra']?.toString() ?? '';
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(muestra['items'] ?? []);
    int totalItems = muestra['total_items'] ?? 0;
    int conformes = muestra['conformes'] ?? 0;
    int noConformes = muestra['no_conformes'] ?? 0;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 16),
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_MUY_CLARO,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header de la muestra
          pw.Row(
            children: [
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: COLOR_ROJO_PRINCIPAL,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  nombreMuestra,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          pw.SizedBox(height: 8),
          
          // Lista de items de la muestra
          ...items.map((item) => _construirItemMuestraCortes(item)).toList(),
        ],
      ),
    );
  }

  static pw.Widget _construirItemMuestraCortes(Map<String, dynamic> item) {
    int itemId = item['item_id'] ?? 0;
    String proceso = item['proceso']?.toString() ?? 'Item $itemId';
    String cuadrante = item['cuadrante']?.toString() ?? '';
    String resultado = item['resultado']?.toString() ?? '';
    bool tieneFoto = item['tiene_foto'] == true;
    bool tieneObservaciones = item['tiene_observaciones'] == true;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 8),
      padding: pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 0.5),
      ),
      child: pw.Row(
        children: [
          // Información del item
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Item $itemId: $proceso',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: COLOR_NEGRO,
                  ),
                ),
                if (cuadrante.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Cuadrante: $cuadrante',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: COLOR_GRIS_OSCURO,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Resultado
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: resultado == 'NC' ? COLOR_RESPUESTA_NO_FONDO : COLOR_RESPUESTA_SI_FONDO,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              resultado,
              style: pw.TextStyle(
                color: resultado == 'NC' ? COLOR_RESPUESTA_NO : COLOR_RESPUESTA_SI,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          
          pw.SizedBox(width: 8),
          
          // Indicadores
          pw.Row(
            children: [
              if (tieneFoto) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_SI_FONDO,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'FOTO',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_SI,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
              ],
              if (tieneObservaciones) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_NA_FONDO,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'OBS',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_NA,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirItemRelevante(Map<String, dynamic> item, String checklistType) {
    String numero = item['numero']?.toString() ?? '';
    String proceso = item['proceso']?.toString() ?? 'Item $numero';
    String? respuesta = item['respuesta'];
    String? observaciones = item['observaciones'];
    bool tieneFoto = item['tiene_foto'] == true;
    bool tieneNoConformes = item['tiene_no_conformes'] == true;
    
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 12),
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: COLOR_GRIS_MUY_CLARO,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header del item
          pw.Row(
            children: [
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: COLOR_ROJO_PRINCIPAL,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'Item $numero',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  proceso,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: COLOR_NEGRO,
                  ),
                ),
              ),
              // Indicadores
              if (tieneFoto) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_SI_FONDO,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'FOTO',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_SI,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 4),
              ],
              if (tieneNoConformes) ...[
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: COLOR_RESPUESTA_NO_FONDO,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'NC',
                    style: pw.TextStyle(
                      color: COLOR_RESPUESTA_NO,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          // Respuesta si existe
          if (respuesta != null && respuesta.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Text(
                  'Respuesta: ',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: COLOR_GRIS_OSCURO,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Container(
                  padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: respuesta.toLowerCase() == 'nc' || respuesta.toLowerCase() == 'no' 
                        ? COLOR_RESPUESTA_NO_FONDO 
                        : COLOR_RESPUESTA_SI_FONDO,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    respuesta.toUpperCase(),
                    style: pw.TextStyle(
                      color: respuesta.toLowerCase() == 'nc' || respuesta.toLowerCase() == 'no' 
                          ? COLOR_RESPUESTA_NO 
                          : COLOR_RESPUESTA_SI,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Observaciones si existen
          if (observaciones != null && observaciones.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Observaciones:',
              style: pw.TextStyle(
                fontSize: 10,
                color: COLOR_GRIS_OSCURO,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              observaciones,
              style: pw.TextStyle(
                fontSize: 10,
                color: COLOR_NEGRO,
              ),
            ),
          ],
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

  static const int _MAX_FOTOS_PDF = 36; // limitar fotos para evitar TooManyPagesException

  static pw.Widget _construirSeccionFotografias(List<Map<String, dynamic>> itemsConFotos) {
    final int total = itemsConFotos.length;
    final List<Map<String, dynamic>> fotosLimitadas =
        itemsConFotos.take(_MAX_FOTOS_PDF).toList();
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
        
        ...fotosLimitadas.map((item) => _construirSeccionFoto(item)).toList(),
        if (total > _MAX_FOTOS_PDF) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: COLOR_ROJO_CLARO,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: COLOR_ROJO_PRINCIPAL, width: 0.5),
            ),
            child: pw.Text(
              'Se omitieron ${total - _MAX_FOTOS_PDF} imágenes para mantener el tamaño del documento.',
              style: pw.TextStyle(fontSize: 10, color: COLOR_NEGRO),
            ),
          )
        ]
      ],
    );
  }

  // Optimización de imágenes para reducir consumo de memoria en el PDF
  static Uint8List _optimizeImageBytes(Uint8List bytes, {int maxDimension = 1280, int jpegQuality = 70}) {
    try {
      final img.Image? original = img.decodeImage(bytes);
      if (original == null) return bytes; // fallback

      int w = original.width;
      int h = original.height;

      // Redimensionar manteniendo proporción si excede maxDimension
      if (w > maxDimension || h > maxDimension) {
        final img.Image resized = img.copyResize(
          original,
          width: w >= h ? maxDimension : (w * maxDimension / h).round(),
          height: h > w ? maxDimension : (h * maxDimension / w).round(),
          interpolation: img.Interpolation.cubic,
        );
        return Uint8List.fromList(img.encodeJpg(resized, quality: jpegQuality));
      }

      // Si es PNG grande, convertir a JPG para ahorrar
      return Uint8List.fromList(img.encodeJpg(original, quality: jpegQuality));
    } catch (_) {
      return bytes; // En caso de error, usar bytes originales
    }
  }

  // ==================== SECCIÓN ESPECIAL: OBSERVACIONES ADICIONALES ====================
  static pw.Widget _construirSeccionObservacionesAdicionales(Map<String, dynamic> data) {
    final String observacion = (data['observacion'] ?? '').toString();
    final String tipo = (data['tipo'] ?? '').toString();
    final bool esMIPE = tipo.toUpperCase() == 'MIPE';

    List<pw.Widget> children = [];

    // Título
    children.add(
      pw.Text(
        'OBSERVACIONES ADICIONALES',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: COLOR_NEGRO),
      ),
    );
    children.add(pw.SizedBox(height: 4));
    children.add(
      pw.Container(height: 3, width: 80, color: COLOR_ROJO_PRINCIPAL),
    );
    children.add(pw.SizedBox(height: 12));

    // Tipo
    if (tipo.isNotEmpty) {
      children.add(_construirFilaInfo('Tipo:', tipo));
    }

    // MIPE extra
    if (esMIPE) {
      if (data['blanco_biologico'] != null && data['blanco_biologico'].toString().isNotEmpty) {
        children.add(_construirFilaInfo('Blanco Biológico:', data['blanco_biologico'].toString()));
      }
      if (data['incidencia'] != null) {
        children.add(_construirFilaInfo('Incidencia:', '${data['incidencia']}%'));
      }
      if (data['severidad'] != null) {
        children.add(_construirFilaInfo('Severidad:', '${data['severidad']}%'));
      }
      if (data['tercio'] != null && data['tercio'].toString().isNotEmpty) {
        children.add(_construirFilaInfo('Tercio:', data['tercio'].toString()));
      }
      children.add(pw.SizedBox(height: 8));
    }

    // Observación
    children.add(
      pw.Container(
        padding: pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: COLOR_GRIS_MUY_CLARO,
          border: pw.Border.all(color: COLOR_GRIS_CLARO, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Observación:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: COLOR_GRIS_OSCURO)),
            pw.SizedBox(height: 6),
            pw.Text(
              observacion.isEmpty ? 'N/A' : observacion,
              style: pw.TextStyle(fontSize: 11, color: COLOR_NEGRO),
            ),
          ],
        ),
      ),
    );

    // Fotografías (si existen)
    final fotos = _obtenerItemsConFotos(data, 'observaciones_adicionales');
    if (fotos.isNotEmpty) {
      children.add(pw.SizedBox(height: 16));
      children.add(_construirSeccionFotografias(fotos));
    }

    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: COLOR_GRIS_MEDIO, width: 1.5),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
    );
  }

  static pw.Widget _construirSeccionFoto(Map<String, dynamic> item) {
    try {
      final Uint8List rawBytes = base64Decode(item['foto_base64']);
      final Uint8List imageBytes = _optimizeImageBytes(rawBytes, maxDimension: 1280, jpegQuality: 70);
      
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
                    (item['numero']?.toString() == 'OBS') ? 'Observación' : 'Item ${item['numero']}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (item['observaciones'] != null && item['observaciones'].toString().isNotEmpty) ...[
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
    // Caso especial para observaciones adicionales: no usa items; secciones propias
    if (checklistType.toLowerCase() == 'observaciones_adicionales') {
      return [];
    }
    
    print('🔍 DEBUG: Tipo de checklist recibido: "$checklistType"');
    print('🔍 DEBUG: Tipo en minúsculas: "${checklistType.toLowerCase()}"');
    print('🔍 DEBUG: ¿Es cortes? ${checklistType.toLowerCase() == 'cortes'}');
    
    // Caso especial para cortes que usa JSON
    if (checklistType.toLowerCase() == 'cortes') {
      print('✅ Ejecutando lógica específica para cortes');
      return _extraerItemsRelevantesCortes(data);
    }
    
    // Caso especial para labores permanentes que usa JSON
    if (checklistType.toLowerCase() == 'labores_permanentes') {
      print('✅ Ejecutando lógica específica para labores permanentes');
      return _extraerItemsRelevantesLaboresPermanentes(data);
    }
    
    // Caso especial para labores temporales que usa JSON
    if (checklistType.toLowerCase() == 'labores_temporales') {
      print('✅ Ejecutando lógica específica para labores temporales');
      return _extraerItemsRelevantesLaboresTemporales(data);
    }
    
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

  /// Extrae items relevantes específicamente para labores temporales desde JSON
  /// Organiza los datos por parada en lugar de por item
  static List<Map<String, dynamic>> _extraerItemsRelevantesLaboresTemporales(Map<String, dynamic> data) {
    List<Map<String, dynamic>> paradas = [];
    
    try {
      // Obtener el JSON de items
      String? itemsJson = data['items_json'];
      if (itemsJson == null || itemsJson.isEmpty) {
        print('⚠️ No se encontró items_json en los datos de labores temporales');
        return paradas;
      }
      
      print('🔍 JSON de items encontrado: ${itemsJson.length} caracteres');
      print('🔍 Primeros 200 caracteres: ${itemsJson.substring(0, itemsJson.length > 200 ? 200 : itemsJson.length)}');
      
      // Parsear el JSON
      List<dynamic> itemsList = jsonDecode(itemsJson);
      print('📋 Procesando ${itemsList.length} items de labores temporales desde JSON');
      
      // Agrupar por número de parada
      Map<String, List<Map<String, dynamic>>> paradasPorNumero = {};
      
      for (int i = 0; i < itemsList.length; i++) {
        Map<String, dynamic> itemData = itemsList[i];
        int itemId = itemData['id'] ?? (i + 1);
        String proceso = itemData['proceso'] ?? 'Item $itemId';
        String? observaciones = itemData['observaciones'];
        String? fotoBase64 = itemData['fotoBase64'];
        
        Map<String, dynamic>? resultadosPorCuadranteParada = itemData['resultadosPorCuadranteParada'];
        if (resultadosPorCuadranteParada == null) continue;
        
        // Procesar cada cuadrante y parada
        resultadosPorCuadranteParada.forEach((cuadranteParadaId, paradasData) {
          if (paradasData is Map<String, dynamic>) {
            paradasData.forEach((paradaNum, resultado) {
              String paradaKey = 'Parada $paradaNum';
              if (!paradasPorNumero.containsKey(paradaKey)) {
                paradasPorNumero[paradaKey] = [];
              }
              
              paradasPorNumero[paradaKey]!.add({
                'item_id': itemId,
                'proceso': proceso,
                'cuadrante_parada': cuadranteParadaId,
                'parada': paradaNum,
                'resultado': resultado,
                'observaciones': observaciones,
                'foto_base64': fotoBase64,
                'tiene_foto': fotoBase64 != null && fotoBase64.isNotEmpty,
                'tiene_observaciones': observaciones != null && observaciones.trim().isNotEmpty,
              });
            });
          }
        });
      }
      
      // Convertir a lista de paradas
      paradasPorNumero.forEach((paradaKey, items) {
        if (items.isNotEmpty) {
          paradas.add({
            'parada': paradaKey,
            'items': items,
            'total_items': items.length,
            'conformes': items.where((item) => item['resultado'] == '1').length,
            'no_conformes': items.where((item) => item['resultado'] == '0').length,
          });
        }
      });
      
      // Ordenar por número de parada
      paradas.sort((a, b) {
        String paradaA = a['parada'].toString();
        String paradaB = b['parada'].toString();
        int numA = int.tryParse(paradaA.replaceAll('Parada ', '')) ?? 0;
        int numB = int.tryParse(paradaB.replaceAll('Parada ', '')) ?? 0;
        return numA.compareTo(numB);
      });
      
    } catch (e) {
      print('❌ Error al procesar items JSON de labores temporales: $e');
    }
    
    print('📊 Total paradas de labores temporales encontradas: ${paradas.length}');
    return paradas;
  }

  /// Extrae items relevantes específicamente para labores permanentes desde JSON
  /// Organiza los datos por parada en lugar de por item
  static List<Map<String, dynamic>> _extraerItemsRelevantesLaboresPermanentes(Map<String, dynamic> data) {
    List<Map<String, dynamic>> paradas = [];
    
    try {
      // Obtener el JSON de items
      String? itemsJson = data['items_json'];
      if (itemsJson == null || itemsJson.isEmpty) {
        print('⚠️ No se encontró items_json en los datos de labores permanentes');
        return paradas;
      }
      
      print('🔍 JSON de items encontrado: ${itemsJson.length} caracteres');
      print('🔍 Primeros 200 caracteres: ${itemsJson.substring(0, itemsJson.length > 200 ? 200 : itemsJson.length)}');
      
      // Parsear el JSON
      List<dynamic> itemsList = jsonDecode(itemsJson);
      print('📋 Procesando ${itemsList.length} items de labores permanentes desde JSON');
      
      // Agrupar por número de parada
      Map<String, List<Map<String, dynamic>>> paradasPorNumero = {};
      
      for (int i = 0; i < itemsList.length; i++) {
        Map<String, dynamic> itemData = itemsList[i];
        int itemId = itemData['id'] ?? (i + 1);
        String proceso = itemData['proceso'] ?? 'Item $itemId';
        String? observaciones = itemData['observaciones'];
        String? fotoBase64 = itemData['fotoBase64'];
        
        Map<String, dynamic>? resultadosPorCuadranteParada = itemData['resultadosPorCuadranteParada'];
        if (resultadosPorCuadranteParada == null) continue;
        
        // Procesar cada cuadrante y parada
        resultadosPorCuadranteParada.forEach((cuadranteParadaId, paradasData) {
          if (paradasData is Map<String, dynamic>) {
            paradasData.forEach((paradaNum, resultado) {
              String paradaKey = 'Parada $paradaNum';
              if (!paradasPorNumero.containsKey(paradaKey)) {
                paradasPorNumero[paradaKey] = [];
              }
              
              paradasPorNumero[paradaKey]!.add({
                'item_id': itemId,
                'proceso': proceso,
                'cuadrante_parada': cuadranteParadaId,
                'parada': paradaNum,
                'resultado': resultado,
                'observaciones': observaciones,
                'foto_base64': fotoBase64,
                'tiene_foto': fotoBase64 != null && fotoBase64.isNotEmpty,
                'tiene_observaciones': observaciones != null && observaciones.trim().isNotEmpty,
              });
            });
          }
        });
      }
      
      // Convertir a lista de paradas
      paradasPorNumero.forEach((paradaKey, items) {
        if (items.isNotEmpty) {
          paradas.add({
            'parada': paradaKey,
            'items': items,
            'total_items': items.length,
            'conformes': items.where((item) => item['resultado'] == '1').length,
            'no_conformes': items.where((item) => item['resultado'] == '0').length,
          });
        }
      });
      
      // Ordenar por número de parada
      paradas.sort((a, b) {
        String paradaA = a['parada'].toString();
        String paradaB = b['parada'].toString();
        int numA = int.tryParse(paradaA.replaceAll('Parada ', '')) ?? 0;
        int numB = int.tryParse(paradaB.replaceAll('Parada ', '')) ?? 0;
        return numA.compareTo(numB);
      });
      
    } catch (e) {
      print('❌ Error al procesar items JSON de labores permanentes: $e');
    }
    
    print('📊 Total paradas de labores permanentes encontradas: ${paradas.length}');
    return paradas;
  }

  /// Extrae items relevantes específicamente para cortes desde JSON
  /// Organiza los datos por muestra en lugar de por item
  static List<Map<String, dynamic>> _extraerItemsRelevantesCortes(Map<String, dynamic> data) {
    List<Map<String, dynamic>> muestras = [];
    
    try {
      // Obtener el JSON de items
      String? itemsJson = data['items_json'];
      if (itemsJson == null || itemsJson.isEmpty) {
        print('⚠️ No se encontró items_json en los datos de cortes');
        return muestras;
      }
      
      print('🔍 JSON de items encontrado: ${itemsJson.length} caracteres');
      print('🔍 Primeros 200 caracteres: ${itemsJson.substring(0, itemsJson.length > 200 ? 200 : itemsJson.length)}');
      
      // Parsear el JSON
      List<dynamic> itemsList = jsonDecode(itemsJson);
      print('📋 Procesando ${itemsList.length} items de cortes desde JSON');
      
      // Agrupar por número de muestra
      Map<String, List<Map<String, dynamic>>> muestrasPorNumero = {};
      
      for (int i = 0; i < itemsList.length; i++) {
        Map<String, dynamic> itemData = itemsList[i];
        int itemId = itemData['id'] ?? (i + 1);
        String proceso = itemData['proceso'] ?? 'Item $itemId';
        String? observaciones = itemData['observaciones'];
        String? fotoBase64 = itemData['fotoBase64'];
        
        Map<String, dynamic>? resultadosPorCuadrante = itemData['resultadosPorCuadrante'];
        if (resultadosPorCuadrante == null) continue;
        
        // Procesar cada cuadrante y muestra
        resultadosPorCuadrante.forEach((cuadranteId, muestrasData) {
          if (muestrasData is Map<String, dynamic>) {
            muestrasData.forEach((muestraNum, resultado) {
              String muestraKey = 'Muestra $muestraNum';
              if (!muestrasPorNumero.containsKey(muestraKey)) {
                muestrasPorNumero[muestraKey] = [];
              }
              
              muestrasPorNumero[muestraKey]!.add({
                'item_id': itemId,
                'proceso': proceso,
                'cuadrante': cuadranteId,
                'muestra': muestraNum,
                'resultado': resultado,
                'observaciones': observaciones,
                'foto_base64': fotoBase64,
                'tiene_foto': fotoBase64 != null && fotoBase64.isNotEmpty,
                'tiene_observaciones': observaciones != null && observaciones.trim().isNotEmpty,
              });
            });
          }
        });
      }
      
      // Convertir a lista de muestras
      muestrasPorNumero.forEach((muestraKey, items) {
        if (items.isNotEmpty) {
          muestras.add({
            'muestra': muestraKey,
            'items': items,
            'total_items': items.length,
            'conformes': items.where((item) => item['resultado'] == 'C').length,
            'no_conformes': items.where((item) => item['resultado'] == 'NC').length,
          });
        }
      });
      
      // Ordenar por número de muestra
      muestras.sort((a, b) {
        String muestraA = a['muestra'].toString();
        String muestraB = b['muestra'].toString();
        int numA = int.tryParse(muestraA.replaceAll('Muestra ', '')) ?? 0;
        int numB = int.tryParse(muestraB.replaceAll('Muestra ', '')) ?? 0;
        return numA.compareTo(numB);
      });
      
    } catch (e) {
      print('❌ Error al procesar items JSON de cortes: $e');
    }
    
    print('📊 Total muestras de cortes encontradas: ${muestras.length}');
    return muestras;
  }
  
  /// Verifica si un item de cortes tiene evaluaciones (resultados en la matriz)
  static bool _tieneEvaluacionesCortes(Map<String, dynamic> itemData) {
    try {
      Map<String, dynamic>? resultadosPorCuadrante = itemData['resultadosPorCuadrante'];
      if (resultadosPorCuadrante == null) {
        print('🔍 No hay resultadosPorCuadrante en el item');
        return false;
      }
      
      // Verificar si hay algún cuadrante con evaluaciones
      for (String cuadrante in resultadosPorCuadrante.keys) {
        dynamic muestrasData = resultadosPorCuadrante[cuadrante];
        if (muestrasData == null) continue;
        
        // Convertir a Map<String, dynamic> ya que JSON parsea las claves como strings
        Map<String, dynamic> muestras = Map<String, dynamic>.from(muestrasData);
        
        // Si hay al menos una muestra con resultado, tiene evaluaciones
        if (muestras.isNotEmpty) {
          print('🔍 Item tiene evaluaciones en cuadrante $cuadrante: ${muestras.length} muestras');
          return true;
        }
      }
      
      print('🔍 Item no tiene evaluaciones');
      return false;
    } catch (e) {
      print('❌ Error al verificar evaluaciones: $e');
      return false;
    }
  }

  /// Verifica si un item de cortes tiene resultados no conformes en la matriz
  static bool _verificarNoConformesCortes(Map<String, dynamic> itemData) {
    try {
      Map<String, dynamic>? resultadosPorCuadrante = itemData['resultadosPorCuadrante'];
      if (resultadosPorCuadrante == null) {
        print('🔍 No hay resultadosPorCuadrante en el item');
        return false;
      }
      
      print('🔍 Verificando no conformes en ${resultadosPorCuadrante.keys.length} cuadrantes');
      
      // Verificar cada cuadrante
      for (String cuadrante in resultadosPorCuadrante.keys) {
        dynamic muestrasData = resultadosPorCuadrante[cuadrante];
        if (muestrasData == null) continue;
        
        // Convertir a Map<String, dynamic> ya que JSON parsea las claves como strings
        Map<String, dynamic> muestras = Map<String, dynamic>.from(muestrasData);
        
        print('🔍 Cuadrante $cuadrante: ${muestras.keys.length} muestras');
        
        // Verificar cada muestra
        for (String muestraKey in muestras.keys) {
          String? resultado = muestras[muestraKey]?.toString();
          print('🔍 Muestra $muestraKey: $resultado');
          if (resultado != null && (resultado.toLowerCase() == 'nc' || resultado == '0')) {
            print('🔍 ¡Encontrado no conforme! Muestra $muestraKey = $resultado');
            return true; // Encontró al menos un no conforme
          }
        }
      }
      
      print('🔍 No se encontraron no conformes');
      return false;
    } catch (e) {
      print('❌ Error al verificar no conformes: $e');
      return false;
    }
  }

  static List<Map<String, dynamic>> _obtenerItemsConFotos(Map<String, dynamic> data, String checklistType) {
    if (checklistType.toLowerCase() == 'observaciones_adicionales') {
      // Observaciones adicionales: imagenes_json puede ser string JSON, lista, o base64 plano
      try {
        final imgs = data['imagenes_json'];
        if (imgs == null) return [];
        List<String> list = [];
        if (imgs is String) {
          try {
            final parsed = jsonDecode(imgs);
            if (parsed is List) {
              for (final e in parsed) {
                if (e is String && e.trim().isNotEmpty) list.add(e.trim());
                if (e is Map) {
                  final cand = (e['base64'] ?? e['fotoBase64'] ?? e['data'] ?? e['src'] ?? '').toString();
                  if (cand.trim().isNotEmpty) list.add(cand.trim());
                }
              }
            }
          } catch (_) {
            final s = imgs.trim();
            final looksB64 = s.length > 100 && RegExp(r'^[A-Za-z0-9+/=\s]+').hasMatch(s);
            if (looksB64) list = [s];
          }
        } else if (imgs is List) {
          for (final e in imgs) {
            if (e is String && e.trim().isNotEmpty) list.add(e.trim());
            if (e is Map) {
              final cand = (e['base64'] ?? e['fotoBase64'] ?? e['data'] ?? e['src'] ?? '').toString();
              if (cand.trim().isNotEmpty) list.add(cand.trim());
            }
          }
        }
        return list
            .map<Map<String, dynamic>>((e) => {
                  'numero': 'OBS',
                  'observaciones': data['observacion'] ?? '',
                  'foto_base64': e,
                  'tiene_foto': true,
                })
            .toList();
      } catch (_) {}
      return [];
    }
    return _extraerItemsRelevantes(data, checklistType).where((item) => item['tiene_foto'] == true).toList();
  }

  static String _formatearFecha(String? fechaString) {
    if (fechaString == null || fechaString.isEmpty) return 'N/A';
    
    try {
      DateTime fechaUTC = DateTime.parse(fechaString);
      
      // Ajusta a la zona horaria de Ecuador (UTC-5)
      DateTime fechaLocal = fechaUTC.subtract(const Duration(hours: 5));
      
      // Formatea la fecha ya ajustada
      // Evitar fallo si no se inicializó la localización
      try {
        return DateFormat('dd/MM/yyyy HH:mm:ss', 'es_EC').format(fechaLocal);
      } catch (_) {
        return DateFormat('dd/MM/yyyy HH:mm:ss').format(fechaLocal);
      }

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
      case 'cortes':
        return 'Cortes';
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

  // ==================== MÉTODO PARA OBTENER NOMBRE REAL DEL USUARIO ====================
  
  static String _obtenerNombreUsuarioReal(Map<String, dynamic> data) {
    print('🔍 DEBUG PDF - Datos recibidos para nombre:');
    print('🔍 usuario_id: ${data['usuario_id']}');
    print('🔍 usuario_nombre: ${data['usuario_nombre']}');
    print('🔍 usuario_creacion: ${data['usuario_creacion']}');
    print('🔍 kontroller: ${data['kontroller']}');
    
    // PRIORIDAD 1: Si hay columna kontroller, usarla directamente
    if (data['kontroller'] != null && 
        data['kontroller'].toString().trim().isNotEmpty &&
        data['kontroller'] != 'usuario_actual') {
      print('🔍 DEBUG PDF - Usando kontroller: ${data['kontroller']}');
      return data['kontroller'].toString();
    }
    
    // PRIORIDAD 2: Si usuario_nombre es un nombre completo (contiene espacio)
    if (data['usuario_nombre'] != null && 
        data['usuario_nombre'].toString().contains(' ') &&
        data['usuario_nombre'] != 'usuario_actual') {
      print('🔍 DEBUG PDF - Usando usuario_nombre completo: ${data['usuario_nombre']}');
      return data['usuario_nombre'].toString();
    }
    
    // PRIORIDAD 3: Intentar obtener desde mapeo manual
    String username = data['usuario_id'] ?? data['usuario_nombre'] ?? data['usuario_creacion'] ?? '';
    
    if (username.isEmpty) {
      return 'N/A';
    }
    
    print('🔍 DEBUG PDF - Username detectado: "$username"');
    
    // Mapeo manual de usernames conocidos
    String nombreReal = _obtenerNombreUsuarioDesdeBD(username);
    print('🔍 DEBUG PDF - Nombre real obtenido: "$nombreReal"');
    return nombreReal;
  }
  
  static String _obtenerNombreUsuarioDesdeBD(String username) {
    // Esta función se ejecutará de forma síncrona
    // En un entorno real, esto debería ser async, pero para el PDF necesitamos síncrono
    
    // Por ahora, retornar el username como fallback
    // En una implementación real, aquí harías una consulta a la base de datos
    print('🔍 Intentando obtener nombre real para username: $username');
    
    // Mapeo manual de usernames conocidos (solución temporal)
    Map<String, String> nombresReales = {
      'admin': 'Belen Escobar',
      'usuario1': 'Usuario Uno',
      'usuario_actual': 'Belen Escobar', // Para labores temporales y permanentes
      'BMunoz': 'Bryan Muñoz', // Mapeo específico para el usuario BMunoz
      // Agregar más mapeos según sea necesario
    };
    
    return nombresReales[username] ?? username;
  }
  
  // ==================== MÉTODO PARA OBTENER DATOS FRESCOS DEL SERVIDOR ====================
  
  static Future<Map<String, dynamic>> _obtenerDatosFrescosDelServidor(
    Map<String, dynamic> recordData, 
    String checklistType
  ) async {
    try {
      // Obtener el ID del registro para hacer la consulta específica
      int? recordId = recordData['id'];
      if (recordId == null) {
        throw Exception('No se pudo obtener el ID del registro');
      }
      
      print('🔍 Obteniendo datos frescos para registro ID: $recordId, tipo: $checklistType');
      
      // Obtener datos frescos según el tipo de checklist
      Map<String, dynamic> resultado;
      switch (checklistType.toLowerCase()) {
        case 'labores_temporales':
          resultado = await AdminService.getLaboresTemporalesRecords();
          break;
        case 'labores_permanentes':
          resultado = await AdminService.getLaboresPermanentesRecords();
          break;
        case 'cortes':
          resultado = await AdminService.getCortesRecords();
          break;
        case 'observaciones_adicionales':
          resultado = await AdminService.getObservacionesAdicionalesRecords();
          break;
        default:
          throw Exception('Tipo de checklist no soportado para datos frescos: $checklistType');
      }
      
      // Buscar el registro específico por ID
      List<dynamic> records = resultado['records'] ?? [];
      Map<String, dynamic>? recordFresco;
      
      try {
        recordFresco = records.firstWhere(
          (record) => record['id'] == recordId,
        );
      } catch (e) {
        recordFresco = null;
      }
      
      if (recordFresco == null) {
        throw Exception('No se encontró el registro con ID $recordId en los datos frescos');
      }
      
      print('✅ Registro fresco encontrado: ${recordFresco['usuario_nombre']}');
      return recordFresco;
      
    } catch (e) {
      print('❌ Error obteniendo datos frescos: $e');
      rethrow;
    }
  }
}