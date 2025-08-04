import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/checklist_storage_service.dart';
import '../services/sql_server_service.dart';
import '../data/checklist_data.dart';

class ChecklistRecordsScreen extends StatefulWidget {
  @override
  _ChecklistRecordsScreenState createState() => _ChecklistRecordsScreenState();
}

class _ChecklistRecordsScreenState extends State<ChecklistRecordsScreen> {
  List<Map<String, dynamic>> records = [];
  Map<String, int> stats = {};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> loadedRecords = await ChecklistStorageService.getLocalChecklists();
      Map<String, int> loadedStats = await ChecklistStorageService.getLocalStats();
      
      setState(() {
        records = loadedRecords;
        stats = loadedStats;
        _isLoading = false;
      });
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

  Future<void> _sendToServer(int recordId) async {
    setState(() {
      _isSending = true;
    });

    try {
      // Obtener el registro completo
      ChecklistBodega? checklist = await ChecklistStorageService.getChecklistById(recordId);
      if (checklist == null) {
        throw Exception('Registro no encontrado');
      }

      // Obtener datos del registro para el envío
      Map<String, dynamic> record = records.firstWhere((r) => r['id'] == recordId);
      
      // Crear query de inserción para el servidor
      String insertQuery = _generateInsertQuery(record);
      
      // Ejecutar query en el servidor
      await SqlServerService.executeQuery(insertQuery);
      
      // Marcar como enviado
      await ChecklistStorageService.markAsEnviado(recordId);
      
      Fluttertoast.showToast(
        msg: 'Registro enviado exitosamente al servidor',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      
      // Recargar registros
      await _loadRecords();
      
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error enviando registro: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }

    setState(() {
      _isSending = false;
    });
  }

  String _generateInsertQuery(Map<String, dynamic> record) {
    // Escapar comillas simples para evitar errores SQL
    String escapeString(String? str) {
      if (str == null) return 'NULL';
      return "'${str.replaceAll("'", "''")}'";
    }

    return '''
INSERT INTO checklist_bodega_servidor (
  titulo, 
  subtitulo, 
  finca_nombre, 
  supervisor_id, 
  supervisor_nombre,
  pesador_id, 
  pesador_nombre,
  usuario_id, 
  usuario_nombre,
  fecha_creacion, 
  porcentaje_cumplimiento,
  checklist_data,
  fecha_envio
) VALUES (
  ${escapeString(record['titulo'])},
  ${escapeString(record['subtitulo'])},
  ${escapeString(record['finca_nombre'])},
  ${record['supervisor_id'] ?? 'NULL'},
  ${escapeString(record['supervisor_nombre'])},
  ${record['pesador_id'] ?? 'NULL'},
  ${escapeString(record['pesador_nombre'])},
  ${record['usuario_id'] ?? 'NULL'},
  ${escapeString(record['usuario_nombre'])},
  ${escapeString(record['fecha_creacion'])},
  ${record['porcentaje_cumplimiento'] ?? 0.0},
  ${escapeString(record['checklist_data'])},
  GETDATE()
);
    ''';
  }

  Future<void> _deleteRecord(int recordId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirmar Eliminación',
          style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
        ),
        content: Text('¿Está seguro que desea eliminar este registro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChecklistStorageService.deleteLocalChecklist(recordId);
        await _loadRecords();
        
        Fluttertoast.showToast(
          msg: 'Registro eliminado correctamente',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error eliminando registro: $e',
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _viewChecklistDetails(int recordId) async {
    try {
      ChecklistBodega? checklist = await ChecklistStorageService.getChecklistById(recordId);
      if (checklist == null) {
        Fluttertoast.showToast(
          msg: 'No se pudo cargar el checklist',
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Detalles del Checklist',
            style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Finca:', checklist.finca?.nombre ?? "No seleccionada"),
                _buildDetailRow('Supervisor:', checklist.supervisor?.nombre ?? "No seleccionado"),
                _buildDetailRow('Pesador:', checklist.pesador?.nombre ?? "No seleccionado"),
                _buildDetailRow('Fecha:', checklist.fecha != null 
                    ? '${checklist.fecha!.day.toString().padLeft(2, '0')}/${checklist.fecha!.month.toString().padLeft(2, '0')}/${checklist.fecha!.year}'
                    : 'No definida'),
                
                SizedBox(height: 16),
                
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cumplimiento General',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${checklist.calcularPorcentajeCumplimiento().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                Text(
                  'Progreso por Secciones:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                SizedBox(height: 8),
                
                ...checklist.secciones.map((seccion) {
                  int completados = seccion.items.where((item) => item.respuesta != null).length;
                  int conFotos = seccion.items.where((item) => item.fotoBase64 != null).length;
                  int conObservaciones = seccion.items.where((item) => item.observaciones != null).length;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seccion.nombre,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Items: $completados/${seccion.items.length}', style: TextStyle(fontSize: 11)),
                            Text('Fotos: $conFotos', style: TextStyle(fontSize: 11, color: Colors.blue[600])),
                            Text('Obs: $conObservaciones', style: TextStyle(fontSize: 11, color: Colors.orange[600])),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error cargando detalles: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Registros Locales',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Actualizar registros',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.red[700]),
                  SizedBox(height: 16),
                  Text(
                    'Cargando registros...',
                    style: TextStyle(color: Colors.red[700], fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Estadísticas
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border(bottom: BorderSide(color: Colors.red[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Total', stats['total'] ?? 0, Colors.blue[600]!),
                      _buildStatCard('Enviados', stats['enviados'] ?? 0, Colors.green[600]!),
                      _buildStatCard('Pendientes', stats['pendientes'] ?? 0, Colors.orange[600]!),
                    ],
                  ),
                ),

                // Lista de registros
                Expanded(
                  child: records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No hay registros guardados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Los checklist guardados aparecerán aquí',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> record = records[index];
                            bool enviado = record['enviado'] == 1;
                            DateTime fecha = DateTime.parse(record['fecha_creacion']);

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: enviado ? Colors.green[200]! : Colors.red[200]!,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header con estado y fecha
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: enviado ? Colors.green[100] : Colors.orange[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            enviado ? 'ENVIADO' : 'PENDIENTE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: enviado ? Colors.green[700] : Colors.orange[700],
                                            ),
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 12),

                                    // Información principal
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                record['finca_nombre'] ?? 'Sin finca',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                'Supervisor: ${record['supervisor_nombre'] ?? "N/A"}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                'Pesador: ${record['pesador_nombre'] ?? "N/A"}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                'Usuario: ${record['usuario_nombre'] ?? "N/A"}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Indicador de cumplimiento
                                        Column(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.red[200]!),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${(record['porcentaje_cumplimiento'] ?? 0.0).toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red[700],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Cumplimiento',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 16),

                                    // Botones de acción
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _viewChecklistDetails(record['id']),
                                            icon: Icon(Icons.visibility, size: 16),
                                            label: Text('Ver Detalles'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.blue[700],
                                              side: BorderSide(color: Colors.blue[300]!),
                                              padding: EdgeInsets.symmetric(vertical: 8),
                                            ),
                                          ),
                                        ),
                                        
                                        SizedBox(width: 8),
                                        
                                        if (!enviado) ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _isSending ? null : () => _sendToServer(record['id']),
                                              icon: _isSending 
                                                  ? SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Icon(Icons.cloud_upload, size: 16),
                                              label: Text(_isSending ? 'Enviando...' : 'Enviar'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green[600],
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(vertical: 8),
                                              ),
                                            ),
                                          ),
                                          
                                          SizedBox(width: 8),
                                        ],
                                        
                                        IconButton(
                                          onPressed: () => _deleteRecord(record['id']),
                                          icon: Icon(Icons.delete, color: Colors.red[600]),
                                          tooltip: 'Eliminar registro',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}