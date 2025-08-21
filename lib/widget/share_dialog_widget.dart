import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/email_service.dart';
import '../widget/multi_email_field.dart'; // Importar el nuevo widget

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
  final _observacionesController = TextEditingController();
  
  bool _isGeneratingPDF = false;
  bool _isSendingEmail = false;
  Uint8List? _pdfBytes;
  List<String> _destinatarios = []; // Lista de destinatarios

  @override
  void dispose() {
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
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enviar por Correo Electrónico',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    Text(
                      'Puedes agregar múltiples destinatarios',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Campo de emails múltiples con autocompletado
          MultiEmailField(
            labelText: 'Destinatarios *',
            hintText: 'ej: hernan.iturralde',
            initialEmails: _destinatarios,
            onEmailsChanged: (emails) {
              setState(() {
                _destinatarios = emails;
              });
            },
            validator: (emails) {
              if (emails.isEmpty) {
                return 'Debe agregar al menos un destinatario';
              }
              return null;
            },
            maxEmails: 10,
          ),
          
          SizedBox(height: 16),
          
          // Campo de observaciones adicionales
          TextFormField(
            controller: _observacionesController,
            decoration: InputDecoration(
              labelText: 'Observaciones adicionales (opcional)',
              hintText: 'Comentarios o notas para incluir en el correo...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              onPressed: (_isSendingEmail || _isGeneratingPDF || _destinatarios.isEmpty) 
                  ? null 
                  : _sendByEmail,
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
              label: Text(_isSendingEmail 
                  ? 'Enviando...' 
                  : _destinatarios.isEmpty
                      ? 'Agrega destinatarios'
                      : 'Enviar a ${_destinatarios.length} destinatario${_destinatarios.length > 1 ? 's' : ''}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Información sobre el envío múltiple
          if (_destinatarios.length > 1)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se enviará el mismo reporte a todos los destinatarios en un solo correo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
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
    // Validar que haya destinatarios
    if (_destinatarios.isEmpty) {
      _showErrorMessage('Debe agregar al menos un destinatario');
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

      // ✅ CAMBIO AQUÍ: Obtener el nombre del usuario que creó el checklist
      String? usuarioQueCreoElChecklist = widget.recordData['usuario_nombre'];

      // Enviar por correo a múltiples destinatarios
      final result = await EmailService.enviarReporteChecklist(
        destinatarios: _destinatarios,
        checklistType: widget.checklistType,
        recordId: widget.recordData['id'],
        pdfBytes: _pdfBytes!,
        observaciones: _observacionesController.text.trim().isNotEmpty 
            ? _observacionesController.text.trim() 
            : null,
        usuarioCreador: usuarioQueCreoElChecklist, // ✅ Pasar el usuario que creó el checklist
      );

      if (result['exito']) {
        List<String> destinatariosEnviados = result['destinatarios'] ?? _destinatarios;
        _showSuccessMessage(
          'Correo enviado exitosamente a ${destinatariosEnviados.length} destinatario${destinatariosEnviados.length > 1 ? 's' : ''}'
        );
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
        downloadDir = Directory('/storage/emulated/0/Download');
        
        if (!await downloadDir.exists()) {
          downloadDir = Directory('/sdcard/Download');
        }
        
        if (!await downloadDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            String publicDownload = externalDir.path
                .replaceAll('/Android/data/${await _getPackageName()}/files', '/Download');
            downloadDir = Directory(publicDownload);
          }
        }
        
        if (!await downloadDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          downloadDir = Directory('${externalDir!.path}/Downloads');
          await downloadDir.create(recursive: true);
        }
        
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      final String fileName = _generateFileName();
      final File file = File('${downloadDir.path}/$fileName');
      
      await file.writeAsBytes(pdfBytes);
      
      if (await file.exists()) {
        final int fileSize = await file.length();
        
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
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        
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
      return false;
    }
  }

  Future<String> _getPackageName() async {
    return 'com.tessa.kontrollers_v2';
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
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
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
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
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
}