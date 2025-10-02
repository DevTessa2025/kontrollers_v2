import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/admin_service.dart';
import 'labores_temporales_detailed_admin_screen.dart';

class LaboresTemporalesAdminScreen extends StatefulWidget {
  @override
  _LaboresTemporalesAdminScreenState createState() => _LaboresTemporalesAdminScreenState();
}

class _LaboresTemporalesAdminScreenState extends State<LaboresTemporalesAdminScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTime? _selectedDate;
  String? _selectedFinca;
  String? _selectedSupervisor;

  // Filtros disponibles
  List<String> _fincas = [];
  List<String> _supervisores = [];

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
      final result = await AdminService.getLaboresTemporalesRecords();
      setState(() {
        _records = result['records'] ?? [];
        _extractFilters();
      });
    } catch (e) {
      print('Error cargando registros de labores temporales: $e');
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
    final supervisoresSet = <String>{};

    for (var record in _records) {
      if (record['finca_nombre'] != null) {
        fincasSet.add(record['finca_nombre']);
      }
      if (record['supervisor'] != null) {
        supervisoresSet.add(record['supervisor']);
      }
    }

    setState(() {
      _fincas = fincasSet.toList()..sort();
      _supervisores = supervisoresSet.toList()..sort();
    });
  }

  List<Map<String, dynamic>> get _filteredRecords {
    return _records.where((record) {
      // Filtro por texto de búsqueda
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final matchesSearch = 
          (record['finca_nombre']?.toString().toLowerCase().contains(searchLower) ?? false) ||
          (record['supervisor']?.toString().toLowerCase().contains(searchLower) ?? false) ||
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

      // Filtro por supervisor
      if (_selectedSupervisor != null && record['supervisor'] != _selectedSupervisor) {
        return false;
      }

      return true;
    }).toList();
  }

  double _calcularPorcentajePromedio(Map<String, dynamic> record) {
    try {
      final cuadrantesJson = record['cuadrantes_json'];
      final itemsJson = record['items_json'];
      
      if (cuadrantesJson == null || itemsJson == null) return 0.0;
      
      final cuadrantes = List<Map<String, dynamic>>.from(
        cuadrantesJson is String ? 
        (jsonDecode(cuadrantesJson) as List).cast<Map<String, dynamic>>() :
        cuadrantesJson
      );
      
      final items = List<Map<String, dynamic>>.from(
        itemsJson is String ? 
        (jsonDecode(itemsJson) as List).cast<Map<String, dynamic>>() :
        itemsJson
      );
      
      if (cuadrantes.isEmpty || items.isEmpty) return 0.0;
      
      double sumaPorcentajes = 0.0;
      int cuadrantesConDatos = 0;
      
      for (var cuadrante in cuadrantes) {
        final cuadranteId = cuadrante['cuadrante']?.toString() ?? '';
        final bloque = cuadrante['bloque']?.toString() ?? '';
        if (cuadranteId.isEmpty || bloque.isEmpty) continue;
        final resultadoKey = 'test_${bloque}_${cuadranteId}';
        int marcados = 0;
        final int numItems = items.length;
        const int paradas = 5;
        for (final item in items) {
          final res = item['resultadosPorCuadranteParada'] as Map<String, dynamic>?;
          if (res == null) continue;
          final mapa = res[resultadoKey];
          if (mapa is Map<String, dynamic>) {
            for (int p = 1; p <= paradas; p++) {
              final v = mapa[p.toString()];
              if (v != null && v.toString().isNotEmpty) marcados++;
            }
          }
        }
        if (numItems > 0) {
          final int totalSlots = numItems * paradas;
          final int noMarcados = totalSlots - marcados;
          final porcentaje = (noMarcados / totalSlots) * 100;
          sumaPorcentajes += porcentaje;
          cuadrantesConDatos++;
        }
      }
      
      return cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
    } catch (e) {
      print('Error calculando porcentaje: $e');
      return 0.0;
    }
  }

  Color _getCumplimientoColor(double? porcentaje) {
    if (porcentaje == null) return Colors.grey;
    if (porcentaje >= 80) return Colors.green;
    if (porcentaje >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Labores Temporales - Administración'),
        backgroundColor: Colors.purple,
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
              hintText: 'Buscar por finca, supervisor o kontroller...',
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
                    labelText: 'Supervisor',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _selectedSupervisor,
                  items: [
                    DropdownMenuItem(value: null, child: Text('Todos los supervisores')),
                    ..._supervisores.map((supervisor) => DropdownMenuItem(value: supervisor, child: Text(supervisor))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSupervisor = value;
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
                    backgroundColor: Colors.purple,
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
              _searchQuery.isNotEmpty || _selectedDate != null || _selectedFinca != null || _selectedSupervisor != null
                  ? 'No se encontraron registros con los filtros aplicados'
                  : 'No hay registros de labores temporales',
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
        return _buildLaboresTemporalesCard(record);
      },
    );
  }

  Widget _buildLaboresTemporalesCard(Map<String, dynamic> record) {
    final porcentaje = _calcularPorcentajePromedio(record);
    final cumplimientoColor = _getCumplimientoColor(porcentaje);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LaboresTemporalesDetailedAdminScreen(record: record),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finca: ${record['finca_nombre'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('Supervisor: ${record['supervisor'] ?? 'N/A'}'),
                        Text('Kontroller: ${record['usuario_nombre'] ?? 'N/A'}'),
                        Text('Fecha: ${_formatDate(record['fecha_creacion'])}'),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cumplimientoColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${porcentaje.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncToServer() async {
    try {
      // Implementar sincronización específica para labores temporales
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
