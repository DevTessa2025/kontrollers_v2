import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../widget/share_dialog_widget.dart';

class CortesDetailedAdminScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const CortesDetailedAdminScreen({
    Key? key,
    required this.record,
  }) : super(key: key);

  @override
  State<CortesDetailedAdminScreen> createState() => _CortesDetailedAdminScreenState();
}

class _CortesDetailedAdminScreenState extends State<CortesDetailedAdminScreen> {
  List<Map<String, dynamic>> _cuadrantes = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, Map<String, Map<int, String?>>> _resultados = {};

  @override
  void initState() {
    super.initState();
    _parseData();
  }


  double _calcularPorcentajePromedio() {
    if (_cuadrantes.isEmpty) return 0.0;
    
    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;
    
    for (var cuadrante in _cuadrantes) {
      final cuadranteId = cuadrante['cuadrante']?.toString() ?? cuadrante['id']?.toString() ?? '';
      
      // Calcular porcentaje para este cuadrante
      int totalMuestras = 0;
      int muestrasConCorteConforme = 0;
      
      if (_resultados.containsKey(cuadranteId)) {
        _resultados[cuadranteId]!.forEach((item, muestras) {
          if (item.toLowerCase().contains('corte conforme')) {
            muestras.forEach((muestra, resultado) {
              if (resultado != null && resultado.isNotEmpty) {
                totalMuestras++;
                if (resultado.toLowerCase() == 'c' || resultado == '1') {
                  muestrasConCorteConforme++;
                }
              }
            });
          }
        });
      }
      
      if (totalMuestras > 0) {
        final porcentajeCuadrante = (muestrasConCorteConforme / 10 * 100);
        sumaPorcentajes += porcentajeCuadrante;
        cuadrantesConDatos++;
        print('Cuadrante $cuadranteId: $muestrasConCorteConforme/10 = ${porcentajeCuadrante.toStringAsFixed(1)}%');
      }
    }
    
    final promedio = cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
    print('Promedio de cuadrantes: ${promedio.toStringAsFixed(1)}%');
    
    return promedio;
  }


  void _parseData() {
    try {
      print('=== DEBUG: Parseando datos de cortes ===');
      print('Record keys: ${widget.record.keys.toList()}');
      print('cuadrantes_json type: ${widget.record['cuadrantes_json'].runtimeType}');
      print('items_json type: ${widget.record['items_json'].runtimeType}');
      
      // Parsear cuadrantes
      if (widget.record['cuadrantes_json'] != null) {
        final cuadrantesData = widget.record['cuadrantes_json'];
        print('cuadrantesData: $cuadrantesData');
        if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
          _cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
        } else if (cuadrantesData is List) {
          _cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
        }
        print('_cuadrantes parsed: ${_cuadrantes.length} items');
      }

      // Parsear items
      if (widget.record['items_json'] != null) {
        final itemsData = widget.record['items_json'];
        print('itemsData: $itemsData');
        if (itemsData is String && itemsData.isNotEmpty) {
          _items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
        } else if (itemsData is List) {
          _items = List<Map<String, dynamic>>.from(itemsData);
        }
        print('_items parsed: ${_items.length} items');
      }

      // Parsear resultados
      _parseResultados();
      print('_resultados keys: ${_resultados.keys.toList()}');
    } catch (e) {
      print('Error parseando datos: $e');
    }
  }

  void _parseResultados() {
    // Estructura: _resultados[cuadrante][item][muestra] = resultado
    for (var item in _items) {
      final itemId = item['id']?.toString() ?? '';
      final itemProceso = item['proceso'] ?? 'Item $itemId';
      
      if (item['resultadosPorCuadrante'] != null) {
        final resultadosPorCuadrante = item['resultadosPorCuadrante'];
        if (resultadosPorCuadrante is Map<String, dynamic>) {
          resultadosPorCuadrante.forEach((cuadrante, muestras) {
            if (!_resultados.containsKey(cuadrante)) {
              _resultados[cuadrante] = {};
            }
            if (!_resultados[cuadrante]!.containsKey(itemProceso)) {
              _resultados[cuadrante]![itemProceso] = {};
            }
            
            if (muestras is Map<String, dynamic>) {
              muestras.forEach((muestra, resultado) {
                final muestraNum = int.tryParse(muestra) ?? 0;
                _resultados[cuadrante]![itemProceso]![muestraNum] = resultado;
              });
            }
          });
        }
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(bottom: BorderSide(color: Colors.blue[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.record['finca_nombre'] ?? 'Sin finca',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      'Kontroller: ${widget.record['usuario_nombre'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    Text(
                      'Fecha: ${_formatDate(widget.record['fecha_creacion'])}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getCumplimientoColor(_calcularPorcentajePromedio()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_calcularPorcentajePromedio().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildStatCard('Bloques', '${_cuadrantes.length}', Colors.blue),
              SizedBox(width: 8),
              _buildStatCard('Promedio', '${_calcularPorcentajePromedio().toStringAsFixed(1)}%', Colors.green),
              SizedBox(width: 8),
              _buildStatCard('Cumplimiento', _getCumplimientoText(_calcularPorcentajePromedio()), Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
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
        ),
      ),
    );
  }

  Widget _buildCuadrantesSection() {
    print('=== DEBUG: _buildCuadrantesSection ===');
    print('_cuadrantes.length: ${_cuadrantes.length}');
    print('_items.length: ${_items.length}');
    print('_resultados.keys: ${_resultados.keys.toList()}');
    
    if (_cuadrantes.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Text(
                'No hay cuadrantes registrados',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Datos disponibles:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text('Cuadrantes: ${_cuadrantes.length}'),
              Text('Items: ${_items.length}'),
              Text('Resultados: ${_resultados.length}'),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Bloques y Resultados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        ..._cuadrantes.map((cuadrante) => _buildCuadranteCard(cuadrante)),
      ],
    );
  }

  Widget _buildCuadranteCard(Map<String, dynamic> cuadrante) {
    final cuadranteId = cuadrante['cuadrante'] ?? 'N/A';
    final bloque = cuadrante['bloque'] ?? 'N/A';
    final variedad = cuadrante['variedad'] ?? 'N/A';
    final supervisor = cuadrante['supervisor'] ?? widget.record['supervisor'] ?? 'N/A';
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        'Bloque: $bloque',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cuadrante: $cuadranteId',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        'Variedad: $variedad',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        'Supervisor: $supervisor',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                _buildCuadranteStats(cuadranteId),
              ],
            ),
            SizedBox(height: 16),
            _buildMuestrasTable(cuadranteId),
          ],
        ),
      ),
    );
  }

  Widget _buildCuadranteStats(String cuadranteId) {
    int totalMuestras = 0;
    int muestrasConCorteConforme = 0;

    if (_resultados.containsKey(cuadranteId)) {
      _resultados[cuadranteId]!.forEach((item, muestras) {
        // Solo procesar el item "Corte conforme"
        if (item.toLowerCase().contains('corte conforme')) {
          muestras.forEach((muestra, resultado) {
            if (resultado != null && resultado.isNotEmpty) {
              totalMuestras++;
              // Contar solo las muestras con 'C' en "Corte conforme"
              if (resultado.toLowerCase() == 'c' || resultado == '1') {
                muestrasConCorteConforme++;
              }
            }
          });
        }
      });
    }

    final porcentaje = totalMuestras > 0 ? (muestrasConCorteConforme / 10 * 100) : 0.0;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getCumplimientoColor(porcentaje),
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
          '$muestrasConCorteConforme/$totalMuestras',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMuestrasTable(String cuadranteId) {
    if (!_resultados.containsKey(cuadranteId) || _resultados[cuadranteId]!.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No hay resultados para este cuadrante',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 8,
        headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
        columns: [
          DataColumn(
            label: Text(
              'Item',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...List.generate(10, (index) => DataColumn(
            label: Text(
              'M${index + 1}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          )),
        ],
        rows: _resultados[cuadranteId]!.entries.map((entry) {
          final item = entry.key;
          final muestras = entry.value;
          
          return DataRow(
            cells: [
              DataCell(
                Container(
                  width: 120,
                  child: Text(
                    item,
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              ...List.generate(10, (index) {
                final muestra = index + 1;
                final resultado = muestras[muestra];
                return DataCell(
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _getResultadoColor(resultado),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(
                        _getResultadoText(resultado),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getResultadoTextColor(resultado),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getResultadoColor(String? resultado) {
    if (resultado == null || resultado.isEmpty) return Colors.grey[200]!;
    if (resultado.toLowerCase() == 'c' || resultado == '1') return Colors.green[300]!;
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return Colors.red[300]!;
    return Colors.orange[300]!;
  }

  String _getResultadoText(String? resultado) {
    if (resultado == null || resultado.isEmpty) return '';
    if (resultado.toLowerCase() == 'c' || resultado == '1') return 'C';
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return 'NC';
    return resultado;
  }

  Color _getResultadoTextColor(String? resultado) {
    if (resultado == null || resultado.isEmpty) return Colors.grey[600]!;
    if (resultado.toLowerCase() == 'c' || resultado == '1') return Colors.green[800]!;
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return Colors.red[800]!;
    return Colors.orange[800]!;
  }

  Color _getCumplimientoColor(double? porcentaje) {
    if (porcentaje == null) return Colors.grey;
    if (porcentaje >= 80) return Colors.green;
    if (porcentaje >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getCumplimientoText(double porcentaje) {
    if (porcentaje >= 80) return 'Alto';
    if (porcentaje >= 60) return 'Medio';
    return 'Bajo';
  }

  Future<void> _showShareDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ShareDialog(
          recordData: widget.record,
          checklistType: 'cortes',
        );
      },
    );
  }


  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de Cortes'),
        backgroundColor: Colors.blue,
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
            _buildHeader(),
            _buildCuadrantesSection(),
          ],
        ),
      ),
    );
  }
}
