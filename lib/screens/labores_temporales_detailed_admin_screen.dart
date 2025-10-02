import 'package:flutter/material.dart';
import 'dart:convert';
import '../widget/share_dialog_widget.dart';

class LaboresTemporalesDetailedAdminScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const LaboresTemporalesDetailedAdminScreen({Key? key, required this.record}) : super(key: key);

  @override
  _LaboresTemporalesDetailedAdminScreenState createState() => _LaboresTemporalesDetailedAdminScreenState();
}

class _LaboresTemporalesDetailedAdminScreenState extends State<LaboresTemporalesDetailedAdminScreen> {
  List<Map<String, dynamic>> _cuadrantes = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, Map<String, Map<int, String?>>> _resultados = {};

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    print('=== DEBUG: Parseando datos de labores temporales ===');
    print('Record keys: ${widget.record.keys.toList()}');
    
    try {
      // Parsear cuadrantes
      final cuadrantesData = widget.record['cuadrantes_json'];
      print('cuadrantes_json type: ${cuadrantesData.runtimeType}');
      
      if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
        _cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
      } else if (cuadrantesData is List) {
        _cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
      }
      print('_cuadrantes parsed: ${_cuadrantes.length} items');
      
      // Parsear items
      final itemsData = widget.record['items_json'];
      print('items_json type: ${itemsData.runtimeType}');
      
      if (itemsData is String && itemsData.isNotEmpty) {
        _items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
      } else if (itemsData is List) {
        _items = List<Map<String, dynamic>>.from(itemsData);
      }
      print('_items parsed: ${_items.length} items');
      
      _parseResultados();
    } catch (e) {
      print('Error parseando datos: $e');
    }
  }

  void _parseResultados() {
    print('=== DEBUG: _parseResultados ===');
    print('_items.length: ${_items.length}');
    
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      print('Item $i: ${item.keys.toList()}');
      print('Item $i contenido: $item');
      
      final itemProceso = item['proceso']?.toString() ?? '';
      print('Item $i proceso: $itemProceso');
      
      if (item['resultadosPorCuadranteParada'] != null) {
        print('Item $i tiene resultadosPorCuadranteParada');
        final resultadosPorCuadranteParada = item['resultadosPorCuadranteParada'];
        if (resultadosPorCuadranteParada is Map<String, dynamic>) {
          resultadosPorCuadranteParada.forEach((cuadrante, paradas) {
            if (!_resultados.containsKey(cuadrante)) {
              _resultados[cuadrante] = {};
            }
            if (paradas is Map<String, dynamic>) {
              Map<int, String?> paradasMap = {};
              paradas.forEach((parada, resultado) {
                final paradaNum = int.tryParse(parada) ?? 0;
                paradasMap[paradaNum] = resultado?.toString();
              });
              _resultados[cuadrante]![itemProceso] = paradasMap;
            }
          });
        }
      }
    }
    
    print('Resultados finales: ${_resultados.keys.toList()}');
    print('_resultados keys: ${_resultados.keys.toList()}');
    
    // Calcular porcentaje promedio
    final promedio = _calcularPorcentajePromedio();
    print('Promedio de cuadrantes: ${promedio.toStringAsFixed(1)}%');
  }

  double _calcularPorcentajePromedio() {
    if (_cuadrantes.isEmpty) return 0.0;
    
    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;
    
    for (var cuadrante in _cuadrantes) {
      final cuadranteId = cuadrante['cuadrante']?.toString() ?? '';
      final bloque = cuadrante['bloque']?.toString() ?? '';
      if (cuadranteId.isEmpty || bloque.isEmpty) continue;
      
      // Construir el key correcto
      final resultadoKey = 'test_${bloque}_${cuadranteId}';
      
      // Buscar el item "Labores temporales conforme"
      String? itemLaboresConforme;
      for (var item in _resultados[resultadoKey]?.keys ?? {}) {
        final itemStr = item?.toString() ?? '';
        if (itemStr.toLowerCase().contains('labores temporales conforme')) {
          itemLaboresConforme = itemStr;
          break;
        }
      }
      
      if (itemLaboresConforme != null && _resultados.containsKey(resultadoKey)) {
        final cuadranteResultados = _resultados[resultadoKey]!;
        if (cuadranteResultados.containsKey(itemLaboresConforme)) {
          final paradas = cuadranteResultados[itemLaboresConforme]!;
          int totalParadas = 0;
          int paradasConformes = 0;
          
          for (int i = 1; i <= 5; i++) {
            final resultado = paradas[i];
            if (resultado != null && resultado.isNotEmpty) {
              totalParadas++;
              if (resultado == '1') {
                paradasConformes++;
              }
            }
          }
          
          if (totalParadas > 0) {
            final porcentaje = (paradasConformes / 5) * 100;
            sumaPorcentajes += porcentaje;
            cuadrantesConDatos++;
          }
        }
      }
    }
    
    return cuadrantesConDatos > 0 ? (sumaPorcentajes / cuadrantesConDatos) : 0.0;
  }

  Color _getCumplimientoColor(double? porcentaje) {
    if (porcentaje == null) return Colors.grey;
    if (porcentaje >= 80) return Colors.green;
    if (porcentaje >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getCumplimientoText(double? porcentaje) {
    if (porcentaje == null) return 'Sin datos';
    if (porcentaje >= 80) return 'Alto';
    if (porcentaje >= 60) return 'Medio';
    return 'Bajo';
  }

  @override
  Widget build(BuildContext context) {
    final porcentaje = _calcularPorcentajePromedio();
    final cumplimientoColor = _getCumplimientoColor(porcentaje);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Labores Temporales - Detalles'),
        backgroundColor: Colors.purple,
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
            _buildHeader(porcentaje, cumplimientoColor),
            _buildCuadrantesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double porcentaje, Color cumplimientoColor) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMACIÓN GENERAL',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple[800],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finca: ${widget.record['finca_nombre'] ?? 'N/A'}'),
                    Text('Supervisor: ${widget.record['supervisor'] ?? 'N/A'}'),
                    Text('Kontroller: ${widget.record['usuario_nombre'] ?? 'N/A'}'),
                    Text('Fecha: ${_formatDate(widget.record['fecha_creacion'])}'),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cumplimientoColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${porcentaje.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _getCumplimientoText(porcentaje),
                    style: TextStyle(
                      color: cumplimientoColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuadrantesSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bloques y Resultados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purple[800],
            ),
          ),
          SizedBox(height: 16),
          ..._cuadrantes.map((cuadrante) => _buildCuadranteCard(cuadrante)),
        ],
      ),
    );
  }

  Widget _buildCuadranteCard(Map<String, dynamic> cuadrante) {
    final cuadranteId = cuadrante['cuadrante']?.toString() ?? 'N/A';
    final bloque = cuadrante['bloque'] ?? 'N/A';
    final variedad = cuadrante['variedad'] ?? 'N/A';
    final supervisor = cuadrante['supervisor'] ?? widget.record['supervisor'] ?? 'N/A';
    
    // Construir el key correcto para buscar en _resultados
    final resultadoKey = 'test_${bloque}_${cuadranteId}';
    
    print('=== DEBUG: _buildCuadranteCard ===');
    print('cuadrante: $cuadrante');
    print('cuadranteId: $cuadranteId');
    print('bloque: $bloque');
    print('resultadoKey: $resultadoKey');
    print('_resultados.keys: ${_resultados.keys.toList()}');
    print('_resultados.containsKey(resultadoKey): ${_resultados.containsKey(resultadoKey)}');
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bloque: $bloque',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
                _buildCuadranteStats(resultadoKey),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text('Cuadrante: $cuadranteId', style: TextStyle(fontSize: 14)),
                SizedBox(width: 20),
                Text('Variedad: $variedad', style: TextStyle(fontSize: 14)),
                SizedBox(width: 20),
                Text('Supervisor: $supervisor', style: TextStyle(fontSize: 14)),
              ],
            ),
            SizedBox(height: 16),
            _buildParadasTable(resultadoKey),
          ],
        ),
      ),
    );
  }

  Widget _buildCuadranteStats(String resultadoKey) {
    if (!_resultados.containsKey(resultadoKey)) {
      return Text('Sin datos disponibles', style: TextStyle(color: Colors.grey));
    }

    final cuadranteResultados = _resultados[resultadoKey]!;
    
    // Buscar el item "Labores temporales conforme"
    String? itemLaboresConforme;
    for (var item in cuadranteResultados.keys) {
      if (item.toLowerCase().contains('labores temporales conforme')) {
        itemLaboresConforme = item;
        break;
      }
    }
    
    if (itemLaboresConforme == null || !cuadranteResultados.containsKey(itemLaboresConforme)) {
      return Text('Sin datos disponibles', style: TextStyle(color: Colors.grey));
    }

    final paradas = cuadranteResultados[itemLaboresConforme]!;
    int totalParadas = 0;
    int paradasConLaboresConforme = 0;
    
    for (int i = 1; i <= 5; i++) {
      final resultado = paradas[i];
      if (resultado != null && resultado.isNotEmpty) {
        totalParadas++;
        if (resultado == '1') {
          paradasConLaboresConforme++;
        }
      }
    }
    
    final porcentaje = totalParadas > 0 ? (paradasConLaboresConforme / 5) * 100 : 0.0;
    final color = _getCumplimientoColor(porcentaje);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
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
    );
  }

  Widget _buildParadasTable(String resultadoKey) {
    if (!_resultados.containsKey(resultadoKey)) {
      return Text('Sin datos disponibles', style: TextStyle(color: Colors.grey));
    }

    final cuadranteResultados = _resultados[resultadoKey]!;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.purple[50]),
        columns: [
          DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
          for (int i = 1; i <= 5; i++)
            DataColumn(label: Text('P$i', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _items.map((item) {
          final itemProceso = item['proceso']?.toString() ?? '';
          final paradas = cuadranteResultados[itemProceso] ?? {};
          
          return DataRow(
            cells: [
              DataCell(
                Container(
                  width: 200,
                  child: Text(
                    itemProceso,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              for (int i = 1; i <= 5; i++)
                DataCell(
                  Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _getResultadoColor(paradas[i]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _getResultadoTexto(paradas[i]),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getResultadoColor(String? resultado) {
    if (resultado == null || resultado.isEmpty) return Colors.grey[300]!;
    if (resultado == '1') return Colors.green;
    if (resultado == '0') return Colors.red;
    return Colors.orange;
  }

  String _getResultadoTexto(String? resultado) {
    if (resultado == null || resultado.isEmpty) return '';
    if (resultado == '1') return 'X';
    if (resultado == '0') return 'NC';
    return resultado.toUpperCase();
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => ShareDialog(
        recordData: widget.record,
        checklistType: 'labores_temporales',
      ),
    );
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

