import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/pdf_service.dart';
import '../services/email_service.dart';

// Clase de tema para mantener la consistencia visual
class _ChecklistTheme {
  final Color color;
  final IconData icon;
  final String title;
  _ChecklistTheme({required this.color, required this.icon, required this.title});

  factory _ChecklistTheme.fromType(String type) {
    switch (type.toLowerCase()) {
      case 'fertirriego':
        return _ChecklistTheme(color: Colors.blue.shade700, icon: Icons.water_drop_outlined, title: 'Fertirriego');
      case 'bodega':
        return _ChecklistTheme(color: Colors.orange.shade700, icon: Icons.warehouse_outlined, title: 'Bodega');
      case 'aplicaciones':
        return _ChecklistTheme(color: Colors.green.shade700, icon: Icons.science_outlined, title: 'Aplicaciones');
      case 'cosechas':
        return _ChecklistTheme(color: Colors.purple.shade700, icon: Icons.agriculture_outlined, title: 'Cosechas');
      default:
        return _ChecklistTheme(color: Colors.grey.shade700, icon: Icons.assignment_outlined, title: type);
    }
  }
}

class ShareDialog extends StatefulWidget {
  final Map<String, dynamic> recordData;
  final String checklistType;

  const ShareDialog({
    super.key,
    required this.recordData,
    required this.checklistType,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _observacionesController = TextEditingController();

  bool _isGeneratingPDF = false;
  bool _isSendingEmail = false;
  Uint8List? _pdfBytes;
  final List<String> _destinatarios = [];

  late final _ChecklistTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = _ChecklistTheme.fromType(widget.checklistType);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }
  
  // =======================================================================
  // INICIO DE LA LÓGICA DE GUARDADO Y PERMISOS (DE TU VERSIÓN FUNCIONAL)
  // =======================================================================

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
      print('Error solicitando permisos: $e');
      return false;
    }
  }
  
  Future<String> _getPackageName() async {
    // Asegúrate de que este sea el package name correcto de tu app.
    return 'com.tessa.kontrollers_v2'; 
  }

  Future<Map<String, dynamic>> _saveFile(Uint8List pdfBytes) async {
    try {
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        return {'success': false, 'error': 'Permisos de almacenamiento denegados'};
      }

      Directory? downloadDir;
      
      if (Platform.isAndroid) {
        // Lógica de búsqueda de directorio de tu versión anterior
        downloadDir = Directory('/storage/emulated/0/Download');
        
        if (!await downloadDir.exists()) {
          downloadDir = Directory('/sdcard/Download');
        }
        
        if (!await downloadDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            String publicDownload = externalDir.path.replaceAll('/Android/data/${await _getPackageName()}/files', '/Download');
            downloadDir = Directory(publicDownload);
          }
        }
        
        if (!await downloadDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            downloadDir = Directory('${externalDir.path}/Downloads');
            await downloadDir.create(recursive: true);
          }
        }
        
      } else {
        // iOS
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('No se pudo acceder al directorio de descargas');
      }

      final String fileName = _generateFileName();
      final File file = File('${downloadDir.path}/$fileName');
      
      print('🔍 Intentando guardar en: ${file.path}');
      await file.writeAsBytes(pdfBytes);
      
      if (await file.exists()) {
        print('✅ Archivo guardado exitosamente en: ${file.path}');
        return {'success': true, 'path': file.path};
      } else {
        throw Exception('El archivo no se pudo crear en la ruta especificada.');
      }

    } catch (e) {
      print('❌ Error al guardar archivo: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // =====================================================================
  // FIN DE LA LÓGICA DE GUARDADO
  // =====================================================================


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(),
                        const SizedBox(height: 24),
                        const _SectionTitle(title: 'Opciones de Exportación'),
                        const SizedBox(height: 12),
                        _buildDownloadButton(),
                        const SizedBox(height: 24),
                        const _SectionTitle(title: 'Enviar por Correo'),
                        const SizedBox(height: 16),
                        _buildMultiEmailField(),
                        const SizedBox(height: 16),
                        _buildObservacionesField(),
                        const SizedBox(height: 24),
                        _buildSendEmailButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      backgroundColor: _theme.color,
      foregroundColor: Colors.white,
      pinned: true,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      title: const Text('Compartir Reporte'),
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      expandedHeight: 120.0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            color: _theme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                children: [
                  Icon(_theme.icon, color: Colors.white.withOpacity(0.8), size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _theme.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID del Registro: ${widget.recordData['id']}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Usuario:', widget.recordData['usuario_nombre'] ?? 'N/A'),
          _buildInfoRow('Finca:', widget.recordData['finca_nombre'] ?? 'N/A'),
          _buildInfoRow('Cumplimiento:', '${widget.recordData['porcentaje_cumplimiento']?.toStringAsFixed(1) ?? '0'}%'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return ListTile(
      onTap: _isGeneratingPDF ? null : _downloadPDF,
      leading: _isGeneratingPDF
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: _theme.color),
            )
          : Icon(Icons.download_for_offline_outlined, color: _theme.color),
      title: Text('Descargar PDF', style: TextStyle(color: _theme.color, fontWeight: FontWeight.bold)),
      subtitle: const Text('Guardar el reporte en el dispositivo'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildMultiEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Destinatarios',
            hintText: 'ej: hernan.iturralde, admin...',
            prefixIcon: const Icon(Icons.person_add_alt_1_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: Theme.of(context).primaryColor,
              onPressed: _addEmailsFromField,
              tooltip: 'Agregar destinatarios',
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onFieldSubmitted: (_) => _addEmailsFromField(),
        ),
        const SizedBox(height: 8),
        if (_destinatarios.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _destinatarios.map((email) => _EmailChip(
              email: email,
              onDeleted: () => _removeDestination(email),
            )).toList(),
          )
      ],
    );
  }

  Widget _buildObservacionesField() {
    return TextFormField(
      controller: _observacionesController,
      decoration: InputDecoration(
        labelText: 'Observaciones (opcional)',
        hintText: 'Añadir un comentario al correo...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        alignLabelWithHint: true,
      ),
      maxLines: 3,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildSendEmailButton() {
    final bool canSend = !_isSendingEmail && _destinatarios.isNotEmpty;
    final String buttonText = _isSendingEmail
        ? 'Enviando...'
        : 'Enviar a ${_destinatarios.length} destinatario${_destinatarios.length == 1 ? '' : 's'}';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSend ? _sendByEmail : null,
        icon: _isSendingEmail
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_outlined),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: _theme.color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _addEmailsFromField() {
    if (_emailController.text.trim().isEmpty) return;
    
    final emails = _emailController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);

    setState(() {
      for (final email in emails) {
        final processedEmail = EmailService.procesarEmail(email);
        if (processedEmail.isNotEmpty && EmailService.validarEmail(processedEmail) && !_destinatarios.contains(processedEmail)) {
          _destinatarios.add(processedEmail);
        }
      }
      _emailController.clear();
    });
  }

  void _removeDestination(String email) {
    setState(() {
      _destinatarios.remove(email);
    });
  }

  Future<void> _downloadPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      final pdfBytes = await PDFService.generarReporteChecklist(
        recordData: widget.recordData,
        checklistType: widget.checklistType,
      );
      final result = await _saveFile(pdfBytes);
      if (mounted) {
        if (result['success']) {
          _showSuccessMessage('PDF guardado en: ${result['path']}');
          _showShareOption(result['path']);
        } else {
          _showErrorMessage('Error al guardar PDF: ${result['error']}');
        }
      }
    } catch (e) {
      _showErrorMessage('Error al generar PDF: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPDF = false);
    }
  }

  Future<void> _sendByEmail() async {
    if (_destinatarios.isEmpty) {
      _showErrorMessage('Agrega al menos un destinatario.');
      return;
    }

    setState(() => _isSendingEmail = true);
    try {
      _pdfBytes ??= await PDFService.generarReporteChecklist(
        recordData: widget.recordData,
        checklistType: widget.checklistType,
      );

      final result = await EmailService.enviarReporteChecklist(
        destinatarios: _destinatarios,
        checklistType: widget.checklistType,
        recordId: widget.recordData['id'],
        pdfBytes: _pdfBytes!,
        observaciones: _observacionesController.text.trim().isNotEmpty ? _observacionesController.text.trim() : null,
        usuarioCreador: widget.recordData['usuario_nombre'],
        fincaNombre: widget.recordData['finca_nombre'],
      );

      if (result['exito'] && mounted) {
        _showSuccessMessage(result['mensaje']);
        Navigator.of(context).pop();
      } else {
        _showErrorMessage(result['mensaje']);
      }
    } catch (e) {
      _showErrorMessage('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isSendingEmail = false);
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green.shade700,
    ));
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
    ));
  }
  
  String _generateFileName() {
    final String fecha = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final String tipo = widget.checklistType.toUpperCase();
    final String finca = (widget.recordData['finca_nombre'] ?? 'SinFinca')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[/\\]'), '_');

    return 'Checklist_${tipo}_${finca}_$fecha.pdf';
  }

  void _showShareOption(String filePath) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Guardado'),
        content: const Text('¿Deseas compartir el archivo con otra aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(filePath)]);
            },
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
  }
}

// Widgets auxiliares para la UI
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }
}

class _EmailChip extends StatelessWidget {
  final String email;
  final VoidCallback onDeleted;

  const _EmailChip({required this.email, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Chip(
      label: Text(email),
      onDeleted: onDeleted,
      backgroundColor: primaryColor.withOpacity(0.1),
      deleteIconColor: primaryColor.withOpacity(0.7),
      labelStyle: TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(color: primaryColor.withOpacity(0.2)),
    );
  }
}