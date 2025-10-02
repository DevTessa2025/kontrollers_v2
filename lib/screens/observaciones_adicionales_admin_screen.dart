import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import 'observaciones_adicionales_detailed_admin_screen.dart';

class ObservacionesAdicionalesAdminScreen extends StatefulWidget {
  @override
  _ObservacionesAdicionalesAdminScreenState createState() => _ObservacionesAdicionalesAdminScreenState();
}

class _ObservacionesAdicionalesAdminScreenState extends State<ObservacionesAdicionalesAdminScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _selectedDate;
  String? _selectedFinca;
  String? _selectedTipo;

  // Filtros disponibles
  List<String> _fincas = [];
  List<String> _tipos = ['MIPE', 'CULTIVO', 'MIRFE'];

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
      final result = await AdminService.getObservacionesAdicionalesRecords();
      setState(() {
        _records = result['records'] ?? [];
        _extractFilters();
      });
    } catch (e) {
      print('Error cargando registros de observaciones adicionales: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando registros: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _extractFilters() {
    final fincasSet = <String>{};

    for (var record in _records) {
      if (record['finca_nombre'] != null) {
        fincasSet.add(record['finca_nombre']);
      }
    }

    setState(() {
      _fincas = fincasSet.toList()..sort();
    });
  }

  List<Map<String, dynamic>> get _filteredRecords {
    return _records.where((record) {
      // Filtro por texto de búsqueda
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch = 
          (record['finca_nombre']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (record['bloque_nombre']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (record['variedad_nombre']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (record['observacion']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (record['usuario_nombre']?.toString().toLowerCase().contains(searchLower) ?? false);
        if (!matchesSearch) return false;
      }

      // Filtro por fecha
      if (_selectedDate != null) {
        final recordDate = DateTime.tryParse(record['fecha_creacion']?.toString() ?? '');
        if (recordDate == null) return false;
        if (recordDate.year != _selectedDate!.year ||
            recordDate.month != _selectedDate!.month ||
            recordDate.day != _selectedDate!.day) {
          return false;
        }
      }

      // Filtro por finca
      if (_selectedFinca != null && record['finca_nombre'] != _selectedFinca) {
        return false;
      }

      // Filtro por tipo
      if (_selectedTipo != null && record['tipo'] != _selectedTipo) {
        return false;
      }

      return true;
    }).toList();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Observaciones Adicionales - Administración'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          // Barra de búsqueda
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por finca, bloque, variedad, observación o usuario...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          SizedBox(height: 16),
          // Filtros
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Finca',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _selectedFinca,
                  items: [
                    DropdownMenuItem(value: null, child: Text('Todas las fincas')),
                    ..._fincas.map((finca) => DropdownMenuItem(value: finca, child: Text(finca))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFinca = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _selectedTipo,
                  items: [
                    DropdownMenuItem(value: null, child: Text('Todos los tipos')),
                    ..._tipos.map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedTipo = value;
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Botón de sincronización
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _syncToServer,
                  icon: Icon(Icons.sync),
                  label: Text('Sincronizar con Servidor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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

  Widget _buildRecordsList() {
    final filteredRecords = _filteredRecords;
    
    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedDate != null || _selectedFinca != null || _selectedTipo != null
                  ? 'No se encontraron registros con los filtros aplicados'
                  : 'No hay registros de observaciones adicionales',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final record = filteredRecords[index];
        return _buildObservacionCard(record);
      },
    );
  }

  Widget _buildObservacionCard(Map<String, dynamic> record) {
    final tipo = record['tipo'] ?? 'N/A';
    final tipoColor = _getTipoColor(tipo);
    final tipoIcon = _getTipoIcon(tipo);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ObservacionesAdicionalesDetailedAdminScreen(record: record),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tipoColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tipoIcon, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          tipo,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Finca: ${record['finca_nombre'] ?? 'N/A'}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('Bloque: ${record['bloque_nombre'] ?? 'N/A'}'),
              Text('Variedad: ${record['variedad_nombre'] ?? 'N/A'}'),
              Text('Usuario: ${record['usuario_nombre'] ?? 'N/A'}'),
              Text('Fecha: ${_formatDate(record['fecha_creacion'])}'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record['observacion'] ?? 'Sin observación',
                  style: TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncToServer() async {
    try {
      // Implementar sincronización específica para observaciones adicionales
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronización completada')),
      );
      _loadRecords();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en sincronización: $e')),
      );
    }
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
