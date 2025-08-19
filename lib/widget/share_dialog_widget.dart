import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/email_service.dart';

class ShareDialog extends StatefulWidget {
  final Map<String, dynamic> recordData;
  final String checklistType;

  ShareDialog({
    required this.recordData,
    required this.checklistType,
  });

  @override
  _ShareDialogState createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  bool _isGeneratingPDF = false;
  bool _isSendingEmail = false;
  Uint8List? _pdfBytes;

  @override
  void dispose() {
    _emailController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getChecklistColor(),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.share,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compartir Reporte',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_getChecklistTitle()} - ID: ${widget.recordData['id']}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del registro
          _buildInfoCard(),
          
          SizedBox(height: 20),
          
          // Opciones de compartir
          Text(
            'Opciones de Compartir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Botón Descargar PDF
          _buildActionButton(
            icon: Icons.download,
            title: 'Descargar PDF',
            subtitle: 'Guardar reporte en el dispositivo',
            color: Colors.blue,
            onTap: _downloadPDF,
            isLoading: _isGeneratingPDF,
          ),
          
          SizedBox(height: 12),
          
          // Sección para envío por correo
          _buildEmailSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getChecklistColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getChecklistColor().withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getChecklistIcon(), color: _getChecklistColor()),
              SizedBox(width: 8),
              Text(
                'Información del Reporte',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getChecklistColor(),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildInfoRow('Tipo:', _getChecklistTitle()),
          _buildInfoRow('Usuario:', widget.recordData['usuario_nombre'] ?? 'N/A'),
          _buildInfoRow('Finca:', widget.recordData['finca_nombre'] ?? 'N/A'),
          _buildInfoRow('Cumplimiento:', '${widget.recordData['porcentaje_cumplimiento']?.toStringAsFixed(1) ?? '0'}%'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.email, color: Colors.orange, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Enviar por Correo Electrónico',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Campo de email
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Destinatario *',
              hintText: 'ejemplo@correo.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingrese el destinatario';
              }
              if (!EmailService.validarEmail(value.trim())) {
                return 'Formato de email inválido';
              }
              return null;
            },
          ),
          
          SizedBox(height: 12),
          
          // Campo de observaciones adicionales
          TextFormField(
            controller: _observacionesController,
            decoration: InputDecoration(
              labelText: 'Observaciones adicionales (opcional)',
              hintText: 'Comentarios o notas para incluir en el correo...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          
          SizedBox(height: 16),
          
          // Botón enviar por correo
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSendingEmail || _isGeneratingPDF) ? null : _sendByEmail,
              icon: _isSendingEmail
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.send),
              label: Text(_isSendingEmail ? 'Enviando...' : 'Enviar por Correo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPDF() async {
    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      // Generar PDF
      final pdfBytes = await PDFService.generarReporteChecklist(
        recordData: widget.recordData,
        checklistType: widget.checklistType,
      );

      // Solicitar permisos
      await _requestStoragePermission();

      // Guardar archivo
      final result = await _saveFile(pdfBytes);
      
      if (result['success']) {
        _showSuccessMessage('PDF descargado exitosamente en: ${result['path']}');
        
        // Opción adicional para compartir
        _showShareOption(result['path']);
      } else {
        _showErrorMessage('Error al guardar PDF: ${result['error']}');
      }

    } catch (e) {
      _showErrorMessage('Error al generar PDF: $e');
    } finally {
      setState(() {
        _isGeneratingPDF = false;
      });
    }
  }

  Future<void> _sendByEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSendingEmail = true;
    });

    try {
      // Generar PDF si no existe
      if (_pdfBytes == null) {
        _pdfBytes = await PDFService.generarReporteChecklist(
          recordData: widget.recordData,
          checklistType: widget.checklistType,
        );
      }

      // Enviar por correo
      final result = await EmailService.enviarReporteChecklist(
        destinatario: _emailController.text.trim(),
        checklistType: widget.checklistType,
        recordId: widget.recordData['id'],
        pdfBytes: _pdfBytes!,
        observaciones: _observacionesController.text.trim().isNotEmpty 
            ? _observacionesController.text.trim() 
            : null,
      );

      if (result['exito']) {
        _showSuccessMessage('Correo enviado exitosamente a ${_emailController.text.trim()}');
        Navigator.of(context).pop();
      } else {
        _showErrorMessage('Error al enviar correo: ${result['mensaje']}');
      }

    } catch (e) {
      _showErrorMessage('Error inesperado: $e');
    } finally {
      setState(() {
        _isSendingEmail = false;
      });
    }
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  }

  Future<Map<String, dynamic>> _saveFile(Uint8List pdfBytes) async {
  try {
    // 1. Solicitar permisos
    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      return {
        'success': false,
        'error': 'Permisos de almacenamiento denegados',
        'action': 'permissions'
      };
    }

    Directory? downloadDir;
    
    if (Platform.isAndroid) {
      // ANDROID: Intentar acceso a carpeta Descargas pública
      
      // Opción 1: Carpeta Descargas estándar de Android
      downloadDir = Directory('/storage/emulated/0/Download');
      
      if (!await downloadDir.exists()) {
        // Opción 2: Carpeta alternativa
        downloadDir = Directory('/sdcard/Download');
      }
      
      if (!await downloadDir.exists()) {
        // Opción 3: Usar External Storage + Download
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navegar hacia la carpeta pública
          String publicDownload = externalDir.path
              .replaceAll('/Android/data/${await _getPackageName()}/files', '/Download');
          downloadDir = Directory(publicDownload);
        }
      }
      
      if (!await downloadDir.exists()) {
        // Opción 4: Crear carpeta en External Storage
        final externalDir = await getExternalStorageDirectory();
        downloadDir = Directory('${externalDir!.path}/Downloads');
        await downloadDir.create(recursive: true);
      }
      
    } else {
      // iOS: Usar directorio de documentos
      downloadDir = await getApplicationDocumentsDirectory();
    }

    if (downloadDir == null || !await downloadDir.exists()) {
      throw Exception('No se pudo acceder al directorio de descargas');
    }

    // 2. Crear archivo
    final String fileName = _generateFileName();
    final File file = File('${downloadDir.path}/$fileName');
    
    print('🔍 Intentando guardar en: ${file.path}');
    
    // 3. Escribir archivo
    await file.writeAsBytes(pdfBytes);
    
    // 4. Verificar que se guardó
    if (await file.exists()) {
      final int fileSize = await file.length();
      
      print('✅ Archivo guardado exitosamente:');
      print('   📁 Ruta: ${file.path}');
      print('   📏 Tamaño: ${fileSize} bytes');
      print('   📱 Directorio: ${downloadDir.path}');
      
      return {
        'success': true,
        'path': file.path,
        'fileName': fileName,
        'directory': downloadDir.path,
        'size': fileSize,
      };
    } else {
      throw Exception('El archivo no se pudo crear');
    }

  } catch (e) {
    print('❌ Error al guardar archivo: $e');
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}
Future<bool> _requestPermissions() async {
  try {
    if (Platform.isAndroid) {
      // Solicitar permiso de almacenamiento
      var status = await Permission.storage.status;
      
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      // Si sigue denegado, intentar con manageExternalStorage
      if (!status.isGranted) {
        var manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          manageStatus = await Permission.manageExternalStorage.request();
        }
        return manageStatus.isGranted;
      }
      
      return status.isGranted;
    }
    
    return true; // iOS
  } catch (e) {
    print('Error solicitando permisos: $e');
    return false;
  }
}

// Obtener nombre del paquete
Future<String> _getPackageName() async {
  // Para Flutter, usualmente es el applicationId del build.gradle
  return 'com.tessa.kontrollers_v2'; // Ajusta según tu package name
}

  String _generateFileName() {
    final String fecha = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final String tipo = widget.checklistType.toUpperCase();
    final int id = widget.recordData['id'];
    
    return 'Checklist_${tipo}_ID${id}_$fecha.pdf';
  }

  void _showShareOption(String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF Guardado'),
        content: Text('¿Desea compartir el archivo usando otras aplicaciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(filePath)]);
            },
            child: Text('Compartir'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Color _getChecklistColor() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Colors.blue[700]!;
      case 'bodega':
        return Colors.orange[700]!;
      case 'aplicaciones':
        return Colors.green[700]!;
      case 'cosechas':
        return Colors.purple[700]!;
      default:
        return Colors.red[700]!;
    }
  }

  IconData _getChecklistIcon() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Icons.water_drop;
      case 'bodega':
        return Icons.warehouse;
      case 'aplicaciones':
        return Icons.science;
      case 'cosechas':
        return Icons.agriculture;
      default:
        return Icons.assignment;
    }
  }

  String _getChecklistTitle() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return 'Fertirriego';
      case 'bodega':
        return 'Bodega';
      case 'aplicaciones':
        return 'Aplicaciones';
      case 'cosechas':
        return 'Cosechas';
      default:
        return widget.checklistType;
    }
  }

void _showShareDialog() {
  if (widget.recordData == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pueden compartir los datos. Intenta recargar el registro.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return ShareDialog(
        recordData: widget.recordData,
        checklistType: widget.checklistType,
      );
    },
  );
}
}