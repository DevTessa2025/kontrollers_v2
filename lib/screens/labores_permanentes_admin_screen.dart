import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import 'labores_permanentes_detailed_admin_screen.dart';

class LaboresPermanentesAdminScreen extends StatefulWidget {
  const LaboresPermanentesAdminScreen({Key? key}) : super(key: key);

  @override
  State<LaboresPermanentesAdminScreen> createState() => _LaboresPermanentesAdminScreenState();
}

class _LaboresPermanentesAdminScreenState extends State<LaboresPermanentesAdminScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  DateTime? _selectedDate;
  String? _selectedFinca;
  String? _selectedSupervisor;

  // Filtros
  List<String> _fincas = [];
  List<String> _supervisores = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  double _calcularPorcentajePromedio(Map<String, dynamic> record) {
    try {
      // Parsear cuadrantes_json
      final cuadrantesData = record['cuadrantes_json'];
      if (cuadrantesData == null) return 0.0;
      
      List<Map<String, dynamic>> cuadrantes = [];
      if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
        cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
      } else if (cuadrantesData is List) {
        cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
      }
      
      if (cuadrantes.isEmpty) return 0.0;
      
      // Parsear items_json
      final itemsData = record['items_json'];
      if (itemsData == null) return 0.0;
      
      List<Map<String, dynamic>> items = [];
      if (itemsData is String && itemsData.isNotEmpty) {
        items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
      } else if (itemsData is List) {
        items = List<Map<String, dynamic>>.from(itemsData);
      }
      
      // 100% si nada está marcado; baja al marcar (promedio por cuadrante)
      double sumaPorcentajes = 0.0;
      int cuadrantesConDatos = 0;
      
      for (var cuadrante in cuadrantes) {
        final cuadranteId = cuadrante['cuadrante']?.toString() ?? cuadrante['id']?.toString() ?? '';
        if (cuadranteId.isEmpty) continue;
        
        // Calcular marcados para este cuadrante sumando todos los items y sus paradas
        final String bloque = cuadrante['bloque']?.toString() ?? '';
        final String resultadoKey = 'test_${bloque}_${cuadranteId}';

        int marcados = 0;
        final int numItems = items.length;
        const int paradas = 5;

        for (final item in items) {
          final resParada = (item['resultadosPorCuadranteParada'] ?? item['resultadosPorCuadrante']) as Map<String, dynamic>?;
          if (resParada == null) continue;
          final mapaCuadrante = resParada.containsKey(resultadoKey)
              ? resParada[resultadoKey]
              : (resParada[cuadranteId]);
          if (mapaCuadrante is Map<String, dynamic>) {
            for (int p = 1; p <= paradas; p++) {
              final v = mapaCuadrante[p.toString()] ?? mapaCuadrante[p];
              if (v != null && v.toString().trim().isNotEmpty) {
                marcados++;
              }
            }
          }
        }

        if (numItems > 0) {
          final int totalSlots = numItems * paradas;
          final int noMarcados = totalSlots - marcados;
          final double porcentaje = (noMarcados / totalSlots) * 100;
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

  Color _getCumplimientoColor(double porcentaje) {
    if (porcentaje >= 80) return Colors.green;
    if (porcentaje >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getCumplimientoText(double porcentaje) {
    if (porcentaje >= 80) return 'Alto';
    if (porcentaje >= 60) return 'Medio';
    return 'Bajo';
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdminService.getLaboresPermanentesRecords(
        fechaInicio: _selectedDate,
        fechaFin: _selectedDate,
        fincaNombre: _selectedFinca,
      );

      setState(() {
        _records = List<Map<String, dynamic>>.from(result['records'] ?? []);
        _fincas = List<String>.from(result['fincas'] ?? []);
        _supervisores = List<String>.from(result['supervisores'] ?? []);
      });
    } catch (e) {
      print('Error cargando registros de labores permanentes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando registros: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncToServer() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Aquí implementarías la lógica de sincronización
      await Future.delayed(Duration(seconds: 2)); // Simulación
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronización completada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en sincronización: $e')),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    
    return _records.where((record) {
      final finca = record['finca_nombre']?.toString().toLowerCase() ?? '';
      final supervisor = record['supervisor']?.toString().toLowerCase() ?? '';
      final fecha = record['fecha_creacion']?.toString().toLowerCase() ?? '';
      
      return finca.contains(_searchQuery.toLowerCase()) ||
             supervisor.contains(_searchQuery.toLowerCase()) ||
             fecha.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por finca, supervisor o fecha...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncToServer,
                icon: _isSyncing 
                  ? SizedBox(
                      width: 16, 
                      height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : Icon(Icons.sync),
                label: Text('Sincronizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Finca',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedFinca,
                  items: [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    ..._fincas.map((finca) => DropdownMenuItem(
                      value: finca,
                      child: Text(finca),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFinca = value;
                    });
                    _loadRecords();
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Supervisor',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedSupervisor,
                  items: [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    ..._supervisores.map((supervisor) => DropdownMenuItem(
                      value: supervisor,
                      child: Text(supervisor),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSupervisor = value;
                    });
                    _loadRecords();
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                      _loadRecords();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16),
                        SizedBox(width: 8),
                        Text(
                          _selectedDate != null 
                            ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                            : 'Fecha',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLaboresPermanentesCard(Map<String, dynamic> record) {
    final porcentaje = _calcularPorcentajePromedio(record);
    final cumplimientoColor = _getCumplimientoColor(porcentaje);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LaboresPermanentesDetailedAdminScreen(record: record),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Supervisor: ${record['supervisor'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                        Text(
                          'Kontroller: ${record['usuario_nombre'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                        Text(
                          'Fecha: ${_formatDate(record['fecha_creacion'])}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
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
                      SizedBox(height: 4),
                      Text(
                        _getCumplimientoText(porcentaje),
                        style: TextStyle(
                          fontSize: 12,
                          color: cumplimientoColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Labores Permanentes - Administración'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No hay registros de labores permanentes',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = _filteredRecords[index];
                          return _buildLaboresPermanentesCard(record);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
