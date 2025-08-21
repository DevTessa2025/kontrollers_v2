import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:typed_data';

class EmailService {
  // Configuración del servidor SMTP
  static const String _smtpServer = 'mail.tessacorporation.com';
  static const int _smtpPort = 587;
  static const String _senderEmail = 'reportes.kontrollers@tessacorporation.com';
  static const String _password = 'Kontrollers2025\$\$**';
  static const String _defaultDomain = '@tessacorporation.com';
  
  /// Envía un correo con el reporte PDF adjunto a múltiples destinatarios
  static Future<Map<String, dynamic>> enviarReporteChecklist({
    required List<String> destinatarios, // Cambiado a lista
    required String checklistType,
    required int recordId,
    required Uint8List pdfBytes,
    String? observaciones,
    String? usuarioCreador, // NUEVO: Nombre del usuario que creó el checklist
  }) async {
    try {
      // Validar y procesar destinatarios
      List<String> destinatariosProcesados = _procesarDestinatarios(destinatarios);
      
      if (destinatariosProcesados.isEmpty) {
        return {
          'exito': false,
          'mensaje': 'No hay destinatarios válidos',
          'error': 'Lista de destinatarios vacía después del procesamiento',
        };
      }

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
        observaciones,
        usuarioCreador // Pasar el usuario creador
      );
      
      // Crear mensaje con PDF adjunto usando StreamAttachment
      final message = Message()
        ..from = Address(_senderEmail, 'Sistema Kontrollers - Reportes')
        ..subject = asunto
        ..text = cuerpoMensaje
        ..html = _generarCuerpoHTML(checklistType, recordId, observaciones, usuarioCreador)
        ..attachments = [
          StreamAttachment(
            Stream.fromIterable([pdfBytes]),
            'application/pdf',
            fileName: _generarNombrePDF(checklistType, recordId),
          ),
        ];

      // Agregar destinatarios
      for (String destinatario in destinatariosProcesados) {
        message.recipients.add(Address(destinatario));
      }

      // Enviar correo
      final sendReport = await send(message, smtpServer);
      
      print('Reporte de envío: ${sendReport.toString()}');
      
      return {
        'exito': true,
        'mensaje': 'Reporte enviado exitosamente a ${destinatariosProcesados.length} destinatario(s)',
        'destinatarios': destinatariosProcesados,
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

  /// Envía un correo simple sin adjuntos a múltiples destinatarios
  static Future<Map<String, dynamic>> enviarCorreoSimple({
    required List<String> destinatarios, // Cambiado a lista
    required String asunto,
    required String cuerpoMensaje,
    String? cuerpoHTML,
  }) async {
    try {
      // Validar y procesar destinatarios
      List<String> destinatariosProcesados = _procesarDestinatarios(destinatarios);
      
      if (destinatariosProcesados.isEmpty) {
        return {
          'exito': false,
          'mensaje': 'No hay destinatarios válidos',
          'error': 'Lista de destinatarios vacía después del procesamiento',
        };
      }

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
        ..subject = asunto
        ..text = cuerpoMensaje;

      // Agregar destinatarios
      for (String destinatario in destinatariosProcesados) {
        message.recipients.add(Address(destinatario));
      }

      if (cuerpoHTML != null) {
        message.html = cuerpoHTML;
      }

      final sendReport = await send(message, smtpServer);
      
      return {
        'exito': true,
        'mensaje': 'Correo enviado exitosamente a ${destinatariosProcesados.length} destinatario(s)',
        'destinatarios': destinatariosProcesados,
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

  /// Procesa lista de destinatarios agregando dominio automáticamente
  static List<String> _procesarDestinatarios(List<String> destinatarios) {
    List<String> destinatariosProcesados = [];
    
    for (String destinatario in destinatarios) {
      String emailProcesado = procesarEmail(destinatario.trim());
      if (emailProcesado.isNotEmpty && validarEmail(emailProcesado)) {
        destinatariosProcesados.add(emailProcesado);
      }
    }
    
    return destinatariosProcesados;
  }

  /// Procesa un email individual agregando el dominio si es necesario
  static String procesarEmail(String email) {
    if (email.trim().isEmpty) return '';
    
    String emailLimpio = email.trim().toLowerCase();
    
    // Si ya contiene @, validar que sea del dominio correcto o completo
    if (emailLimpio.contains('@')) {
      // Si termina con @ solamente, agregar el dominio
      if (emailLimpio.endsWith('@')) {
        return emailLimpio + 'tessacorporation.com';
      }
      // Si ya tiene un dominio completo, devolver tal como está
      return emailLimpio;
    } else {
      // Si no contiene @, es solo el usuario, agregar dominio completo
      return emailLimpio + _defaultDomain;
    }
  }

  /// Obtener sugerencias de autocompletado para un texto dado
  static List<String> obtenerSugerenciasAutocompletado(String texto) {
    String textoLimpio = texto.trim().toLowerCase();
    
    if (textoLimpio.isEmpty) return [];
    
    // Si ya contiene @ y el dominio completo, no sugerir nada
    if (textoLimpio.contains('@tessacorporation.com')) {
      return [];
    }
    
    // Si contiene @ pero no el dominio completo
    if (textoLimpio.contains('@')) {
      if (textoLimpio.endsWith('@')) {
        return ['${textoLimpio}tessacorporation.com'];
      }
      // Si tiene un dominio parcial que coincide con tessacorporation.com
      String dominioParcial = textoLimpio.split('@')[1];
      String dominioCompleto = 'tessacorporation.com';
      
      if (dominioCompleto.startsWith(dominioParcial)) {
        String usuario = textoLimpio.split('@')[0];
        return ['$usuario@$dominioCompleto'];
      }
      return [];
    }
    
    // Si no contiene @, sugerir el autocompletado completo
    return ['$textoLimpio$_defaultDomain'];
  }

  static String _generarAsunto(String checklistType, int recordId) {
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final String fecha = DateTime.now().toString().substring(0, 10);
    
    return 'Reporte de $tipoChecklist - $fecha';
  }

  static String _generarCuerpoMensaje(String checklistType, int recordId, String? observaciones, String? usuarioCreador) {
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final String fecha = DateTime.now().toString().substring(0, 19);
    
    // AQUÍ ESTÁ EL CAMBIO: Usar el usuario que creó el checklist, no el que envía el correo
    final String kontrollerQueHizoReporte = usuarioCreador ?? 'Usuario no especificado';
    
    String mensaje = '''
Estimado/a usuario/a,

Se adjunta el reporte detallado del checklist de $tipoChecklist correspondiente al Kontroller: $kontrollerQueHizoReporte.

INFORMACIÓN DEL REPORTE:
- Checklist: $tipoChecklist
- Fecha de Generación: $fecha
- Generado por: $kontrollerQueHizoReporte
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

  static String _generarCuerpoHTML(String checklistType, int recordId, String? observaciones, String? usuarioCreador) {
    final String tipoChecklist = _obtenerNombreChecklist(checklistType);
    final String fecha = DateTime.now().toString().substring(0, 19);
    final String colorTema = _obtenerColorTema(checklistType);
    
    // AQUÍ ESTÁ EL CAMBIO: Usar el usuario que creó el checklist
    final String kontrollerQueHizoReporte = usuarioCreador ?? 'Usuario no especificado';

    String htmlContent = '''
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
        <div>Reporte de Checklist - $tipoChecklist</div>
    </div>

    <div class="checklist-details">
        <h2>📋 Información del Reporte</h2>
        
        <div class="info-box">
            <strong>Detalles del Registro:</strong><br>
            • <span class="highlight">Checklist:</span> $tipoChecklist<br>
            • <span class="highlight">Fecha de Generación:</span> $fecha<br>
            • <span class="highlight">Generado por:</span> $kontrollerQueHizoReporte
        </div>

        <div class="attachment-note">
            <strong>📎 Archivo Adjunto:</strong> ${_generarNombrePDF(checklistType, recordId)}
        </div>
''';

    if (observaciones != null && observaciones.isNotEmpty) {
      htmlContent += '''
        <div class="info-box">
            <strong>💭 Observaciones Adicionales:</strong><br>
            ${observaciones.replaceAll('\n', '<br>')}
        </div>
''';
    }

    htmlContent += '''
    </div>

    <div class="footer">
        <p><strong>Sistema Kontrollers</strong> - Tessa Corporation</p>
        <p>Este reporte ha sido generado automáticamente. Para consultas, contacte al administrador del sistema.</p>
    </div>
</body>
</html>
''';

    return htmlContent;
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

  /// Validar lista de emails
  static Map<String, List<String>> validarEmails(List<String> emails) {
    Map<String, List<String>> resultado = {
      'validos': [],
      'invalidos': [],
    };

    for (String email in emails) {
      String emailProcesado = procesarEmail(email.trim());
      if (emailProcesado.isNotEmpty && validarEmail(emailProcesado)) {
        resultado['validos']!.add(emailProcesado);
      } else {
        resultado['invalidos']!.add(email.trim());
      }
    }

    return resultado;
  }

  static Map<String, String> validarParametrosEnvio({
    required List<String> destinatarios, // Cambiado a lista
    required String checklistType,
    required int recordId,
  }) {
    Map<String, String> errores = {};

    if (destinatarios.isEmpty) {
      errores['destinatarios'] = 'Debe especificar al menos un destinatario';
    } else {
      Map<String, List<String>> validacion = validarEmails(destinatarios);
      if (validacion['validos']!.isEmpty) {
        errores['destinatarios'] = 'No hay destinatarios válidos en la lista';
      }
      if (validacion['invalidos']!.isNotEmpty) {
        errores['destinatarios_invalidos'] = 'Emails inválidos: ${validacion['invalidos']!.join(', ')}';
      }
    }

    if (checklistType.trim().isEmpty) {
      errores['checklistType'] = 'El tipo de checklist es obligatorio';
    }

    if (recordId <= 0) {
      errores['recordId'] = 'ID de registro inválido';
    }

    return errores;
  }

  // ==================== MÉTODOS DE UTILIDAD PARA AUTOCOMPLETADO ====================

  /// Obtener lista de usuarios comunes del dominio (para autocompletado)
  static List<String> obtenerUsuariosComunes() {
    return [
      'admin',
      'supervisor',
      'reportes',
      'gerencia',
      'sistemas',
      'operaciones',
      'calidad',
      'rrhh',
      'contabilidad',
      'ventas',
    ];
  }

  /// Filtrar usuarios comunes basado en texto de entrada
  static List<String> filtrarUsuariosComunes(String texto) {
    if (texto.trim().isEmpty) return obtenerUsuariosComunes().map((u) => u + _defaultDomain).toList();
    
    String textoBusqueda = texto.trim().toLowerCase();
    return obtenerUsuariosComunes()
        .where((usuario) => usuario.toLowerCase().contains(textoBusqueda))
        .map((usuario) => usuario + _defaultDomain)
        .toList();
  }
}