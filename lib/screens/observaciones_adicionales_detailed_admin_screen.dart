import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../widget/share_dialog_widget.dart';

class ObservacionesAdicionalesDetailedAdminScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const ObservacionesAdicionalesDetailedAdminScreen({Key? key, required this.record}) : super(key: key);

  @override
  _ObservacionesAdicionalesDetailedAdminScreenState createState() => _ObservacionesAdicionalesDetailedAdminScreenState();
}

class _ObservacionesAdicionalesDetailedAdminScreenState extends State<ObservacionesAdicionalesDetailedAdminScreen> {
  List<String> _imagenes = [];

  @override
  void initState() {
    super.initState();
    _parseImagenes();
  }

  void _parseImagenes() {
    try {
      final imagenesJson = widget.record['imagenes_json'];
      if (imagenesJson != null && imagenesJson.isNotEmpty) {
        if (imagenesJson is String) {
          _imagenes = List<String>.from(jsonDecode(imagenesJson));
        } else if (imagenesJson is List) {
          _imagenes = List<String>.from(imagenesJson);
        }
      }
    } catch (e) {
      print('Error parseando imágenes: $e');
    }
  }

  Color _getTipoColor(String? tipo) {
    switch (tipo) {
      case 'MIPE':
        return Colors.red;
      case 'CULTIVO':
        return Colors.green;
      case 'MIRFE':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getTipoIcon(String? tipo) {
    switch (tipo) {
      case 'MIPE':
        return Icons.bug_report;
      case 'CULTIVO':
        return Icons.agriculture;
      case 'MIRFE':
        return Icons.science;
      default:
        return Icons.visibility;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipo = widget.record['tipo'] ?? 'N/A';
    final tipoColor = _getTipoColor(tipo);
    final tipoIcon = _getTipoIcon(tipo);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Observación Adicional - Detalles'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _showShareDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(tipo, tipoColor, tipoIcon),
            _buildInformacionGeneral(),
            _buildObservacion(),
            if (_imagenes.isNotEmpty) _buildImagenes(),
            if (tipo == 'MIPE') _buildDatosMIPE(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String tipo, Color tipoColor, IconData tipoIcon) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tipoColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tipoIcon, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      tipo,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Icon(Icons.visibility, size: 24, color: Colors.orange[600]),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'INFORMACIÓN GENERAL',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformacionGeneral() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Finca', widget.record['finca_nombre'] ?? 'N/A'),
          _buildInfoRow('Bloque', widget.record['bloque_nombre'] ?? 'N/A'),
          _buildInfoRow('Variedad', widget.record['variedad_nombre'] ?? 'N/A'),
          _buildInfoRow('Usuario', widget.record['usuario_nombre'] ?? 'N/A'),
          _buildInfoRow('Fecha de Creación', _formatDate(widget.record['fecha_creacion'])),
          if (widget.record['fecha_envio'] != null)
            _buildInfoRow('Fecha de Envío', _formatDate(widget.record['fecha_envio'])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservacion() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OBSERVACIÓN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          Text(
            widget.record['observacion'] ?? 'Sin observación',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildImagenes() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IMÁGENES (${_imagenes.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemCount: _imagenes.length,
            itemBuilder: (context, index) {
              return _buildImagenCard(_imagenes[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImagenCard(String base64Image, int index) {
    try {
      final bytes = base64Decode(base64Image);
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: Icon(Icons.broken_image, color: Colors.grey),
              );
            },
          ),
        ),
      );
    } catch (e) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }

  Widget _buildDatosMIPE() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.red[600]),
              SizedBox(width: 8),
              Text(
                'DATOS MIPE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (widget.record['blanco_biologico'] != null)
            _buildInfoRow('Blanco Biológico', widget.record['blanco_biologico']),
          if (widget.record['incidencia'] != null)
            _buildInfoRow('Incidencia', '${widget.record['incidencia']}%'),
          if (widget.record['severidad'] != null)
            _buildInfoRow('Severidad', '${widget.record['severidad']}%'),
          if (widget.record['tercio'] != null)
            _buildInfoRow('Tercio', widget.record['tercio']),
        ],
      ),
    );
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => ShareDialog(
        recordData: widget.record,
        checklistType: 'observaciones_adicionales',
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
