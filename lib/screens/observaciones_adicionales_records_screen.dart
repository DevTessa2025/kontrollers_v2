import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/observaciones_adicionales_service.dart';
import 'observaciones_adicionales_screen.dart';
import '../services/observaciones_adicionales_export_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ObservacionesAdicionalesRecordsScreen extends StatefulWidget {
  const ObservacionesAdicionalesRecordsScreen({Key? key}) : super(key: key);

  @override
  State<ObservacionesAdicionalesRecordsScreen> createState() => _ObservacionesAdicionalesRecordsScreenState();
}

class _ObservacionesAdicionalesRecordsScreenState extends State<ObservacionesAdicionalesRecordsScreen> {
  bool _loading = true;
  List<ObservacionAdicional> _items = [];
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ObservacionesAdicionalesService.getAll();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final res = await ObservacionesAdicionalesService.syncToServer();
    setState(() => _syncing = false);
    await _load();
    if (!mounted) return;
    Fluttertoast.showToast(
      msg: 'Sync: ${res['synced']} ok, ${res['failed']} errores',
      backgroundColor: res['failed'] > 0 ? Colors.orange[600] : Colors.green[600],
      textColor: Colors.white,
    );
  }

  Future<void> _syncIndividual(ObservacionAdicional item) async {
    try {
      final result = await ObservacionesAdicionalesService.syncIndividualToServer(item.id!);
      
      await _load();
      if (!mounted) return;
      
      if (result['success']) {
        Fluttertoast.showToast(
          msg: result['message'],
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: result['message'],
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error al sincronizar: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _eliminar(ObservacionAdicional item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de que desea eliminar esta observación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ObservacionesAdicionalesService.softDelete(item.id!);
        await _load();
        Fluttertoast.showToast(
          msg: 'Observación eliminada',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error al eliminar: $e',
          backgroundColor: Colors.red[600],
          textColor: Colors.white,
        );
      }
    }
  }

  void _verDetalles(ObservacionAdicional item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => _buildDetallesModal(item, scrollController),
      ),
    );
  }

  void _editar(ObservacionAdicional item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObservacionesAdicionalesScreen(
          observacionParaEditar: item,
        ),
      ),
    ).then((_) => _load());
  }

  Uint8List _b64ToBytes(String b64) => base64Decode(b64);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Registros de Observaciones'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: _syncing ? null : _sync,
            icon: _syncing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Sincronizar todo',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildStatsHeader(),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildItemCard(item);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _openExportDialog() async {
    final fincas = _items.map((e) => e.fincaNombre).toSet().toList()..sort();
    final Set<String> seleccionadas = { ...fincas };
    DateTime? fi;
    DateTime? ff;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Exportar a Word'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fincas'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: fincas.map((f) => FilterChip(
                      label: Text(f),
                      selected: seleccionadas.contains(f),
                      onSelected: (sel) => setS(() { if (sel) seleccionadas.add(f); else seleccionadas.remove(f); }),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Rango de fechas'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: ctx, initialDate: fi ?? DateTime.now().subtract(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setS(() => fi = d);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(fi == null ? 'Fecha inicio' : '${fi!.day}/${fi!.month}/${fi!.year}'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(context: ctx, initialDate: ff ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setS(() => ff = d);
                      },
                      icon: const Icon(Icons.event),
                      label: Text(ff == null ? 'Fecha fin' : '${ff!.day}/${ff!.month}/${ff!.year}'),
                    )),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _exportWord(seleccionadas.toList(), fi, ff);
                },
                icon: const Icon(Icons.download),
                label: const Text('Exportar'),
              )
            ],
          );
        });
      }
    );
  }

  Future<void> _exportWord(List<String> fincasSel, DateTime? fi, DateTime? ff) async {
    try {
      final filtered = _items.where((e) {
        final matchFinca = fincasSel.isEmpty || fincasSel.contains(e.fincaNombre);
        final matchFecha = (fi == null || (e.fechaCreacion ?? DateTime(2000)).isAfter(fi.subtract(const Duration(days: 1)))) &&
                           (ff == null || (e.fechaCreacion ?? DateTime(2100)).isBefore(ff.add(const Duration(days: 1))));
        return matchFinca && matchFecha;
      }).map((e) => e.toMap()).toList();

      final docBytes = await ObservacionesAdicionalesExportService.buildWordDocHtml(
        records: filtered,
        fincas: fincasSel,
        fechaInicio: fi,
        fechaFin: ff,
      );

      final dir = await getExternalStorageDirectory();
      final String fincaPart = fincasSel.isEmpty ? 'Todas' : fincasSel.join('_').replaceAll(' ', '_');
      final String fecha = DateTime.now().toString().substring(0, 10).replaceAll('-', '');
      final file = File('${dir!.path}/Observaciones_Adicionales_${fincaPart}_$fecha.doc');
      await file.writeAsBytes(docBytes);

      Fluttertoast.showToast(msg: 'Word exportado: ${file.path}', backgroundColor: Colors.green[600], textColor: Colors.white);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error exportando: $e', backgroundColor: Colors.red[600], textColor: Colors.white);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay observaciones registradas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera observación desde el menú principal',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final total = _items.length;
    final sincronizadas = _items.where((item) => item.enviado == 1).length;
    final pendientes = total - sincronizadas;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Total', total.toString(), Colors.teal[700]!),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem('Sincronizadas', sincronizadas.toString(), Colors.green[600]!),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: _buildStatItem('Pendientes', pendientes.toString(), Colors.orange[600]!),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ObservacionAdicional item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _verDetalles(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTipoColor(item.tipo).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getTipoColor(item.tipo)),
                    ),
                    child: Text(
                      item.tipo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getTipoColor(item.tipo),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildSyncStatus(item),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${item.fincaNombre} - ${item.bloqueNombre} - ${item.variedadNombre}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.observacion,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Indicador de datos MIPE
              if (item.tipo == 'MIPE' && _hasMIPEData(item)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_outlined, size: 14, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Datos MIPE disponibles',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.image_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${item.imagenesBase64.length} imagen${item.imagenesBase64.length == 1 ? '' : 'es'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(item.fechaCreacion),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.visibility_outlined,
                      label: 'Ver',
                      color: Colors.blue[600]!,
                      onTap: () => _verDetalles(item),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Editar',
                      color: Colors.orange[600]!,
                      onTap: () => _editar(item),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: item.enviado == 1 ? Icons.cloud_done : Icons.cloud_upload_outlined,
                      label: item.enviado == 1 ? 'Sincronizado' : 'Sincronizar',
                      color: item.enviado == 1 ? Colors.green[600]! : Colors.purple[600]!,
                      onTap: item.enviado == 1 ? null : () => _syncIndividual(item),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Eliminar',
                      color: Colors.red[600]!,
                      onTap: () => _eliminar(item),
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

  Widget _buildSyncStatus(ObservacionAdicional item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: item.enviado == 1 ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.enviado == 1 ? Colors.green[300]! : Colors.orange[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.enviado == 1 ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: item.enviado == 1 ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 4),
          Text(
            item.enviado == 1 ? 'Sincronizado' : 'Pendiente',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: item.enviado == 1 ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? color.withOpacity(0.3) : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap != null ? color : Colors.grey[400],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: onTap != null ? color : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getTipoColor(String tipo) {
    switch (tipo) {
      case 'MIPE':
        return Colors.blue[600]!;
      case 'CULTIVO':
        return Colors.green[600]!;
      case 'MIRFE':
        return Colors.purple[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _hasMIPEData(ObservacionAdicional item) {
    return (item.blancoBiologico != null && item.blancoBiologico!.isNotEmpty) ||
           item.incidencia != null ||
           item.severidad != null ||
           (item.tercio != null && item.tercio!.isNotEmpty);
  }

  Widget _buildDetallesModal(ObservacionAdicional item, ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Detalles de la Observación',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Información General', [
                    _buildDetailRow('Tipo', item.tipo, _getTipoColor(item.tipo)),
                    _buildDetailRow('Finca', item.fincaNombre),
                    _buildDetailRow('Bloque', item.bloqueNombre),
                    _buildDetailRow('Variedad', item.variedadNombre),
                    _buildDetailRow('Usuario', item.usuarioNombre ?? 'N/A'),
                    _buildDetailRow('Fecha', _formatDate(item.fechaCreacion)),
                  ]),
                  const SizedBox(height: 20),
                  _buildDetailSection('Observación', [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        item.observacion,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ]),
                  // Campos MIPE si el tipo es MIPE
                  if (item.tipo == 'MIPE') ...[
                    const SizedBox(height: 20),
                    _buildDetailSection('Datos MIPE', [
                      if (item.blancoBiologico != null && item.blancoBiologico!.isNotEmpty)
                        _buildDetailRow('Blanco Biológico', item.blancoBiologico!),
                      if (item.incidencia != null)
                        _buildDetailRow('Incidencia', '${item.incidencia}%'),
                      if (item.severidad != null)
                        _buildDetailRow('Severidad', '${item.severidad}%'),
                      if (item.tercio != null && item.tercio!.isNotEmpty)
                        _buildDetailRow('Tercio', item.tercio!),
                    ]),
                  ],
                  if (item.imagenesBase64.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection('Imágenes (${item.imagenesBase64.length})', [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: item.imagenesBase64.length,
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _b64ToBytes(item.imagenesBase64[index]),
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  _buildDetailSection('Estado', [
                    _buildDetailRow('Sincronización', 
                        item.enviado == 1 ? 'Sincronizado' : 'Pendiente',
                        item.enviado == 1 ? Colors.green[600]! : Colors.orange[600]!),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.teal[700],
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.grey[800],
                fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


