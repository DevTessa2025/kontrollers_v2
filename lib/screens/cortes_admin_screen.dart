import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import 'cortes_detailed_admin_screen.dart';

class CortesAdminScreen extends StatefulWidget {
  const CortesAdminScreen({Key? key}) : super(key: key);

  @override
  State<CortesAdminScreen> createState() => _CortesAdminScreenState();
}

class _CortesAdminScreenState extends State<CortesAdminScreen> {
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
      print('=== DEBUG: Calculando porcentaje promedio ===');
      print('Record keys: ${record.keys.toList()}');
      
      // Parsear cuadrantes e items
      List<Map<String, dynamic>> cuadrantes = [];
      List<Map<String, dynamic>> items = [];
      
      print('cuadrantes_json: ${record['cuadrantes_json']}');
      print('items_json: ${record['items_json']}');
      
      if (record['cuadrantes_json'] != null) {
        final cuadrantesData = record['cuadrantes_json'];
        print('cuadrantesData type: ${cuadrantesData.runtimeType}');
        if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
          cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
        } else if (cuadrantesData is List) {
          cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
        }
      }
      
      if (record['items_json'] != null) {
        final itemsData = record['items_json'];
        print('itemsData type: ${itemsData.runtimeType}');
        if (itemsData is String && itemsData.isNotEmpty) {
          items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
        } else if (itemsData is List) {
          items = List<Map<String, dynamic>>.from(itemsData);
        }
      }
      
      print('Cuadrantes parseados: ${cuadrantes.length}');
      print('Items parseados: ${items.length}');
      
      if (cuadrantes.isEmpty) {
        print('No hay cuadrantes - retornando 0');
        return 0.0;
      }
      
      // Encontrar el item "Corte conforme"
      Map<String, dynamic>? itemCorteConforme;
      print('Buscando item "Corte conforme" en ${items.length} items...');
      for (var item in items) {
        final itemProceso = item['proceso']?.toString() ?? '';
        print('Item: $itemProceso');
        if (itemProceso.toLowerCase().contains('corte conforme')) {
          itemCorteConforme = item;
          print('Item "Corte conforme" encontrado: $itemProceso');
          print('Item completo: $item');
          break;
        }
      }
      
      if (itemCorteConforme == null) {
        print('No se encontró el item "Corte conforme"');
        return 0.0;
      }
      
      double sumaPorcentajes = 0.0;
      int cuadrantesConDatos = 0;
      
      // Calcular porcentaje para cada cuadrante
      print('Procesando ${cuadrantes.length} cuadrantes...');
      for (var cuadrante in cuadrantes) {
        final cuadranteId = cuadrante['cuadrante']?.toString() ?? cuadrante['id']?.toString() ?? '';
        print('Procesando cuadrante: $cuadranteId');
        
        int totalMuestras = 0;
        int muestrasConCorteConforme = 0;
        
        // Procesar resultados del item "Corte conforme" para este cuadrante
        print('resultadosPorCuadrante: ${itemCorteConforme['resultadosPorCuadrante']}');
        if (itemCorteConforme['resultadosPorCuadrante'] != null) {
          final resultadosPorCuadrante = itemCorteConforme['resultadosPorCuadrante'];
          if (resultadosPorCuadrante is Map<String, dynamic>) {
            print('Resultados por cuadrante keys: ${resultadosPorCuadrante.keys.toList()}');
            final muestras = resultadosPorCuadrante[cuadranteId];
            print('Muestras para cuadrante $cuadranteId: $muestras');
            if (muestras is Map<String, dynamic>) {
              muestras.forEach((muestra, resultado) {
                print('Muestra $muestra: $resultado');
                if (resultado != null && resultado.toString().isNotEmpty) {
                  totalMuestras++;
                  if (resultado.toString().toLowerCase() == 'c' || resultado.toString() == '1') {
                    muestrasConCorteConforme++;
                  }
                }
              });
            }
          }
        }
        
        print('Cuadrante $cuadranteId - Total muestras: $totalMuestras, Conformes: $muestrasConCorteConforme');
        if (totalMuestras > 0) {
          final porcentajeCuadrante = (muestrasConCorteConforme / 10 * 100);
          sumaPorcentajes += porcentajeCuadrante;
          cuadrantesConDatos++;
          print('Cuadrante $cuadranteId: $muestrasConCorteConforme/10 = ${porcentajeCuadrante.toStringAsFixed(1)}%');
        } else {
          print('Cuadrante $cuadranteId: Sin datos');
        }
      }
      
      final promedio = cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
      print('Promedio de cuadrantes: ${promedio.toStringAsFixed(1)}%');
      
      return promedio;
    } catch (e) {
      print('Error calculando porcentaje promedio: $e');
      return 0.0;
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdminService.getCortesRecords(
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
      print('Error cargando registros de cortes: $e');
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
      final fecha = record['fecha']?.toString().toLowerCase() ?? '';
      
      return finca.contains(_searchQuery.toLowerCase()) ||
             supervisor.contains(_searchQuery.toLowerCase()) ||
             fecha.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
              IconButton(
                onPressed: () async {
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
                icon: Icon(Icons.calendar_today),
                tooltip: 'Seleccionar fecha',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCortesCard(Map<String, dynamic> record) {
    // Parsear datos JSON
    List<dynamic> cuadrantes = [];
    List<dynamic> items = [];
    
    try {
      cuadrantes = List<dynamic>.from(record['cuadrantes_json'] is String 
        ? (record['cuadrantes_json'] as String).isNotEmpty 
          ? [] // Parsear JSON si es necesario
          : []
        : record['cuadrantes_json'] ?? []);
      
      items = List<dynamic>.from(record['items_json'] is String 
        ? (record['items_json'] as String).isNotEmpty 
          ? [] // Parsear JSON si es necesario
          : []
        : record['items_json'] ?? []);
    } catch (e) {
      print('Error parseando JSON: $e');
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showCortesDetails(record),
        borderRadius: BorderRadius.circular(8),
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
                          record['finca_nombre'] ?? 'Sin finca',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Kontroller: ${record['usuario_nombre'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Fecha: ${_formatDate(record['fecha'])}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCumplimientoColor(_calcularPorcentajePromedio(record)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_calcularPorcentajePromedio(record).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (cuadrantes.isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  'Cuadrantes:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: cuadrantes.take(5).map<Widget>((cuadrante) {
                    final cuadranteData = cuadrante is Map<String, dynamic> ? cuadrante : {};
                    return Chip(
                      label: Text(
                        '${cuadranteData['cuadrante'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue[100],
                    );
                  }).toList(),
                ),
                if (cuadrantes.length > 5)
                  Text(
                    '... y ${cuadrantes.length - 5} más',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
              if (items.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  'Items evaluados: ${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCumplimientoColor(double? porcentaje) {
    if (porcentaje == null) return Colors.grey;
    if (porcentaje >= 80) return Colors.green;
    if (porcentaje >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime? dt;
      if (date is DateTime) {
        dt = date;
      } else if (date is num) {
        // milliseconds since epoch
        dt = DateTime.fromMillisecondsSinceEpoch(date.toInt());
      } else if (date is String) {
        final raw = date.trim();
        // Intento directo
        dt = DateTime.tryParse(raw);
        // Reintentos con patrones comunes de SQL
        if (dt == null) {
          final candidates = [
            'yyyy-MM-dd HH:mm:ss.SSS',
            'yyyy-MM-dd HH:mm:ss',
            'yyyy-MM-ddTHH:mm:ss.SSS',
            'yyyy-MM-ddTHH:mm:ss',
          ];
          for (final p in candidates) {
            try {
              dt = DateFormat(p).parseStrict(raw);
              break;
            } catch (_) {}
          }
        }
      }
      if (dt == null) return date.toString();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      return date.toString();
    }
  }

  void _showCortesDetails(Map<String, dynamic> record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CortesDetailedAdminScreen(record: record),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Administración - Cortes del Día'),
        backgroundColor: Colors.blue,
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
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hay registros de cortes',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Los registros aparecerán aquí una vez que se creen',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecords,
                        child: ListView.builder(
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            return _buildCortesCard(_filteredRecords[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
