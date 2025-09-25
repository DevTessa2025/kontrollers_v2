import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import '../services/checklist_storage_service.dart';
import '../services/sql_server_service.dart';
import '../services/date_helper.dart';
import '../data/checklist_data.dart';
import 'checklist_bodega_screen.dart';

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
    // Verificar que el checklist esté completo antes de enviar
    bool isComplete = await ChecklistStorageService.isChecklistComplete(recordId);
    
    if (!isComplete) {
      bool? continueEdit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Checklist Incompleto',
            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Este checklist no está completo. No se puede enviar al servidor hasta que todos los ítems tengan una respuesta.\n\n¿Desea continuar llenándolo?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Continuar Llenando'),
            ),
          ],
        ),
      );

      if (continueEdit == true) {
        await _editChecklist(recordId);
      }
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      var record = records.firstWhere((r) => r['id'] == recordId);

      String insertQuery = _generateInsertQuery(record);

      await SqlServerService.executeQuery(insertQuery);

      await ChecklistStorageService.markAsEnviado(recordId);

      Fluttertoast.showToast(
        msg: 'Registro enviado exitosamente al servidor',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );

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

  Future<void> _editChecklist(int recordId) async {
    try {
      ChecklistBodega? checklist = await ChecklistStorageService.getChecklistById(recordId);
      
      if (checklist == null) {
        Fluttertoast.showToast(
          msg: 'No se pudo cargar el checklist para editar',
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
        return;
      }

      // Verificar si ya fue enviado
      var record = records.firstWhere((r) => r['id'] == recordId);
      if (record['enviado'] == 1) {
        Fluttertoast.showToast(
          msg: 'No se puede editar un checklist que ya fue enviado al servidor',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
        return;
      }

      // Navegar a la pantalla de edición
      bool? updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistBodegaScreen(
            checklistToEdit: checklist,
            recordId: recordId,
          ),
        ),
      );

      // Si se actualizó, recargar la lista
      if (updated == true) {
        await _loadRecords();
      }

    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error cargando checklist para editar: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  bool _isRecordComplete(Map<String, dynamic> record) {
    for (int i = 1; i <= 20; i++) {
      if (record['item_${i}_respuesta'] == null) {
        return false;
      }
    }
    return true;
  }

  String _generateInsertQuery(Map<String, dynamic> record) {
    String escapeValue(dynamic value) {
      if (value == null) return 'NULL';
      if (value is String) return "'${value.replaceAll("'", "''")}'";
      return value.toString();
    }

    String formatDate(String dateString) {
      try {
        // Debug del string de entrada
        DateHelper.debugDateString(dateString);
        
        DateTime date = DateTime.parse(dateString);
        
        // Usar formato más robusto para SQL Server
        String formatted = "CONVERT(DATETIME2, '${date.toIso8601String().replaceAll('T', ' ').substring(0, 19)}', 126)";
        
        print('🔍 DEBUG FECHA - Input: $dateString');
        print('🔍 DEBUG FECHA - Parsed: $date');
        print('🔍 DEBUG FECHA - Formatted: $formatted');
        return formatted;
      } catch (e) {
        print('🔍 DEBUG FECHA - Error parsing date: $e');
        return 'GETDATE()';
      }
    }

    // Generar un UUID único para este checklist
    var uuid = const Uuid();
    String checklistUuid = uuid.v4();

    List<String> columnNames = [
      'checklist_uuid',
      'finca_nombre', 'supervisor_id', 'supervisor_nombre', 'pesador_id', 'pesador_nombre',
      'usuario_id', 'usuario_nombre', 'fecha_creacion', 'porcentaje_cumplimiento', 'fecha_envio'
    ];
    List<String> values = [
      escapeValue(checklistUuid),
      escapeValue(record['finca_nombre']),
      escapeValue(record['supervisor_id']),
      escapeValue(record['supervisor_nombre']),
      escapeValue(record['pesador_id']),
      escapeValue(record['pesador_nombre']),
      escapeValue(record['usuario_id']),
      escapeValue(record['usuario_nombre']),
      formatDate(record['fecha_creacion']),
      escapeValue(record['porcentaje_cumplimiento']),
      'GETDATE()'
    ];

    for (int i = 1; i <= 20; i++) {
      columnNames.add('item_${i}_respuesta');
      values.add(escapeValue(record['item_${i}_respuesta']));
      columnNames.add('item_${i}_valor_numerico');
      values.add(escapeValue(record['item_${i}_valor_numerico']));
      columnNames.add('item_${i}_observaciones');
      values.add(escapeValue(record['item_${i}_observaciones']));
      columnNames.add('item_${i}_foto_base64');
      values.add(escapeValue(record['item_${i}_foto_base64']));
    }

    return 'INSERT INTO check_bodega (${columnNames.join(', ')}) VALUES (${values.join(', ')})';
  }

  Future<void> _deleteRecord(int recordId) async {
    // Verificar si ya fue enviado
    var record = records.firstWhere((r) => r['id'] == recordId);
    bool enviado = record['enviado'] == 1;

    String confirmMessage = enviado 
        ? '¿Está seguro que desea eliminar este registro enviado? Esta acción no se puede deshacer.'
        : '¿Está seguro que desea eliminar este registro? Esta acción no se puede deshacer.';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirmar Eliminación',
          style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
        ),
        content: Text(confirmMessage),
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
                // Estadísticas mejoradas
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border(bottom: BorderSide(color: Colors.red[200]!)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatCard('Total', stats['total'] ?? 0, Colors.blue[600]!),
                          _buildStatCard('Completos', stats['completos'] ?? 0, Colors.green[600]!),
                          _buildStatCard('Incompletos', stats['incompletos'] ?? 0, Colors.orange[600]!),
                          _buildStatCard('Enviados', stats['enviados'] ?? 0, Colors.purple[600]!),
                        ],
                      ),
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
                            bool completo = _isRecordComplete(record);
                            DateTime fecha = DateTime.parse(record['fecha_creacion']);

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: enviado 
                                      ? Colors.green[200]!
                                      : completo
                                          ? Colors.blue[200]!
                                          : Colors.orange[200]!,
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
                                            color: enviado 
                                                ? Colors.green[100]
                                                : completo
                                                    ? Colors.blue[100]
                                                    : Colors.orange[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            enviado 
                                                ? 'ENVIADO'
                                                : completo
                                                    ? 'COMPLETO'
                                                    : 'INCOMPLETO',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: enviado 
                                                  ? Colors.green[700]
                                                  : completo
                                                      ? Colors.blue[700]
                                                      : Colors.orange[700],
                                            ),
                                          ),
                                        ),
                                        if (!completo && !enviado) ...[
                                          SizedBox(width: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'NECESITA COMPLETARSE',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red[700],
                                              ),
                                            ),
                                          ),
                                        ],
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
                                            child: OutlinedButton.icon(
                                              onPressed: () => _editChecklist(record['id']),
                                              icon: Icon(Icons.edit, size: 16),
                                              label: Text(completo ? 'Editar' : 'Completar'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: completo ? Colors.blue[700] : Colors.orange[700],
                                                side: BorderSide(color: completo ? Colors.blue[300]! : Colors.orange[300]!),
                                                padding: EdgeInsets.symmetric(vertical: 8),
                                              ),
                                            ),
                                          ),

                                          SizedBox(width: 8),

                                          if (completo)
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

                                        // IconButton(
                                        //   onPressed: () => _deleteRecord(record['id']),
                                        //   icon: Icon(Icons.delete, color: Colors.red[600]),
                                        //   tooltip: 'Eliminar registro',
                                        // ),
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