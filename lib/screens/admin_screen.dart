import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kontrollers_v2/services/pdf_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../services/admin_service.dart';
import '../widget/share_dialog_widget.dart';
import '../services/observaciones_adicionales_export_service.dart';
import '../services/observaciones_adicionales_excel_service.dart';
import '../services/email_service.dart';
import 'observaciones_adicionales_admin_detail_screen.dart';
import 'cortes_admin_screen.dart';
import 'labores_permanentes_admin_screen.dart';
import 'labores_temporales_admin_screen.dart';
import 'observaciones_adicionales_admin_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _hasAdminPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminPermissions();
  }

  Future<void> _checkAdminPermissions() async {
    bool isAdmin = await AdminService.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _hasAdminPermissions = isAdmin;
        _isLoading = false;
      });
    }

    if (!isAdmin) {
      // Si no es admin, regresar después de 2 segundos
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Verificando permisos...'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red[700]),
              SizedBox(height: 16),
              Text('Validando acceso...'),
            ],
          ),
        ),
      );
    }

    if (!_hasAdminPermissions) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Acceso Denegado'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 80,
                color: Colors.red[300],
              ),
              SizedBox(height: 20),
              Text(
                'No tienes permisos de administrador',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Contacta al administrador del sistema',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 30),
              Text(
                'Regresando automáticamente...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Administración'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red[700]!,
              Colors.red[50]!,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con información del admin
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.admin_panel_settings,
                            color: Colors.red[700], size: 32),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panel de Administración',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Acceso completo a registros del sistema',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                Text(
                  'Registros de Checklists',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Selecciona el tipo de checklist para ver sus registros',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),

                SizedBox(height: 24),

                // Grid de botones para cada tipo de checklist
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildChecklistCard(
                        title: 'Fertirriego',
                        subtitle: 'Finca • Bloque',
                        icon: Icons.water_drop,
                        color: Colors.blue,
                        onTap: () => _navigateToRecords('fertirriego'),
                      ),
                      _buildChecklistCard(
                        title: 'Bodega',
                        subtitle: 'Finca • Supervisor • Pesador',
                        icon: Icons.warehouse,
                        color: Colors.orange,
                        onTap: () => _navigateToRecords('bodega'),
                      ),
                      _buildChecklistCard(
                        title: 'Aplicaciones',
                        subtitle: 'Finca • Bloque • Bomba',
                        icon: Icons.sanitizer,
                        color: Colors.green,
                        onTap: () => _navigateToRecords('aplicaciones'),
                      ),
                      _buildChecklistCard(
                        title: 'Cosechas',
                        subtitle: 'Finca • Bloque • Variedad',
                        icon: Icons.agriculture,
                        color: Colors.purple,
                        onTap: () => _navigateToRecords('cosecha'),
                      ),
                      _buildChecklistCard(
                        title: 'Cortes del Día',
                        subtitle: 'Finca • Bloque • Variedad',
                        icon: Icons.content_cut,
                        color: Colors.red,
                        onTap: () => _navigateToRecords('cortes'),
                      ),
                      _buildChecklistCard(
                        title: 'Labores Permanentes',
                        subtitle: 'Finca • Bloque • Variedad',
                        icon: Icons.agriculture,
                        color: Colors.deepPurple,
                        onTap: () => _navigateToRecords('labores_permanentes'),
                      ),
                      _buildChecklistCard(
                        title: 'Labores Temporales',
                        subtitle: 'Finca • Bloque • Variedad',
                        icon: Icons.construction,
                        color: Colors.amber,
                        onTap: () => _navigateToRecords('labores_temporales'),
                      ),
                      _buildChecklistCard(
                        title: 'Observaciones Adicionales',
                        subtitle: 'Finca • Bloque • Variedad',
                        icon: Icons.note_alt,
                        color: Colors.teal,
                        onTap: () => _navigateToRecords('observaciones_adicionales'),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Información adicional
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[600], size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información importante',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Los datos se consultan directamente del servidor. Requiere conexión a internet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRecords(String checklistType) {
    if (checklistType == 'cortes') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CortesAdminScreen(),
        ),
      );
    } else if (checklistType == 'labores_permanentes') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LaboresPermanentesAdminScreen(),
        ),
      );
    } else if (checklistType == 'labores_temporales') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LaboresTemporalesAdminScreen(),
        ),
      );
    } else if (checklistType == 'observaciones_adicionales') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ObservacionesAdicionalesAdminScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChecklistRecordsScreen(checklistType: checklistType),
        ),
      );
    }
  }
}

// ==================== PANTALLA DE REGISTROS ====================

class ChecklistRecordsScreen extends StatefulWidget {
  final String checklistType;

  ChecklistRecordsScreen({required this.checklistType});

  @override
  _ChecklistRecordsScreenState createState() => _ChecklistRecordsScreenState();
}

class _ChecklistRecordsScreenState extends State<ChecklistRecordsScreen> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _fincas = [];
  Map<String, dynamic> _statistics = {};

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showFilters = false;

  // Filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  int? _selectedUserId;
  String? _selectedFinca;

  String _exportFormato = 'pdf';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    // Limpiar cualquier operación pendiente
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUsers();
    await _loadFincas();
     await _loadRecords();
  }

  Future<void> _loadUsers() async {
    try {
      List<Map<String, dynamic>> users = await AdminService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
        });
      }
    } catch (e) {
      print('Error cargando usuarios: $e');
    }
  }

  Future<void> _loadFincas() async {
    try {
      List<String> fincas = await AdminService.getAllFincas();
      if (mounted) {
        setState(() {
          _fincas = fincas;
        });
      }
    } catch (e) {
      print('Error cargando fincas: $e');
    }
  }

  Future<void> _loadRecords() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      Map<String, dynamic> result;

      switch (widget.checklistType) {
        case 'fertirriego':
          result = await AdminService.getFertiriegoRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'bodega':
          result = await AdminService.getBodegaRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'aplicaciones':
          result = await AdminService.getAplicacionesRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'cosecha':
          result = await AdminService.getCosechasRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'cortes':
          result = await AdminService.getCortesRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'labores_permanentes':
          result = await AdminService.getLaboresPermanentesRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'labores_temporales':
          result = await AdminService.getLaboresTemporalesRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'observaciones_adicionales':
          result = await AdminService.getObservacionesAdicionalesRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        default:
          throw Exception('Tipo de checklist no válido');
      }

      if (mounted) {
        setState(() {
          _records = result['records'] ?? [];
          _statistics = result['statistics'] ?? {};
          _isLoading = false;
          _hasError = !result['success'];
          _errorMessage = result['error'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_getChecklistTitle()} - Registros'),
        backgroundColor: _getChecklistColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
        if (widget.checklistType == 'observaciones_adicionales')
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Exportar a Word (Deshabilitado)',
            onPressed: null, // Deshabilitado temporalmente
          ),
        if (widget.checklistType == 'observaciones_adicionales')
          IconButton(
            icon: const Icon(Icons.email_outlined),
            tooltip: 'Enviar Word por correo (Deshabilitado)',
            onPressed: null, // Deshabilitado temporalmente
          ),
          IconButton(
            icon:
                Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _showFilters = !_showFilters;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getChecklistColor(),
              Colors.grey[50]!,
            ],
            stops: [0.0, 0.2],
          ),
        ),
        child: Column(
          children: [
            // Panel de filtros (desplegable)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _showFilters ? null : 0,
              child: _showFilters ? _buildFiltersPanel() : Container(),
            ),

            // Estadísticas
            if (_statistics.isNotEmpty && !_isLoading) _buildStatistics(),

            // Lista de registros
            Expanded(
              child: _buildRecordsList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExportObservacionesWord() async {
    // Obtener fincas únicas de los resultados actuales
    final fincas = _records.map((r) => r['finca_nombre']?.toString() ?? '').where((s) => s.isNotEmpty).toSet().toList()..sort();
    final Set<String> seleccionadas = {...fincas};
    DateTime? fi = _fechaInicio;
    DateTime? ff = _fechaFin;
    final TextEditingController emailsCtrl = TextEditingController();
    final List<String> destinatarios = [];

    await showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Exportar Observaciones a Word'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fincas (selección múltiple)'),
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
                    label: Text(fi == null ? 'Fecha inicio' : DateFormat('dd/MM/yyyy').format(fi!)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(context: ctx, initialDate: ff ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (d != null) setS(() => ff = d);
                    },
                    icon: const Icon(Icons.event),
                    label: Text(ff == null ? 'Fecha fin' : DateFormat('dd/MM/yyyy').format(ff!)),
                  )),
                ]),
                const SizedBox(height: 16),
                // Selección de formato
                const Text('Formato'),
                Row(children: [
                  Expanded(child: RadioListTile<String>(
                    value: 'pdf',
                    groupValue: _exportFormato,
                    title: const Text('PDF'),
                    onChanged: (v) => setS(() { _exportFormato = v ?? 'pdf'; }),
                    dense: true,
                  )),
                  Expanded(child: RadioListTile<String>(
                    value: 'excel',
                    groupValue: _exportFormato,
                    title: const Text('Excel (con imágenes)'),
                    onChanged: (v) => setS(() { _exportFormato = v ?? 'excel'; }),
                    dense: true,
                  )),
                ]),
                const SizedBox(height: 16),
                const Text('Enviar por correo (opcional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: emailsCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Destinatarios',
                    helperText: 'Escribe la primera parte: nombre.apellido',
                    prefixIcon: const Icon(Icons.person_add_alt_1),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Agregar',
                      onPressed: () {
                        final parts = emailsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
                        setS(() {
                          for (final p in parts) {
                            final processed = EmailService.procesarEmail(p);
                            if (processed.isNotEmpty && EmailService.validarEmail(processed) && !destinatarios.contains(processed)) {
                              destinatarios.add(processed);
                            }
                          }
                          emailsCtrl.clear();
                        });
                      },
                    ),
                  ),
                  onSubmitted: (_) {
                    final processed = EmailService.procesarEmail(emailsCtrl.text.trim());
                    if (processed.isNotEmpty && EmailService.validarEmail(processed)) {
                      setS(() { destinatarios.add(processed); emailsCtrl.clear(); });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (destinatarios.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: destinatarios.map((e) => Chip(
                      label: Text(e),
                      onDeleted: () => setS(() { destinatarios.remove(e); }),
                    )).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: null, // Deshabilitado temporalmente
              icon: const Icon(Icons.download),
              label: const Text('Exportar (Deshabilitado)'),
            ),
          ],
        );
      });
    });
  }

  Future<void> _exportObservacionesFlexible(
    List<String> fincasSel, DateTime? fi, DateTime? ff, {List<String>? emailsList, String? formato}) async {
    try {
      final filtered = _records.where((r) {
        final finca = (r['finca_nombre'] ?? '').toString();
        final matchFinca = fincasSel.isEmpty || fincasSel.contains(finca);
        DateTime? fc;
        try { fc = r['fecha_creacion'] != null ? DateTime.parse(r['fecha_creacion']) : null; } catch (_) {}
        final matchFecha = (fi == null || (fc ?? DateTime(2000)).isAfter(fi.subtract(const Duration(days: 1)))) &&
                           (ff == null || (fc ?? DateTime(2100)).isBefore(ff.add(const Duration(days: 1))));
        return matchFinca && matchFecha;
      }).toList();

      Directory? dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
      final String fincaPart = fincasSel.isEmpty ? 'Todas' : fincasSel.join('_').replaceAll(' ', '_');
      final String fecha = DateFormat('yyyyMMdd').format(DateTime.now());

      if ((formato ?? 'pdf') == 'excel') {
        // Usar el nuevo servicio de Excel con formato visualmente agradable
        final bytes = await ObservacionesAdicionalesExcelService.buildExcelHtml(
          records: filtered,
          fincas: fincasSel,
          fechaInicio: fi,
          fechaFin: ff,
        );
        final file = File('${dir!.path}/Observaciones_Adicionales_${fincaPart}_$fecha.xls');
        await file.writeAsBytes(bytes);

        if ((emailsList ?? []).isNotEmpty) {
          final res = await EmailService.enviarAdjunto(
            destinatarios: emailsList!,
            bytes: bytes,
            fileName: 'Observaciones_Adicionales_${fincaPart}_$fecha.xls',
            mimeType: 'application/vnd.ms-excel',
            asunto: 'Observaciones Adicionales (Excel) - ${fincasSel.isEmpty ? 'Todas' : fincasSel.join(', ')}',
            cuerpoMensaje: 'Se adjunta archivo Excel con observaciones adicionales e imágenes.',
          );
          final ok = res['exito'] == true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Excel enviado por correo' : (res['mensaje'] ?? 'Error al enviar')),
              backgroundColor: ok ? Colors.green : Colors.red,
            ));
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel exportado: ${file.path}'), backgroundColor: Colors.green));
        }
        return;
      }

      // PDF simple por registro (sin anexos de imágenes para tamaño)
      final doc = pw.Document();
      for (final r in filtered) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (ctx) => [
              pw.Text('Observaciones Adicionales', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(border: pw.TableBorder.all(), children: [
                _pdfRow('ID', (r['id'] ?? '').toString()),
                _pdfRow('Finca', (r['finca_nombre'] ?? '').toString()),
                _pdfRow('Bloque', (r['bloque_nombre'] ?? '').toString()),
                _pdfRow('Variedad', (r['variedad_nombre'] ?? '').toString()),
                _pdfRow('Usuario', (r['usuario_nombre'] ?? '').toString()),
                _pdfRow('Tipo', (r['tipo'] ?? '').toString()),
                _pdfRow('Fecha', (r['fecha_creacion'] ?? '').toString()),
                _pdfRow('Observación', (r['observacion'] ?? '').toString()),
              ]),
              if ((r['tipo'] ?? '').toString().toUpperCase() == 'MIPE') ...[
                pw.SizedBox(height: 6),
                pw.Table(border: pw.TableBorder.all(), children: [
                  _pdfRow('Blanco Biológico', (r['blanco_biologico'] ?? '').toString()),
                  _pdfRow('Incidencia', (r['incidencia'] ?? '').toString()),
                  _pdfRow('Severidad', (r['severidad'] ?? '').toString()),
                  _pdfRow('Tercio', (r['tercio'] ?? '').toString()),
                ]),
              ],
            ],
          ),
        );
      }
      final bytes = await doc.save();
      final file = File('${dir!.path}/Observaciones_Adicionales_${fincaPart}_$fecha.pdf');
      await file.writeAsBytes(bytes);

      if ((emailsList ?? []).isNotEmpty) {
        final res = await EmailService.enviarAdjunto(
          destinatarios: emailsList!,
          bytes: bytes,
          fileName: 'Observaciones_Adicionales_${fincaPart}_$fecha.pdf',
          mimeType: 'application/pdf',
          asunto: 'Observaciones Adicionales (PDF) - ${fincasSel.isEmpty ? 'Todas' : fincasSel.join(', ')}',
          cuerpoMensaje: 'Se adjunta archivo PDF con observaciones adicionales.',
        );
        final ok = res['exito'] == true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'PDF enviado por correo' : (res['mensaje'] ?? 'Error al enviar')),
            backgroundColor: ok ? Colors.green : Colors.red,
          ));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF exportado: ${file.path}'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando: $e'), backgroundColor: Colors.red));
    }
  }

  pw.TableRow _pdfRow(String k, String v) {
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(v)),
    ]);
  }

  Future<void> _openSendWordDialog() async {
    final TextEditingController emailsCtrl = TextEditingController();
    final Set<String> fincasSel = _records.map((r) => (r['finca_nombre'] ?? '').toString()).where((s) => s.isNotEmpty).toSet();
    await showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Enviar Word por correo'),
        content: TextField(
          controller: emailsCtrl,
          decoration: const InputDecoration(labelText: 'Destinatarios (separados por coma)', prefixIcon: Icon(Icons.person_add_alt)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendWordByEmail(emailsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), fincasSel.toList());
            },
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
          )
        ],
      );
    });
  }

  Future<void> _sendWordByEmail(List<String> emails, List<String> fincasSel) async {
    try {
      // Reutilizar el export actual en memoria
      final bytes = await ObservacionesAdicionalesExportService.buildWordDocHtml(
        records: _records,
        fincas: fincasSel,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
      );

      // Enviar como adjunto genérico usando EmailService.enviarCorreoSimple con cuerpo HTML y adjunto manual no soportado
      // Como EmailService actual adjunta PDFs, aquí guardamos primero y compartimos la ruta si deseas. Para enviar adjunto .doc
      // necesitaríamos extender EmailService; si lo ves necesario, lo agrego. Por ahora guardo y muestro ruta.

      Directory? dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
      final String fincaPart = fincasSel.isEmpty ? 'Todas' : fincasSel.join('_').replaceAll(' ', '_');
      final String fecha = DateFormat('yyyyMMdd').format(DateTime.now());
      final file = File('${dir!.path}/Observaciones_Adicionales_${fincaPart}_$fecha.doc');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archivo generado en: ${file.path}. Ahora puede compartirlo desde su gestor de archivos o WhatsApp/Correo.'), backgroundColor: Colors.blue));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al preparar envío: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: _getChecklistColor()),
              SizedBox(width: 8),
              Text(
                'Filtros de búsqueda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Filtros de fecha
          Row(
            children: [
              Expanded(
                child: _buildDateFilter(
                  label: 'Fecha inicio',
                  date: _fechaInicio,
                  onTap: () => _selectDate(context, true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDateFilter(
                  label: 'Fecha fin',
                  date: _fechaFin,
                  onTap: () => _selectDate(context, false),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Filtros de usuario y finca
          Row(
            children: [
              Expanded(
                child: _buildDropdownFilter<int>(
                  label: 'Usuario',
                  value: _selectedUserId,
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('Todos los usuarios'),
                    ),
                    ..._users
                        .map((user) => DropdownMenuItem<int>(
                              value: user['id'],
                              child: Text(user['nombre'] ?? user['username']),
                            ))
                        .toList(),
                  ],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        _selectedUserId = value;
                      });
                      _loadRecords();
                    }
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFilter<String>(
                  label: 'Finca',
                  value: _selectedFinca,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas las fincas'),
                    ),
                    ..._fincas
                        .map((finca) => DropdownMenuItem<String>(
                              value: finca,
                              child: Text(finca),
                            ))
                        .toList(),
                  ],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        _selectedFinca = value;
                      });
                      _loadRecords();
                    }
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Botones de acción
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: Icon(Icons.clear_all),
                label: Text('Limpiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadRecords,
                  icon: Icon(Icons.search),
                  label: Text('Aplicar filtros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getChecklistColor(),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? DateFormat('dd/MM/yyyy').format(date) : label,
                style: TextStyle(
                  color: date != null ? Colors.black : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            if (date != null)
              InkWell(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      if (label.contains('inicio')) {
                        _fechaInicio = null;
                      } else {
                        _fechaFin = null;
                      }
                    });
                    _loadRecords();
                  }
                },
                child: Icon(Icons.clear, size: 16, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildStatistics() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: _getChecklistColor()),
              SizedBox(width: 8),
              Text(
                'Estadísticas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Registros',
                  _statistics['total_registros']?.toString() ?? '0',
                  Icons.list_alt,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Promedio',
                  '${(_statistics['promedio_cumplimiento']?.toStringAsFixed(1) ?? '0')}%',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Usuarios',
                  _statistics['total_usuarios']?.toString() ?? '0',
                  Icons.people,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Fincas',
                  _statistics['total_fincas']?.toString() ?? '0',
                  Icons.location_on,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _getChecklistColor()),
            SizedBox(height: 16),
            Text(
              'Cargando registros...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                'Error al cargar registros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRecords,
                icon: Icon(Icons.refresh),
                label: Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getChecklistColor(),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No se encontraron registros',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Intenta ajustar los filtros de búsqueda',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: Icon(Icons.clear_all),
                label: Text('Limpiar filtros'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return _buildRecordCard(record);
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 4,
      child: InkWell(
        onTap: () => _showRecordDetail(record),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getCumplimientoColor(record['porcentaje_cumplimiento'])
                  .withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con ID y porcentaje
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getChecklistColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'ID ${record['id']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getChecklistColor(),
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getCumplimientoColor(
                                record['porcentaje_cumplimiento'])
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCumplimientoIcon(
                                record['porcentaje_cumplimiento']),
                            size: 14,
                            color: _getCumplimientoColor(
                                record['porcentaje_cumplimiento']),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${record['porcentaje_cumplimiento']?.toStringAsFixed(1) ?? '0'}%',
                            style: TextStyle(
                              color: _getCumplimientoColor(
                                  record['porcentaje_cumplimiento']),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // Información principal
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record['usuario_nombre'] ??
                            'Usuario ${record['usuario_id']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 6),

                if (record['finca_nombre'] != null)
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record['finca_nombre'],
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                // Campos específicos por tipo de checklist
                ..._buildSpecificFields(record),

                SizedBox(height: 12),

                // Fechas
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 12, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Creado: ${_formatDate(record['fecha_creacion'])}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload,
                                size: 12, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Enviado: ${_formatDate(record['fecha_envio'])}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                // Indicador de "Ver más"
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Toca para ver detalles',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getChecklistColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: _getChecklistColor(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Construir campos específicos según el tipo de checklist
  List<Widget> _buildSpecificFields(Map<String, dynamic> record) {
    List<Widget> fields = [];

    switch (widget.checklistType) {
      case 'fertirriego':
        // Fertirriego: finca y bloque
        if (record['bloque_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bloque: ${record['bloque_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;

      case 'bodega':
        // Bodega: finca, supervisor y pesador
        if (record['supervisor_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.supervisor_account, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Supervisor: ${record['supervisor_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        if (record['pesador_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.scale, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pesador: ${record['pesador_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;

      case 'aplicaciones':
        // Aplicaciones: finca, bloque y bomba
        if (record['bloque_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bloque: ${record['bloque_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        if (record['bomba_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.build, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bomba: ${record['bomba_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;

      case 'cosecha':
        // Cosechas: finca, bloque y variedad
        if (record['bloque_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bloque: ${record['bloque_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        if (record['variedad_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.eco, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Variedad: ${record['variedad_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;

      case 'cortes':
        // Cortes: finca, bloque y variedad
        if (record['bloque_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bloque: ${record['bloque_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        if (record['variedad_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.eco, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Variedad: ${record['variedad_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;

      case 'labores_permanentes':
        // Labores Permanentes: finca, bloque y variedad
        if (record['bloque_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bloque: ${record['bloque_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        if (record['variedad_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.eco, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Variedad: ${record['variedad_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;

      case 'labores_temporales':
        // Labores Temporales: finca, bloque y variedad
        if (record['bloque_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bloque: ${record['bloque_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        if (record['variedad_nombre'] != null) {
          fields.add(SizedBox(height: 4));
          fields.add(Row(
            children: [
              Icon(Icons.eco, size: 16, color: Colors.grey[600]),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Variedad: ${record['variedad_nombre']}',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ));
        }
        break;
    }

    return fields;
  }

  Color _getCumplimientoColor(dynamic porcentaje) {
    if (porcentaje == null) return Colors.grey;
    double value = porcentaje.toDouble();
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getCumplimientoIcon(dynamic porcentaje) {
    if (porcentaje == null) return Icons.help_outline;
    double value = porcentaje.toDouble();
    if (value >= 80) return Icons.check_circle;
    if (value >= 60) return Icons.warning;
    return Icons.error;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_fechaInicio ?? DateTime.now().subtract(Duration(days: 30)))
          : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
    );

    if (picked != null) {
      if (mounted) {
        setState(() {
          if (isStartDate) {
            _fechaInicio = picked;
          } else {
            _fechaFin = picked;
          }
        });
        _loadRecords();
      }
    }
  }

  void _clearFilters() {
    if (mounted) {
      setState(() {
        _fechaInicio = null;
        _fechaFin = null;
        _selectedUserId = null;
        _selectedFinca = null;
      });
      _loadRecords();
    }
  }

  void _showRecordDetail(Map<String, dynamic> record) {
    if (widget.checklistType == 'observaciones_adicionales') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ObservacionesAdicionalesAdminDetailScreen(
            record: record,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecordDetailScreen(
            record: record,
            checklistType: widget.checklistType,
          ),
        ),
      );
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
      case 'cosecha':
        return 'Cosechas';
      case 'cortes':
        return 'Cortes del Día';
      case 'labores_permanentes':
        return 'Labores Permanentes';
      case 'labores_temporales':
        return 'Labores Temporales';
      case 'observaciones_adicionales':
        return 'Observaciones Adicionales';
      default:
        return widget.checklistType;
    }
  }

  Color _getChecklistColor() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Colors.blue[700]!;
      case 'bodega':
        return Colors.orange[700]!;
      case 'aplicaciones':
        return Colors.green[700]!;
      case 'cosecha':
        return Colors.purple[700]!;
      case 'cortes':
        return Colors.red[700]!;
      case 'labores_permanentes':
        return Colors.deepPurple[700]!;
      case 'labores_temporales':
        return Colors.amber[700]!;
      case 'observaciones_adicionales':
        return Colors.teal[700]!;
      default:
        return Colors.red[700]!;
    }
  }
}

// ==================== PANTALLA DE DETALLE DE REGISTRO ====================

class RecordDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;
  final String checklistType;

  RecordDetailScreen({required this.record, required this.checklistType});

  @override
  _RecordDetailScreenState createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  Map<String, dynamic>? _fullRecord;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFullRecord();
  }

  @override
  void dispose() {
    // Limpiar cualquier operación pendiente
    super.dispose();
  }

  Future<void> _loadFullRecord() async {
    try {
      String tableName = widget.checklistType == 'observaciones_adicionales'
          ? 'observaciones_adicionales'
          : 'check_${widget.checklistType}';
      Map<String, dynamic>? fullRecord =
          await AdminService.getRecordDetail(tableName, widget.record['id']);

      if (mounted) {
        setState(() {
          _fullRecord = fullRecord;
          _isLoading = false;
          _hasError = fullRecord == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle - ID ${widget.record['id']}'),
        backgroundColor: _getChecklistColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Botón de compartir mejorado
          PopupMenuButton<String>(
            icon: Icon(Icons.share, color: Colors.white),
            iconSize: 24,
            tooltip: 'Compartir reporte',
            onSelected: (value) {
              if (value == 'share') {
                _showShareDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, color: _getChecklistColor(), size: 20),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compartir Reporte',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'PDF con detalles completos',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getChecklistColor(),
              Colors.grey[50]!,
            ],
            stops: [0.0, 0.2],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _hasError
                ? _buildErrorState()
                : _buildDetailContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _getChecklistColor()),
            SizedBox(height: 16),
            Text(
              'Cargando detalles...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              'Error cargando detalles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No se pudieron cargar los detalles del registro',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFullRecord,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getChecklistColor(),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    if (_fullRecord == null) return Container();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información general
          _buildInfoCard(),
          SizedBox(height: 16),

          // Contenido específico por tipo
          if (widget.checklistType == 'observaciones_adicionales')
            _buildObservacionesAdicionalesSection()
          else
            _buildItemsSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 8,
      shadowColor: _getChecklistColor().withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getChecklistColor().withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getChecklistColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: _getChecklistColor(),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Información General',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              _buildInfoRow('ID', _fullRecord!['id'].toString()),
              _buildInfoRow('UUID', _fullRecord!['checklist_uuid']?.toString() ?? 'N/A'),
              _buildInfoRow('Usuario', _fullRecord!['usuario_nombre'] ?? 'N/A'),
              _buildInfoRow('Finca', _fullRecord!['finca_nombre'] ?? 'N/A'),

              // Campos específicos por tipo de checklist
              ..._buildDetailSpecificFields(),

              _buildInfoRow('Fecha Creación',
                  _formatDetailDate(_fullRecord!['fecha_creacion'])),
              _buildInfoRow('Fecha Envío',
                  _formatDetailDate(_fullRecord!['fecha_envio'])),

              // Cumplimiento con estilo especial
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCumplimientoColor(
                          _fullRecord!['porcentaje_cumplimiento'])
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getCumplimientoColor(
                            _fullRecord!['porcentaje_cumplimiento'])
                        .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCumplimientoIcon(
                          _fullRecord!['porcentaje_cumplimiento']),
                      color: _getCumplimientoColor(
                          _fullRecord!['porcentaje_cumplimiento']),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cumplimiento:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_fullRecord!['porcentaje_cumplimiento']?.toStringAsFixed(1) ?? '0'}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getCumplimientoColor(
                            _fullRecord!['porcentaje_cumplimiento']),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Construir campos específicos para vista detallada
  List<Widget> _buildDetailSpecificFields() {
    List<Widget> fields = [];

    switch (widget.checklistType) {
      case 'fertirriego':
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('Bloque', _fullRecord!['bloque_nombre']));
        break;

      case 'bodega':
        if (_fullRecord!['supervisor_nombre'] != null)
          fields.add(
              _buildInfoRow('Supervisor', _fullRecord!['supervisor_nombre']));
        if (_fullRecord!['pesador_nombre'] != null)
          fields.add(_buildInfoRow('Pesador', _fullRecord!['pesador_nombre']));
        break;

      case 'aplicaciones':
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('Bloque', _fullRecord!['bloque_nombre']));
        if (_fullRecord!['bomba_nombre'] != null)
          fields.add(_buildInfoRow('Bomba', _fullRecord!['bomba_nombre']));
        break;

      case 'cosecha':
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('Bloque', _fullRecord!['bloque_nombre']));
        if (_fullRecord!['variedad_nombre'] != null)
          fields
              .add(_buildInfoRow('Variedad', _fullRecord!['variedad_nombre']));
        break;

      case 'cortes':
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('Supervisor', _fullRecord!['bloque_nombre']?.toString() ?? 'N/A'));
        break;

      case 'labores_permanentes':
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('UP', _fullRecord!['bloque_nombre']?.toString() ?? 'N/A'));
        break;

      case 'labores_temporales':
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('UP', _fullRecord!['bloque_nombre']?.toString() ?? 'N/A'));
        break;
      case 'observaciones_adicionales':
        fields.add(_buildInfoRow('Tipo', _fullRecord!['tipo']?.toString() ?? 'N/A'));
        if (_fullRecord!['bloque_nombre'] != null)
          fields.add(_buildInfoRow('Bloque', _fullRecord!['bloque_nombre']?.toString() ?? 'N/A'));
        if (_fullRecord!['variedad_nombre'] != null)
          fields.add(_buildInfoRow('Variedad', _fullRecord!['variedad_nombre']?.toString() ?? 'N/A'));
        // Campos MIPE si aplica
        if ((_fullRecord!['tipo']?.toString() ?? '').toUpperCase() == 'MIPE') {
          if (_fullRecord!['blanco_biologico'] != null && _fullRecord!['blanco_biologico'].toString().isNotEmpty)
            fields.add(_buildInfoRow('Blanco Biológico', _fullRecord!['blanco_biologico'].toString()));
          if (_fullRecord!['incidencia'] != null)
            fields.add(_buildInfoRow('Incidencia', '${_fullRecord!['incidencia']}%'));
          if (_fullRecord!['severidad'] != null)
            fields.add(_buildInfoRow('Severidad', '${_fullRecord!['severidad']}%'));
          if (_fullRecord!['tercio'] != null && _fullRecord!['tercio'].toString().isNotEmpty)
            fields.add(_buildInfoRow('Tercio', _fullRecord!['tercio'].toString()));
        }
        break;
    }

    return fields;
  }

  Widget _buildJsonDataSection() {
    return Card(
      elevation: 8,
      shadowColor: _getChecklistColor().withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getChecklistColor().withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getChecklistColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.assignment,
                      color: _getChecklistColor(),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Detalles del Checklist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Mostrar información de cuadrantes de forma estructurada
              if (_fullRecord!['cuadrantes_json'] != null)
                _buildStructuredData('Cuadrantes Evaluados', _fullRecord!['cuadrantes_json']),
              
              SizedBox(height: 16),
              
              // Mostrar información de items de forma estructurada
              if (_fullRecord!['items_json'] != null)
                _buildStructuredData('Resultados de Evaluación', _fullRecord!['items_json']),
              
              SizedBox(height: 16),
              
              // Mostrar observaciones generales si existen
              if (_fullRecord!['observaciones_generales'] != null && 
                  _fullRecord!['observaciones_generales'].toString().isNotEmpty)
                _buildObservacionesField(_fullRecord!['observaciones_generales']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredData(String title, dynamic jsonData) {
    try {
      dynamic parsedData;
      if (jsonData is String) {
        parsedData = json.decode(jsonData);
      } else {
        parsedData = jsonData;
      }

      if (parsedData == null) {
        return _buildEmptyDataCard(title);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _buildParsedDataContent(parsedData),
          ),
        ],
      );
    } catch (e) {
      // Si no se puede parsear como JSON, mostrar como texto
      return _buildTextData(title, jsonData.toString());
    }
  }

  Widget _buildParsedDataContent(dynamic data) {
    if (data is List) {
      return _buildArrayContent(data);
    } else if (data is Map<String, dynamic>) {
      return _buildObjectContent(data);
    } else {
      return Text(
        _formatValue(data),
        style: TextStyle(
          color: Colors.grey[800],
          fontSize: 13,
        ),
      );
    }
  }

  Widget _buildArrayContent(List<dynamic> array) {
    List<Widget> widgets = [];
    
    // Verificar si es un array de procesos (items de checklist)
    bool isProcessArray = array.isNotEmpty && 
        array.first is Map<String, dynamic> && 
        array.first.containsKey('proceso');
    
    if (isProcessArray) {
      return _buildProcessArrayContent(array);
    }
    
    for (int i = 0; i < array.length; i++) {
      dynamic item = array[i];
      
      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elemento ${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 6),
              if (item is Map<String, dynamic>)
                _buildObjectContent(item)
              else
                Text(
                  _formatValue(item),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(children: widgets);
  }

  Widget _buildProcessArrayContent(List<dynamic> processes) {
    List<Widget> widgets = [];
    
    // Agrupar por número de muestra (parada)
    Map<String, List<Map<String, dynamic>>> muestrasPorNumero = {};
    List<Map<String, dynamic>> procesosSinResultados = [];
    
    for (var process in processes) {
      if (process is Map<String, dynamic>) {
        // Detectar el tipo de estructura según el tipo de checklist
        Map<String, dynamic> resultados;
        if (widget.checklistType == 'labores_permanentes' || widget.checklistType == 'labores_temporales') {
          resultados = process['resultadosPorCuadranteParada'] ?? {};
        } else {
          resultados = process['resultadosPorCuadrante'] ?? {};
        }
        
        bool hasResults = resultados.isNotEmpty && 
            resultados.values.any((cuadrante) => cuadrante is Map && cuadrante.isNotEmpty);
        
        // Debug para entender qué está pasando
        print('🔍 Proceso ${process['id']}: ${process['proceso']}');
        print('🔍 Tipo de checklist: ${widget.checklistType}');
        print('🔍 Resultados encontrados: ${resultados.keys.length} cuadrantes');
        print('🔍 HasResults: $hasResults');
        if (resultados.isNotEmpty) {
          resultados.forEach((key, value) {
            print('🔍 Cuadrante $key: ${value is Map ? value.keys.length : 'no es Map'} items');
          });
        }
        
        if (hasResults) {
          // Procesar cada cuadrante y parada
          resultados.forEach((cuadranteId, paradas) {
            if (paradas is Map<String, dynamic>) {
              paradas.forEach((paradaNum, resultado) {
                String muestraKey = 'P$paradaNum';
                if (!muestrasPorNumero.containsKey(muestraKey)) {
                  muestrasPorNumero[muestraKey] = [];
                }
                muestrasPorNumero[muestraKey]!.add({
                  'proceso': process,
                  'cuadrante': cuadranteId,
                  'parada': paradaNum,
                  'resultado': resultado,
                });
              });
            }
          });
        } else {
          procesosSinResultados.add(process);
        }
      }
    }
    
    // Mostrar muestras evaluadas organizadas por número
    if (muestrasPorNumero.isNotEmpty) {
      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Muestras Evaluadas (${muestrasPorNumero.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              ...muestrasPorNumero.entries.map((entry) => _buildMuestraCard(entry.key, entry.value)),
            ],
          ),
        ),
      );
    }
    
    // Mostrar procesos sin resultados
    if (procesosSinResultados.isNotEmpty) {
      widgets.add(
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Procesos No Evaluados (${procesosSinResultados.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              ...procesosSinResultados.map((process) => _buildProcessCard(process, false)),
            ],
          ),
        ),
      );
    }
    
    return Column(children: widgets);
  }

  Widget _buildMuestraCard(String numeroMuestra, List<Map<String, dynamic>> evaluaciones) {
    // Agrupar por resultado para mostrar resumen
    Map<String, int> resumenResultados = {};
    for (var evaluacion in evaluaciones) {
      String resultado = evaluacion['resultado'] ?? '';
      resumenResultados[resultado] = (resumenResultados[resultado] ?? 0) + 1;
    }
    
    // Determinar color principal basado en el resultado más común
    String resultadoPrincipal = resumenResultados.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    Color colorPrincipal = _getResultColor(resultadoPrincipal);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorPrincipal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorPrincipal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la muestra
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorPrincipal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    numeroMuestra,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                      'Muestra $numeroMuestra',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorPrincipal,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${evaluaciones.length} evaluaciones',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Resumen de resultados
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorPrincipal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  resumenResultados.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(', '),
                  style: TextStyle(
                    color: colorPrincipal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          // Detalles de evaluaciones
          SizedBox(height: 8),
          ...evaluaciones.map((evaluacion) {
            Map<String, dynamic> proceso = evaluacion['proceso'];
            String cuadrante = evaluacion['cuadrante'];
            String resultado = evaluacion['resultado'];
            String nombreProceso = proceso['proceso'] ?? 'Sin proceso';
            int idProceso = proceso['id'] ?? 0;
            
            return Container(
              margin: EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  // ID del proceso
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$idProceso',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  
                  // Información del proceso
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreProceso,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Cuadrante $cuadrante',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Resultado
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getResultColor(resultado).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: _getResultColor(resultado)),
                    ),
                    child: Text(
                      resultado,
                      style: TextStyle(
                        color: _getResultColor(resultado),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProcessCard(Map<String, dynamic> process, bool hasResults) {
    String proceso = process['proceso'] ?? 'Sin proceso';
    int id = process['id'] ?? 0;
    String? observaciones = process['observaciones'];
    String? fotoBase64 = process['fotoBase64'];
    
    // Detectar el tipo de estructura según el tipo de checklist
    Map<String, dynamic> resultados;
    if (widget.checklistType == 'labores_permanentes' || widget.checklistType == 'labores_temporales') {
      resultados = process['resultadosPorCuadranteParada'] ?? {};
    } else {
      resultados = process['resultadosPorCuadrante'] ?? {};
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasResults ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasResults ? Colors.green[200]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del proceso
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hasResults ? Colors.green[600] : Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$id',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  proceso,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hasResults ? Colors.green[800] : Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ),
              if (hasResults)
                Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 16,
                )
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.grey[400],
                  size: 16,
                ),
            ],
          ),
          
          // Resultados por cuadrante si existen
          if (hasResults && resultados.isNotEmpty) ...[
            SizedBox(height: 8),
            ...resultados.entries.map((entry) {
              String cuadranteId = entry.key;
              Map<String, dynamic> paradas = entry.value;
              
              return Container(
                margin: EdgeInsets.only(bottom: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Text(
                      'Cuadrante $cuadranteId:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.green[700],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: paradas.entries.map((parada) {
                          String paradaNum = parada.key;
                          String resultado = parada.value;
                          
                          Color color = _getResultColor(resultado);
                          
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: color),
                            ),
                            child: Text(
                              'P$paradaNum: $resultado',
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          // Observaciones si existen
          if (observaciones != null && observaciones.isNotEmpty) ...[
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: Colors.blue[600], size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      observaciones,
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Indicador de foto si existe
          if (fotoBase64 != null && fotoBase64.isNotEmpty) ...[
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.photo, color: Colors.orange[600], size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Foto adjunta',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getResultColor(String resultado) {
    switch (resultado.toUpperCase()) {
      case 'C':
        return Colors.green;
      case 'NC':
        return Colors.red;
      case 'NA':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _buildObjectContent(Map<String, dynamic> data) {
    List<Widget> widgets = [];
    
    data.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    '${_formatKey(key)}:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatValue(value),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Column(children: widgets);
  }

  Widget _buildTextData(String title, String text) {
    String displayText = text;
    if (displayText.length > 300) {
      displayText = displayText.substring(0, 300) + '...';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDataCard(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[500], size: 16),
              SizedBox(width: 8),
              Text(
                'No hay datos disponibles',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildObservacionesField(dynamic observaciones) {
    String text = observaciones?.toString() ?? '';
    if (text.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Observaciones Generales',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.note, color: Colors.blue[600], size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatKey(String key) {
    // Convertir claves técnicas a texto más legible
    Map<String, String> keyMap = {
      'supervisor': 'Supervisor',
      'bloque': 'Bloque',
      'variedad': 'Variedad',
      'cuadrante': 'Cuadrante',
      'paradas': 'Paradas',
      'resultados': 'Resultados',
      'item_id': 'Item ID',
      'proceso': 'Proceso',
      'respuesta': 'Respuesta',
      'observaciones': 'Observaciones',
      'foto': 'Foto',
      'valor_numerico': 'Valor Numérico',
    };
    
    return keyMap[key.toLowerCase()] ?? key.replaceAll('_', ' ').toUpperCase();
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    
    String str = value.toString();
    
    // Truncar valores muy largos
    if (str.length > 100) {
      str = str.substring(0, 100) + '...';
    }
    
    return str;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    List<Widget> itemWidgets = [];

    // Verificar si es una tabla con datos JSON (nuevas tablas)
    bool isJsonTable = ['cortes', 'labores_permanentes', 'labores_temporales'].contains(widget.checklistType);
    
    if (isJsonTable) {
      // Para tablas con datos JSON, mostrar información de cuadrantes e items
      return _buildJsonDataSection();
    }

    // ⭐ CAMBIO CRÍTICO: Obtener los items que existen para este tipo de checklist
    List<int> itemsExistentes =
        AdminService.getExistingItemsForType('check_${widget.checklistType}');

    print('🔍 Construyendo items para ${widget.checklistType}');
    print('📋 Items existentes: $itemsExistentes');

    // Buscar solo los items que existen para este tipo
    for (int i in itemsExistentes) {
      if (_fullRecord!.containsKey('item_${i}_respuesta')) {
        String? respuesta = _fullRecord!['item_${i}_respuesta'];
        int? valorNumerico = _fullRecord!['item_${i}_valor_numerico'];
        String? observaciones = _fullRecord!['item_${i}_observaciones'];
        String? fotoBase64 = _fullRecord!['item_${i}_foto_base64'];

        if (respuesta != null ||
            valorNumerico != null ||
            (observaciones != null && observaciones.isNotEmpty) ||
            (fotoBase64 != null && fotoBase64.isNotEmpty)) {
          itemWidgets.add(_buildItemCard(
              i, respuesta, valorNumerico, observaciones, fotoBase64));
          print('✅ Item $i agregado al widget');
        }
      } else {
        print(
            '⚠️ Item $i no encontrado en datos (esto es normal si no tiene datos)');
      }
    }

    if (itemWidgets.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                SizedBox(height: 12),
                Text(
                  'No se encontraron items completados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Items disponibles para ${widget.checklistType}: ${itemsExistentes.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getChecklistColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.checklist,
                    color: _getChecklistColor(),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Items del Checklist',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'Tipo: ${widget.checklistType} • Total disponible: ${itemsExistentes.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getChecklistColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${itemWidgets.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getChecklistColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        ...itemWidgets,
      ],
    );
  }

  // ==================== SECCIÓN DETALLE: OBSERVACIONES ADICIONALES ====================

  Widget _buildObservacionesAdicionalesSection() {
    // Observación
    List<Widget> children = [];

    children.add(
      Card(
        elevation: 8,
        shadowColor: _getChecklistColor().withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getChecklistColor().withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getChecklistColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.description, color: _getChecklistColor(), size: 20),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Observación',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    (_fullRecord!['observacion'] ?? '').toString(),
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Imágenes
    List<String> images = [];
    try {
      if (_fullRecord!['imagenes_json'] != null) {
        final parsed = json.decode(_fullRecord!['imagenes_json']);
        if (parsed is List) {
          images = parsed.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    if (images.isNotEmpty) {
      children.add(SizedBox(height: 16));
      children.add(
        Card(
          elevation: 8,
          shadowColor: _getChecklistColor().withOpacity(0.3),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getChecklistColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.image, color: _getChecklistColor(), size: 20),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Imágenes (${images.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
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
                          errorBuilder: (context, error, stack) => Container(
                            color: Colors.grey[200],
                            child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: children);
  }

  Widget _buildItemCard(int itemNumber, String? respuesta, int? valorNumerico,
      String? observaciones, String? fotoBase64) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getRespuestaColor(respuesta).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getChecklistColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Item $itemNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getChecklistColor(),
                      ),
                    ),
                  ),
                  Spacer(),
                  if (respuesta != null)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRespuestaColor(respuesta).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRespuestaIcon(respuesta),
                            size: 12,
                            color: _getRespuestaColor(respuesta),
                          ),
                          SizedBox(width: 4),
                          Text(
                            respuesta.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getRespuestaColor(respuesta),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (valorNumerico != null ||
                  (observaciones != null && observaciones.isNotEmpty) ||
                  (fotoBase64 != null && fotoBase64.isNotEmpty)) ...[
                SizedBox(height: 12),
                if (valorNumerico != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.straighten,
                            size: 16, color: Colors.blue[600]),
                        SizedBox(width: 6),
                        Text(
                          'Valor: $valorNumerico',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (valorNumerico != null &&
                    observaciones != null &&
                    observaciones.isNotEmpty)
                  SizedBox(height: 8),
                if (observaciones != null && observaciones.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note,
                                size: 16, color: Colors.orange[600]),
                            SizedBox(width: 6),
                            Text(
                              'Observaciones:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          observaciones,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (fotoBase64 != null && fotoBase64.isNotEmpty) ...[
                  if ((valorNumerico != null) ||
                      (observaciones != null && observaciones.isNotEmpty))
                    SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showImageDialog(fotoBase64),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.photo_camera,
                              size: 16, color: Colors.green[600]),
                          SizedBox(width: 6),
                          Text(
                            'Foto adjunta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green[700],
                            ),
                          ),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Ver',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.visibility,
                              size: 14, color: Colors.green[600]),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getRespuestaColor(String? respuesta) {
    if (respuesta == null) return Colors.grey;
    switch (respuesta.toLowerCase()) {
      case 'si':
        return Colors.green;
      case 'no':
        return Colors.red;
      case 'na':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRespuestaIcon(String? respuesta) {
    if (respuesta == null) return Icons.help_outline;
    switch (respuesta.toLowerCase()) {
      case 'si':
        return Icons.check_circle;
      case 'no':
        return Icons.cancel;
      case 'na':
        return Icons.remove_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _getCumplimientoColor(dynamic porcentaje) {
    if (porcentaje == null) return Colors.grey;
    double value = porcentaje.toDouble();
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getCumplimientoIcon(dynamic porcentaje) {
    if (porcentaje == null) return Icons.help_outline;
    double value = porcentaje.toDouble();
    if (value >= 80) return Icons.check_circle;
    if (value >= 60) return Icons.warning;
    return Icons.error;
  }

  String _formatDetailDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy - HH:mm:ss').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getChecklistColor() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Colors.blue[700]!;
      case 'bodega':
        return Colors.orange[700]!;
      case 'aplicaciones':
        return Colors.green[700]!;
      case 'cosecha':
        return Colors.purple[700]!;
      case 'cortes':
        return Colors.red[700]!;
      case 'labores_permanentes':
        return Colors.deepPurple[700]!;
      case 'labores_temporales':
        return Colors.amber[700]!;
      default:
        return Colors.red[700]!;
    }
  }

  // Método para mostrar imagen en diálogo
  void _showImageDialog(String base64Image) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(10),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: MediaQuery.of(context).size.width * 0.95,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header del diálogo
                        Container(
                          padding: EdgeInsets.all(16),
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
                                child: Icon(Icons.photo,
                                    color: Colors.white, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Imagen del Item',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Toca fuera para cerrar',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Imagen con visor interactivo
                        Flexible(
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            child: InteractiveViewer(
                              panEnabled: true,
                              boundaryMargin: EdgeInsets.all(20),
                              minScale: 0.3,
                              maxScale: 5.0,
                              clipBehavior: Clip.none,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 15,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    base64Decode(base64Image),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 300,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.grey[300]!),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.error_outline,
                                                size: 48,
                                                color: Colors.red[400],
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Error al cargar imagen',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'La imagen podría estar corrupta o en un formato no compatible',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    frameBuilder: (context, child, frame,
                                        wasSynchronouslyLoaded) {
                                      if (wasSynchronouslyLoaded ||
                                          frame != null) {
                                        return child;
                                      }
                                      return Container(
                                        height: 300,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                color: _getChecklistColor(),
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Cargando imagen...',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Footer con instrucciones y acciones
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border:
                                          Border.all(color: Colors.blue[200]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.zoom_in,
                                            size: 16, color: Colors.blue[600]),
                                        SizedBox(width: 6),
                                        Text(
                                          'Pellizca para zoom',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border:
                                          Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.pan_tool,
                                            size: 16, color: Colors.green[600]),
                                        SizedBox(width: 6),
                                        Text(
                                          'Arrastra para mover',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        // TODO: Implementar descarga de imagen
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Función de descarga próximamente'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      },
                                      icon: Icon(Icons.download, size: 16),
                                      label: Text('Descargar'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: Icon(Icons.close, size: 16),
                                      label: Text('Cerrar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _getChecklistColor(),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareDialogOffline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ShareDialogOffline(
          recordData: _fullRecord!,
          checklistType: widget.checklistType,
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
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
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showShareDialog() async {
  if (_fullRecord == null) {
    _showErrorSnackBar('No se pueden compartir los datos. Intenta recargar el registro.');
    return;
  }

  // Verificar que los datos del registro sean válidos para el tipo de checklist
  List<int> itemsExistentes = AdminService.getExistingItemsForType('check_${widget.checklistType}');
  print('🔍 Validando datos para PDF - Items esperados: $itemsExistentes');
  
  // Verificar conectividad para envío por correo
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error verificando conectividad: $e');
      return false;
    }
  }

  bool hasConnection = await _checkConnectivity();
  
  if (!hasConnection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sin Conexión'),
          ],
        ),
        content: Text(
          'No hay conexión a internet. Solo estará disponible la opción de descarga local. '
          'Para enviar por correo, conecta a internet e inténtalo nuevamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showShareDialogOffline();
            },
            child: Text('Solo Descarga'),
          ),
        ],
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return ShareDialog(
        recordData: _fullRecord!,
        checklistType: widget.checklistType,
      );
    },
  );
}
}

class ShareDialogOffline extends StatefulWidget {
  final Map<String, dynamic> recordData;
  final String checklistType;

  ShareDialogOffline({
    required this.recordData,
    required this.checklistType,
  });

  @override
  _ShareDialogOfflineState createState() => _ShareDialogOfflineState();
}

class _ShareDialogOfflineState extends State<ShareDialogOffline> {
  bool _isGeneratingPDF = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 64,
                    color: Colors.orange[300],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Modo Sin Conexión',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Solo está disponible la descarga local del reporte.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPDF ? null : _downloadPDF,
                      icon: _isGeneratingPDF
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.download),
                      label: Text(
                          _isGeneratingPDF ? 'Generando...' : 'Descargar PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange[700],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.download, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Descarga Local',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPDF() async {
    if (mounted) {
      setState(() {
        _isGeneratingPDF = true;
      });
    }

    try {
      // Generar PDF usando el PDFService con datos frescos del servidor
      final pdfBytes = await PDFService.generarReporteChecklist(
        recordData: widget.recordData,
        checklistType: widget.checklistType,
        obtenerDatosFrescos: true, // Obtener datos frescos para asegurar el nombre correcto
      );

      // Guardar archivo - implementación similar a ShareDialog
      final result = await _saveFile(pdfBytes);

      if (result['success']) {
        _showSuccessMessage(
            'PDF descargado exitosamente en: ${result['path']}');
        Navigator.pop(context);
      } else {
        _showErrorMessage('Error al guardar PDF: ${result['error']}');
      }
    } catch (e) {
      _showErrorMessage('Error al generar PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _saveFile(Uint8List pdfBytes) async {
    // Implementación igual que en ShareDialog
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        directory = Directory('${directory!.path}/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String fileName = _generateFileName();
      final File file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pdfBytes);

      return {
        'success': true,
        'path': file.path,
        'fileName': fileName,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  String _generateFileName() {
    final String fecha =
        DateTime.now().toString().substring(0, 10).replaceAll('-', '');
    final String tipo = widget.checklistType.toUpperCase();
    final int id = widget.recordData['id'];

    return 'Checklist_${tipo}_ID${id}_$fecha.pdf';
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ==================== EXTENSIONES Y UTILIDADES ====================

extension AdminScreenUtils on _ChecklistRecordsScreenState {
  String getTypeDisplayName() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return 'Fertirriego';
      case 'bodega':
        return 'Bodega';
      case 'aplicaciones':
        return 'Aplicaciones';
      case 'cosecha':
        return 'Cosechas';
      default:
        return widget.checklistType.toUpperCase();
    }
  }

  List<String> getTypeSpecificFields() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return ['Finca', 'Bloque'];
      case 'bodega':
        return ['Finca', 'Supervisor', 'Pesador'];
      case 'aplicaciones':
        return ['Finca', 'Bloque', 'Bomba'];
      case 'cosecha':
        return ['Finca', 'Bloque', 'Variedad'];
      default:
        return ['Finca'];
    }
  }

  Color getTypeColor() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Colors.blue[700]!;
      case 'bodega':
        return Colors.orange[700]!;
      case 'aplicaciones':
        return Colors.green[700]!;
      case 'cosecha':
        return Colors.purple[700]!;
      default:
        return Colors.red[700]!;
    }
  }

  IconData getTypeIcon() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Icons.water_drop;
      case 'bodega':
        return Icons.warehouse;
      case 'aplicaciones':
        return Icons.sanitizer;
      case 'cosecha':
        return Icons.agriculture;
      default:
        return Icons.assignment;
    }
  }
}

// ==================== CONSTANTES Y CONFIGURACIÓN ====================

class AdminScreenConstants {
  // Colores por tipo de checklist
  static const Map<String, Color> checklistColors = {
    'fertirriego': Colors.blue,
    'bodega': Colors.orange,
    'aplicaciones': Colors.green,
    'cosecha': Colors.purple,
    'cortes': Colors.red,
    'labores_permanentes': Colors.deepPurple,
    'labores_temporales': Colors.amber,
  };

  // Iconos por tipo de checklist
  static const Map<String, IconData> checklistIcons = {
    'fertirriego': Icons.water_drop,
    'bodega': Icons.warehouse,
    'aplicaciones': Icons.sanitizer,
    'cosecha': Icons.agriculture,
    'cortes': Icons.content_cut,
    'labores_permanentes': Icons.agriculture,
    'labores_temporales': Icons.construction,
  };

  // Campos específicos por tipo
  static const Map<String, List<String>> checklistFields = {
    'fertirriego': ['finca_nombre', 'bloque_nombre'],
    'bodega': ['finca_nombre', 'supervisor_nombre', 'pesador_nombre'],
    'aplicaciones': ['finca_nombre', 'bloque_nombre', 'bomba_nombre'],
    'cosechas': ['finca_nombre', 'bloque_nombre', 'variedad_nombre'],
    'cortes': ['finca_nombre', 'bloque_nombre', 'variedad_nombre'],
    'labores_permanentes': ['finca_nombre', 'bloque_nombre', 'variedad_nombre'],
    'labores_temporales': ['finca_nombre', 'bloque_nombre', 'variedad_nombre'],
  };

  // Títulos legibles
  static const Map<String, String> checklistTitles = {
    'fertirriego': 'Fertirriego',
    'bodega': 'Bodega',
    'aplicaciones': 'Aplicaciones',
    'cosechas': 'Cosechas',
    'cortes': 'Cortes del Día',
    'labores_permanentes': 'Labores Permanentes',
    'labores_temporales': 'Labores Temporales',
  };

  // Subtítulos con campos
  static const Map<String, String> checklistSubtitles = {
    'fertirriego': 'Finca • Bloque',
    'bodega': 'Finca • Supervisor • Pesador',
    'aplicaciones': 'Finca • Bloque • Bomba',
    'cosechas': 'Finca • Bloque • Variedad',
    'cortes': 'Finca • Bloque • Variedad',
    'labores_permanentes': 'Finca • Bloque • Variedad',
    'labores_temporales': 'Finca • Bloque • Variedad',
  };

  // Configuración de zoom para imágenes
  static const double minImageScale = 0.3;
  static const double maxImageScale = 5.0;
  static const double defaultImageScale = 1.0;

  // Configuración de filtros
  static const int defaultDateRangeDays = 30;
  static const int maxRecordsPerPage = 50;

  // Configuración de UI
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 12.0;
  static const double dialogBorderRadius = 20.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}
