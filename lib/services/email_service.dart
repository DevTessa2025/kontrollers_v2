import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:typed_data';

class EmailService {
  // Configuración del servidor SMTP
  static const String _smtpServer = 'mail.tessacorporation.com';
  static const int _smtpPort = 587;
  static const String _senderEmail = 'reportes.kontrollers@tessacorporation.com';
  static const String _password = 'Kontrollers2025\$\$**';
  
  /// Envía un correo con el reporte PDF adjunto
  static Future<Map<String, dynamic>> enviarReporteChecklist({
    required String destinatario,
    required String checklistType,
    required int recordId,
    required Uint8List pdfBytes,
    String? observaciones,
  }) async {
    try {
      // Configurar servidor SMTP
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _password,
        ssl: false,
        allowInsecure: false,
      );

      // Crear el asunto y cuerpo del mensaje
      final String asunto = _generarAsunto(checklistType, recordId);
      final String cuerpoMensaje = _generarCuerpoMensaje(
        checklistType, 
        recordId, 
        observaciones
      );
      
      // Crear mensaje con PDF adjunto usando StreamAttachment
      final message = Message()
        ..from = Address(_senderEmail, 'Sistema Kontrollers - Reportes')
        ..recipients.add(Address(destinatario))
        ..subject = asunto
        ..text = cuerpoMensaje
        ..html = _generarCuerpoHTML(checklistType, recordId, observaciones)
        ..attachments = [
          StreamAttachment(
            Stream.fromIterable([pdfBytes]),
            'application/pdf',
            fileName: _generarNombrePDF(checklistType, recordId),
          ),
        ];

      // Enviar correo
      final sendReport = await send(message, smtpServer);
      
      print('Reporte de envío: ${sendReport.toString()}');
      
      return {
        'exito': true,
        'mensaje': 'Reporte enviado exitosamente a $destinatario',
        'detalles': sendReport.toString(),
      };
    } catch (e) {
      print('Error al enviar correo: $e');
      return {
        'exito': false,
        'mensaje': 'Error al enviar correo: $e',
        'error': e.toString(),
      };
    }
  }

  /// Envía un correo simple sin adjuntos
  static Future<Map<String, dynamic>> enviarCorreoSimple({
    required String destinatario,
    required String asunto,
    required String cuerpoMensaje,
    String? cuerpoHTML,
  }) async {
    try {
      final smtpServer = SmtpServer(
        _smtpServer,
        port: _smtpPort,
        username: _senderEmail,
        password: _password,
        ssl: false,
        allowInsecure: false,
      );

      final message = Message()
        ..from = Address(_senderEmail, 'Sistema Kontrollers')
        ..recipients.add(Address(destinatario))
        ..subject = asunto
        ..text = cuerpoMensaje;

      if (cuerpoHTML != null) {
        message.html = cuerpoHTML;
      }

      final sendReport = await send(message, smtpServer);
      
      return {
        'exito': true,
        'mensaje': 'Correo enviado exitosamente',
        'detalles': sendReport.toString(),
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error al enviar correo: $e',
        'error': e.toString(),
      };
    }
  }

  // ==================== MÉTODOS PRIVADOS ====================

  static String _generarAsunto(String checklistType, int recordId) {
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final String fecha = DateTime.now().toString().substring(0, 10);
    
    return 'Reporte de $tipoChecklist - ID: $recordId - $fecha';
  }

  static String _generarCuerpoMensaje(String checklistType, int recordId, String? observaciones) {
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final String fecha = DateTime.now().toString().substring(0, 19);
    
    String mensaje = '''
Estimado/a usuario/a,

Se adjunta el reporte detallado del checklist de $tipoChecklist correspondiente al registro ID: $recordId.

INFORMACIÓN DEL REPORTE:
- Tipo de Checklist: $tipoChecklist
- ID del Registro: $recordId
- Fecha de Generación: $fecha
- Generado por: Sistema Kontrollers

El archivo PDF adjunto contiene:
✓ Información general del checklist
✓ Detalles de todos los items completados
✓ Valores numéricos registrados
✓ Observaciones de campo
✓ Fotografías adjuntas (si las hay)
✓ Porcentaje de cumplimiento
''';

    if (observaciones != null && observaciones.isNotEmpty) {
      mensaje += '\nOBSERVACIONES ADICIONALES:\n$observaciones\n';
    }

    mensaje += '''

Este reporte ha sido generado automáticamente por el Sistema Kontrollers.
Para cualquier consulta o aclaración, por favor contacte al administrador del sistema.

Saludos cordiales,
Sistema Kontrollers
Tessa Corporation
''';

    return mensaje;
  }

  static String _generarCuerpoHTML(String checklistType, int recordId, String? observaciones) {
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final String fecha = DateTime.now().toString().substring(0, 19);
    final String colorTema = _obtenerColorTema(checklistType);

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .header { background: linear-gradient(135deg, $colorTema, ${colorTema}AA); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .logo { font-size: 24px; font-weight: bold; margin-bottom: 10px; }
        .info-box { background: #f8f9fa; border-left: 4px solid $colorTema; padding: 15px; margin: 15px 0; }
        .checklist-details { background: white; border: 1px solid #ddd; border-radius: 8px; padding: 20px; }
        .footer { background: #f1f1f1; padding: 15px; border-radius: 8px; margin-top: 20px; font-size: 12px; color: #666; }
        .highlight { color: $colorTema; font-weight: bold; }
        ul { padding-left: 20px; }
        li { margin: 5px 0; }
        .attachment-note { background: #e3f2fd; border: 1px solid #2196f3; border-radius: 4px; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo">📊 Sistema Kontrollers</div>
        <div>Reporte de Checklist - $tipoChecklist</div>
    </div>

    <div class="checklist-details">
        <h2>📋 Información del Reporte</h2>
        
        <div class="info-box">
            <strong>Detalles del Registro:</strong><br>
            • <span class="highlight">Tipo de Checklist:</span> $tipoChecklist<br>
            • <span class="highlight">ID del Registro:</span> $recordId<br>
            • <span class="highlight">Fecha de Generación:</span> $fecha<br>
            • <span class="highlight">Generado por:</span> Sistema Kontrollers
        </div>

        <h3>📄 Contenido del Reporte PDF</h3>
        <p>El archivo adjunto incluye la siguiente información detallada:</p>
        
        <ul>
            <li>✅ <strong>Información general</strong> del checklist</li>
            <li>📝 <strong>Detalles completos</strong> de todos los items</li>
            <li>🔢 <strong>Valores numéricos</strong> registrados</li>
            <li>💬 <strong>Observaciones</strong> de campo</li>
            <li>📸 <strong>Fotografías adjuntas</strong> (si las hay)</li>
            <li>📊 <strong>Porcentaje de cumplimiento</strong> general</li>
        </ul>

        <div class="attachment-note">
            <strong>📎 Archivo Adjunto:</strong> ${_generarNombrePDF(checklistType, recordId)}
        </div>
''';

    if (observaciones != null && observaciones.isNotEmpty) {
      return '''$_generarCuerpoHTML
        <div class="info-box">
            <strong>💭 Observaciones Adicionales:</strong><br>
            ${observaciones.replaceAll('\n', '<br>')}
        </div>
''';
    }

    return '''$_generarCuerpoHTML
    </div>

    <div class="footer">
        <p><strong>Sistema Kontrollers</strong> - Tessa Corporation</p>
        <p>Este reporte ha sido generado automáticamente. Para consultas, contacte al administrador del sistema.</p>
    </div>
</body>
</html>
''';
  }

  static String _generarNombrePDF(String checklistType, int recordId) {
    final String fecha = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final String tipoChecklist = checklistType.toUpperCase();
    return 'Checklist_${tipoChecklist}_ID${recordId}_$fecha.pdf';
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

  static String _obtenerColorTema(String checklistType) {
    switch (checklistType.toLowerCase()) {
      case 'fertirriego':
        return '#1976d2'; // Azul
      case 'bodega':
        return '#f57c00'; // Naranja
      case 'aplicaciones':
        return '#388e3c'; // Verde
      case 'cosechas':
        return '#7b1fa2'; // Púrpura
      default:
        return '#d32f2f'; // Rojo por defecto
    }
  }

  // ==================== MÉTODOS DE VALIDACIÓN ====================

  static bool validarEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  static Map<String, String> validarParametrosEnvio({
    required String destinatario,
    required String checklistType,
    required int recordId,
  }) {
    Map<String, String> errores = {};

    if (destinatario.trim().isEmpty) {
      errores['destinatario'] = 'El destinatario es obligatorio';
    } else if (!validarEmail(destinatario)) {
      errores['destinatario'] = 'Formato de email inválido';
    }

    if (checklistType.trim().isEmpty) {
      errores['checklistType'] = 'El tipo de checklist es obligatorio';
    }

    if (recordId <= 0) {
      errores['recordId'] = 'ID de registro inválido';
    }

    return errores;
  }
}