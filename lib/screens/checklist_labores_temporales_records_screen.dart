import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../data/checklist_data_labores_temporales.dart';
import '../services/checklist_labores_temporales_storage_service.dart';
import 'checklist_labores_temporales_screen.dart';

class ChecklistLaboresTemporalesRecordsScreen extends StatefulWidget {
  @override
  _ChecklistLaboresTemporalesRecordsScreenState createState() => _ChecklistLaboresTemporalesRecordsScreenState();
}

class _ChecklistLaboresTemporalesRecordsScreenState extends State<ChecklistLaboresTemporalesRecordsScreen> {
  List<ChecklistLaboresTemporales> _checklists = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _searchQuery = '';
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadChecklists();
    _loadStatistics();
  }

  Future<void> _loadChecklists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<ChecklistLaboresTemporales> checklists = await ChecklistLaboresTemporalesStorageService.getAllChecklists();
      setState(() {
        _checklists = checklists;
        _isLoading = false;
      });
      print('Cargados ${checklists.length} checklists de labores permanentes');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error cargando registros: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _loadStatistics() async {
    try {
      Map<String, dynamic> stats = await ChecklistLaboresTemporalesStorageService.getStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      print('Error cargando estadísticas de labores temporales: $e');
    }
  }

  Future<void> _syncToServer() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      Map<String, dynamic> result = await ChecklistLaboresTemporalesStorageService.syncChecklistsToServer();
      
      if (result['success']) {
        Fluttertoast.showToast(
          msg: result['message'],
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
        
        // Recargar datos después de sincronización exitosa
        await _loadChecklists();
        await _loadStatistics();
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? 'Error en la sincronización',
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error de conexión: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _syncIndividualChecklist(ChecklistLaboresTemporales checklist) async {
    try {
      // Mostrar diálogo de confirmación
      bool confirmed = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Sincronizar Checklist'),
            content: Text(
              '¿Está seguro de sincronizar el checklist del ${_formatDate(checklist.fecha)} '
              'de la finca ${checklist.finca?.nombre ?? 'N/A'}?'
            ),
            actions: [
              TextButton(
                child: Text('Cancelar'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text('Sincronizar'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;

      if (confirmed && checklist.id != null) {
        // Aquí implementarías la sincronización individual
        // Por ahora, usamos la sincronización general
        await _syncToServer();
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error sincronizando checklist: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _deleteChecklist(ChecklistLaboresTemporales checklist) async {
    bool confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar eliminación'),
          content: Text(
            '¿Está seguro de eliminar el checklist del ${_formatDate(checklist.fecha)} '
            'de la finca ${checklist.finca?.nombre ?? 'N/A'}?'
          ),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Eliminar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirmed) {
      try {
        if (checklist.id != null) {
          await ChecklistLaboresTemporalesStorageService.deleteChecklist(checklist.id!);
          await _loadChecklists();
          await _loadStatistics();
          
          Fluttertoast.showToast(
            msg: 'Checklist eliminado exitosamente',
            backgroundColor: Colors.green[600],
            textColor: Colors.white,
          );
        }
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error eliminando checklist: $e',
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _editChecklist(ChecklistLaboresTemporales checklist) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistLaboresTemporalesScreen(
          checklistToEdit: checklist,
          recordId: checklist.id,
        ),
      ),
    );

    if (result != null) {
      await _loadChecklists();
      await _loadStatistics();
    }
  }

  List<ChecklistLaboresTemporales> _getFilteredChecklists() {
    if (_searchQuery.isEmpty) {
      return _checklists;
    }

    return _checklists.where((checklist) {
      return (checklist.finca?.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             (checklist.kontroller?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
             _formatDate(checklist.fecha).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(date);
  }

  String _formatDateShort(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return DateFormat('dd/MM/yyyy', 'es_ES').format(date);
  }

  Color _getStatusColor(ChecklistLaboresTemporales checklist) {
    if (checklist.fechaEnvio != null) {
      return Colors.green;
    }
    return Colors.orange;
  }

  String _getStatusText(ChecklistLaboresTemporales checklist) {
    if (checklist.fechaEnvio != null) {
      return 'Sincronizado';
    }
    return 'Pendiente';
  }

  Widget _buildStatisticsCard() {
    if (_statistics.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.deepPurple[700]),
                SizedBox(width: 8),
                Text(
                  'Estadísticas Generales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Fila 1
            Row(
              children: [
                Expanded(child: _buildStatItem('Total', '${_statistics['totalChecklists']}', Colors.deepPurple)),
                Expanded(child: _buildStatItem('Sincronizados', '${_statistics['enviados']}', Colors.green)),
                Expanded(child: _buildStatItem('Pendientes', '${_statistics['pendientes']}', Colors.orange)),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Fila 2
            Row(
              children: [
                Expanded(child: _buildStatItem('Fincas', '${_statistics['fincasEvaluadas']}', Colors.purple)),
                Expanded(child: _buildStatItem('Promedio', '${_statistics['promedioCumplimiento'].toStringAsFixed(1)}%', Colors.teal)),
                Expanded(child: _buildStatItem('Mejor', '${_statistics['mejorCumplimiento'].toStringAsFixed(1)}%', Colors.green)),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Mensaje informativo
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.deepPurple[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toca en cualquier checklist para editarlo o usa el botón "Nuevo" para crear uno nuevo',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.deepPurple[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por finca, kontroller o fecha...',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChecklistLaboresTemporalesScreen(),
              ),
            );
            if (result != null) {
              _loadChecklists();
              _loadStatistics();
            }
          },
          icon: Icon(Icons.add, size: 18),
          label: Text('Nuevo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple[600],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSyncing ? null : _syncToServer,
        icon: _isSyncing 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(Icons.cloud_upload, size: 18),
        label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar con Servidor'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistCard(ChecklistLaboresTemporales checklist) {
    List<ChecklistLaboresTemporales> filteredList = _getFilteredChecklists();
    int index = filteredList.indexOf(checklist);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => checklist.fechaEnvio != null ? _showChecklistDetails(checklist) : _editChecklist(checklist),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con número e información principal
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[600],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checklist.finca?.nombre ?? 'Sin finca',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Kontroller: ${checklist.kontroller ?? 'No especificado'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(checklist),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(checklist),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDateShort(checklist.fecha),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Información de cuadrantes
              if (checklist.cuadrantes.isNotEmpty) ...[
                Text(
                  'Cuadrantes evaluados (${checklist.cuadrantes.length}):',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: checklist.cuadrantes.take(6).map((cuadrante) => 
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple[300]!),
                      ),
                      child: Text(
                        cuadrante.cuadrante,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
                if (checklist.cuadrantes.length > 6)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '+${checklist.cuadrantes.length - 6} más...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                SizedBox(height: 12),
              ],
              
              // Métricas
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Cumplimiento',
                      '${checklist.porcentajeCumplimiento?.toStringAsFixed(1) ?? '0.0'}%',
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Ítems',
                      '${checklist.items.length}',
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Cuadrantes',
                      '${checklist.cuadrantes.length}',
                      Colors.purple,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (checklist.fechaEnvio == null)
                    TextButton.icon(
                      onPressed: () => _editChecklist(checklist),
                      icon: Icon(Icons.edit, size: 18),
                      label: Text('Editar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[600],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _showChecklistDetails(checklist),
                    icon: Icon(Icons.visibility, size: 18),
                    label: Text('Ver Detalles'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[600],
                    ),
                  ),
                  if (checklist.fechaEnvio == null)
                    TextButton.icon(
                      onPressed: () => _syncIndividualChecklist(checklist),
                      icon: Icon(Icons.cloud_upload, size: 18),
                      label: Text('Sincronizar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[600],
                      ),
                    ),
                  if (checklist.fechaEnvio == null)
                    TextButton.icon(
                      onPressed: () => _deleteChecklist(checklist),
                      icon: Icon(Icons.delete, size: 18),
                      label: Text('Eliminar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showChecklistDetails(ChecklistLaboresTemporales checklist) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Detalles del Checklist'),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Fecha:', _formatDate(checklist.fecha)),
                  _buildDetailRow('Finca:', checklist.finca?.nombre ?? 'N/A'),
                  _buildDetailRow('Kontroller:', checklist.kontroller ?? 'N/A'),
                  _buildDetailRow('UP:', checklist.up ?? 'N/A'),
                  _buildDetailRow('Semana:', checklist.semana ?? 'N/A'),
                  _buildDetailRow('Cuadrantes:', '${checklist.cuadrantes.length}'),
                  _buildDetailRow('Ítems evaluados:', '${checklist.items.length}'),
                  _buildDetailRow('% Cumplimiento:', '${checklist.porcentajeCumplimiento?.toStringAsFixed(1) ?? '0.0'}%'),
                  _buildDetailRow('Estado:', _getStatusText(checklist)),
                  
                  if (checklist.fechaEnvio != null)
                    _buildDetailRow('Sincronizado:', _formatDate(checklist.fechaEnvio)),
                  
                  SizedBox(height: 16),
                  
                  if (checklist.cuadrantes.isNotEmpty) ...[
                    Text(
                      'Cuadrantes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ...checklist.cuadrantes.map((cuadrante) => 
                      _buildCuadranteWithPhotos(cuadrante),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (checklist.fechaEnvio == null)
              ElevatedButton(
                child: Text('Editar'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _editChecklist(checklist);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCuadranteWithPhotos(CuadranteLaboresTemporalesInfo cuadrante) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del cuadrante
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.deepPurple[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${cuadrante.supervisor} - ${cuadrante.cuadrante} (Bl. ${cuadrante.bloque}) - ${cuadrante.variedad}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            // Fotos del cuadrante
            if (cuadrante.fotos.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                'Fotos adjuntas (${cuadrante.fotos.length}):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cuadrante.fotos.map((foto) => _buildPhotoPreview(foto)).toList(),
              ),
            ] else ...[
              SizedBox(height: 8),
              Text(
                'Sin fotos adjuntas',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(Map<String, dynamic> foto) {
    final base64Image = foto['base64'] as String?;
    final etiqueta = foto['etiqueta'] as String?;
    
    if (base64Image == null || base64Image.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(Icons.broken_image, color: Colors.grey[500]),
      );
    }
    
    try {
      final bytes = base64Decode(base64Image);
      return GestureDetector(
        onTap: () => _showFullImage(bytes, etiqueta),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple[300]!),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.memory(
                  bytes,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              if (etiqueta != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[600],
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: Text(
                      _getItemName(etiqueta),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Icon(Icons.error, color: Colors.red[500]),
      );
    }
  }

  String _getItemName(String etiqueta) {
    switch (etiqueta) {
      case '1': return 'Alzado';
      case '2': return 'Hormonado';
      case '3': return 'Paloteo';
      case '4': return 'Materia Org.';
      case '5': return 'Limpieza';
      default: return 'Sin etiqueta';
    }
  }

  void _showFullImage(Uint8List bytes, String? etiqueta) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con etiqueta
                if (etiqueta != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[600],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Ítem: ${_getItemName(etiqueta)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Imagen
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: etiqueta != null 
                          ? BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            )
                          : BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: etiqueta != null 
                          ? BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            )
                          : BorderRadius.circular(8),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // Botón cerrar
                Padding(
                  padding: EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ChecklistLaboresTemporales> filteredChecklists = _getFilteredChecklists();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Registros de Labores Temporales'),
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadChecklists();
              _loadStatistics();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChecklistLaboresTemporalesScreen(),
            ),
          );
          if (result != null) {
            _loadChecklists();
            _loadStatistics();
          }
        },
        backgroundColor: Colors.deepPurple[600],
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Nuevo Checklist',
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple[600]),
                  SizedBox(height: 16),
                  Text('Cargando registros...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadChecklists();
                await _loadStatistics();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatisticsCard(),
                    SizedBox(height: 16),
                    _buildSearchBar(),
                    SizedBox(height: 12),
                    _buildSyncButton(),
                    SizedBox(height: 16),
                    
                    if (filteredChecklists.isEmpty)
                      Container(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              _checklists.isEmpty 
                                  ? 'No hay checklists registrados'
                                  : 'No se encontraron registros con el filtro aplicado',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChecklistLaboresTemporalesScreen(),
                                  ),
                                );
                                if (result != null) {
                                  _loadChecklists();
                                  _loadStatistics();
                                }
                              },
                              icon: Icon(Icons.add),
                              label: Text('Crear Primer Checklist'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filteredChecklists.map((checklist) => 
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _buildChecklistCard(checklist),
                        ),
                      ),
                    
                    SizedBox(height: 80), // Espacio para el FAB
                  ],
                ),
              ),
            ),
    );
  }
}