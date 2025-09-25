import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../widget/share_dialog_widget.dart';

class ObservacionesAdicionalesAdminDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const ObservacionesAdicionalesAdminDetailScreen({Key? key, required this.record}) : super(key: key);

  @override
  State<ObservacionesAdicionalesAdminDetailScreen> createState() => _ObservacionesAdicionalesAdminDetailScreenState();
}

class _ObservacionesAdicionalesAdminDetailScreenState extends State<ObservacionesAdicionalesAdminDetailScreen> {
  Map<String, dynamic>? _fullRecord;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await AdminService.getRecordDetail('observaciones_adicionales', widget.record['id']);
      if (mounted) {
        setState(() {
          _fullRecord = detail ?? widget.record;
          _loading = false;
          _error = detail == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observación Adicional'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Compartir / Exportar',
            icon: const Icon(Icons.share),
            onPressed: _fullRecord == null ? null : _openShareDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 64),
          const SizedBox(height: 12),
          Text('No se pudo cargar el detalle', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildContent() {
    final r = _fullRecord!;
    final tipo = (r['tipo'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(r),
          const SizedBox(height: 16),
          _buildObservacionCard(r),
          const SizedBox(height: 16),
          if (tipo.toUpperCase() == 'MIPE') _buildMIPECard(r),
          const SizedBox(height: 16),
          _buildImagesCard(r),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> r) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.note_alt, color: Colors.teal[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID ${r['id']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700])),
                      Text(_formatDate(r['fecha_creacion']), style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal[200]!),
                  ),
                  child: Text(
                    (r['tipo'] ?? 'N/A').toString(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.teal[700]),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            _rowInfo('Finca', r['finca_nombre']),
            _rowInfo('Bloque', r['bloque_nombre']),
            _rowInfo('Variedad', r['variedad_nombre']),
            _rowInfo('Usuario', r['usuario_nombre'] ?? r['usuario_id']),
            _rowInfo('Enviado', _formatDate(r['fecha_envio'])),
          ],
        ),
      ),
    );
  }

  Widget _buildObservacionCard(Map<String, dynamic> r) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text('Observación', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
              child: Text((r['observacion'] ?? '').toString(), style: TextStyle(color: Colors.grey[800])),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMIPECard(Map<String, dynamic> r) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.analytics, color: Colors.blue[700]), const SizedBox(width: 8), const Text('Datos MIPE', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          if ((r['blanco_biologico'] ?? '').toString().isNotEmpty) _rowInfo('Blanco Biológico', r['blanco_biologico']),
          if (r['incidencia'] != null) _rowInfo('Incidencia', '${r['incidencia']}%'),
          if (r['severidad'] != null) _rowInfo('Severidad', '${r['severidad']}%'),
          if ((r['tercio'] ?? '').toString().isNotEmpty) _rowInfo('Tercio', r['tercio']),
        ]),
      ),
    );
  }

  Widget _buildImagesCard(Map<String, dynamic> r) {
    List<String> images = [];
    try {
      if (r['imagenes_json'] != null) {
        final parsed = json.decode(r['imagenes_json']);
        if (parsed is List) images = parsed.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    if (images.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [Icon(Icons.image_not_supported, color: Colors.grey[600]), const SizedBox(width: 8), Text('Sin imágenes', style: TextStyle(color: Colors.grey[700]))]),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.image, color: Colors.purple[700]), const SizedBox(width: 8), Text('Imágenes (${images.length})', style: const TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final b64 = images[index];
              return InkWell(
                onTap: () => _showImageDialog(b64),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(b64),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image))),
                  ),
                ),
              );
            },
          )
        ]),
      ),
    );
  }

  Widget _rowInfo(String label, dynamic value) {
    final text = (value ?? 'N/A').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('$label:', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600))),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  String _formatDate(dynamic v) {
    if (v == null) return 'N/A';
    try {
      final d = DateTime.parse(v.toString());
      return DateFormat('dd/MM/yy HH:mm').format(d);
    } catch (_) {
      return v.toString();
    }
  }

  void _openShareDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ShareDialog(
          recordData: _fullRecord!,
          checklistType: 'observaciones_adicionales',
        );
      },
    );
  }

  void _showImageDialog(String base64Image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          maxScale: 5,
          minScale: 0.3,
          child: Image.memory(base64Decode(base64Image), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
