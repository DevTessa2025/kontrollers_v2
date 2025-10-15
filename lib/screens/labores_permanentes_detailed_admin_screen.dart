import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../widget/share_dialog_widget.dart';

class LaboresPermanentesDetailedAdminScreen extends StatefulWidget {
  final Map<String, dynamic> record;

  const LaboresPermanentesDetailedAdminScreen({
    Key? key,
    required this.record,
  }) : super(key: key);

  @override
  State<LaboresPermanentesDetailedAdminScreen> createState() => _LaboresPermanentesDetailedAdminScreenState();
}

class _LaboresPermanentesDetailedAdminScreenState extends State<LaboresPermanentesDetailedAdminScreen> {
  List<Map<String, dynamic>> _cuadrantes = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, Map<String, Map<int, String?>>> _resultados = {};

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    print('=== DEBUG: Parseando datos de labores permanentes ===');
    print('Record keys: ${widget.record.keys.toList()}');
    
    // Parsear cuadrantes_json
    if (widget.record['cuadrantes_json'] != null) {
      final cuadrantesData = widget.record['cuadrantes_json'];
      print('cuadrantes_json type: ${cuadrantesData.runtimeType}');
      
      if (cuadrantesData is String && cuadrantesData.isNotEmpty) {
        _cuadrantes = List<Map<String, dynamic>>.from(jsonDecode(cuadrantesData));
      } else if (cuadrantesData is List) {
        _cuadrantes = List<Map<String, dynamic>>.from(cuadrantesData);
      }
      print('_cuadrantes parsed: ${_cuadrantes.length} items');
    }
    
    // Parsear items_json
    if (widget.record['items_json'] != null) {
      final itemsData = widget.record['items_json'];
      print('items_json type: ${itemsData.runtimeType}');
      
      if (itemsData is String && itemsData.isNotEmpty) {
        _items = List<Map<String, dynamic>>.from(jsonDecode(itemsData));
      } else if (itemsData is List) {
        _items = List<Map<String, dynamic>>.from(itemsData);
      }
      print('_items parsed: ${_items.length} items');
    }
    
    // Parsear resultados
    _resultados = _parseResultados();
    print('_resultados keys: ${_resultados.keys.toList()}');
  }

  Map<String, Map<String, Map<int, String?>>> _parseResultados() {
    Map<String, Map<String, Map<int, String?>>> resultados = {};
    
    print('=== DEBUG: _parseResultados ===');
    print('_items.length: ${_items.length}');
    
    for (int i = 0; i < _items.length; i++) {
      var item = _items[i];
      print('Item $i: ${item.keys.toList()}');
      print('Item $i contenido: $item');
      
      final itemProceso = item['proceso']?.toString() ?? '';
      print('Item $i proceso: $itemProceso');
      
      // Buscar diferentes estructuras posibles
      if (item['resultadosPorCuadrante'] != null) {
        print('Item $i tiene resultadosPorCuadrante');
        final resultadosPorCuadrante = item['resultadosPorCuadrante'];
        if (resultadosPorCuadrante is Map<String, dynamic>) {
          resultadosPorCuadrante.forEach((cuadrante, muestras) {
            if (!resultados.containsKey(cuadrante)) {
              resultados[cuadrante] = {};
            }
            if (muestras is Map<String, dynamic>) {
              Map<int, String?> muestrasMap = {};
              muestras.forEach((muestra, resultado) {
                final muestraNum = int.tryParse(muestra) ?? 0;
                muestrasMap[muestraNum] = resultado?.toString();
              });
              resultados[cuadrante]![itemProceso] = muestrasMap;
            }
          });
        }
      } else if (item['resultadosPorCuadranteParada'] != null) {
        print('Item $i tiene resultadosPorCuadranteParada');
        final resultadosPorCuadranteParada = item['resultadosPorCuadranteParada'];
        if (resultadosPorCuadranteParada is Map<String, dynamic>) {
          resultadosPorCuadranteParada.forEach((cuadrante, paradas) {
            if (!resultados.containsKey(cuadrante)) {
              resultados[cuadrante] = {};
            }
            if (paradas is Map<String, dynamic>) {
              Map<int, String?> paradasMap = {};
              paradas.forEach((parada, resultado) {
                final paradaNum = int.tryParse(parada) ?? 0;
                paradasMap[paradaNum] = resultado?.toString();
              });
              resultados[cuadrante]![itemProceso] = paradasMap;
            }
          });
        }
      } else {
        print('Item $i no tiene estructura de resultados reconocida');
      }
    }
    
    print('Resultados finales: ${resultados.keys.toList()}');
    return resultados;
  }

  double _calcularPorcentajePromedio() {
    if (_cuadrantes.isEmpty) return 0.0;
    double sumaPorcentajes = 0.0;
    int cuadrantesConDatos = 0;
    for (var cuadrante in _cuadrantes) {
      final cuadranteId = cuadrante['cuadrante']?.toString() ?? cuadrante['id']?.toString() ?? '';
      final bloque = cuadrante['bloque']?.toString() ?? '';
      final supervisor = cuadrante['supervisor']?.toString() ?? (widget.record['supervisor']?.toString() ?? '');
      if (cuadranteId.isEmpty || bloque.isEmpty) continue;
      final resultadoKey = '${supervisor}_${bloque}_${cuadranteId}';
      int marcados = 0;
      const int paradas = 5;
      final int numItems = _items.length;
      if (_resultados.containsKey(resultadoKey)) {
        final cuadranteResultados = _resultados[resultadoKey]!;
        for (final entry in cuadranteResultados.entries) {
          final mapaParadas = entry.value;
          for (int p = 1; p <= paradas; p++) {
            final v = mapaParadas[p];
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
  }

  Widget _buildHeader() {
    final porcentaje = _calcularPorcentajePromedio();
    final cumplimientoColor = _getCumplimientoColor(porcentaje);
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMACIÓN GENERAL',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finca: ${widget.record['finca_nombre'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'Supervisor: ${widget.record['supervisor'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'Kontroller: ${widget.record['usuario_nombre'] ?? 'N/A'}',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'Fecha: ${_formatDate(widget.record['fecha_creacion'])}',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
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
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getCumplimientoText(porcentaje),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _buildResumenCumplimiento() {
    final promedio = _calcularPorcentajePromedio();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'RESUMEN DE CUMPLIMIENTO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              Text(
                'Bloques evaluados: ${_cuadrantes.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 20),
              Text(
                'Promedio: ${promedio.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
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
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No hay datos de cuadrantes disponibles',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
              color: Colors.black87,
            ),
          ),
        ),
        ..._cuadrantes.map((cuadrante) => _buildCuadranteCard(cuadrante)),
      ],
    );
  }

  Widget _buildCuadranteCard(Map<String, dynamic> cuadrante) {
    final cuadranteId = cuadrante['cuadrante']?.toString() ?? 'N/A';
    final bloque = cuadrante['bloque'] ?? 'N/A';
    final variedad = cuadrante['variedad'] ?? 'N/A';
    final supervisor = cuadrante['supervisor'] ?? widget.record['supervisor'] ?? 'N/A';
    
    // Construir el key correcto para buscar en _resultados
    final resultadoKey = '${supervisor}_${bloque}_${cuadranteId}';
    
    print('=== DEBUG: _buildCuadranteCard ===');
    print('cuadrante: $cuadrante');
    print('cuadranteId: $cuadranteId');
    print('bloque: $bloque');
    print('resultadoKey: $resultadoKey');
    print('_resultados.keys: ${_resultados.keys.toList()}');
    print('_resultados.containsKey(resultadoKey): ${_resultados.containsKey(resultadoKey)}');
    
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
                          color: Colors.deepPurple[800],
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
                _buildCuadranteStats(resultadoKey),
              ],
            ),
            SizedBox(height: 16),
            _buildMuestrasTable(resultadoKey),
            SizedBox(height: 12),
            _buildFotosSection(cuadrante),
          ],
        ),
      ),
    );
  }

  Widget _buildCuadranteStats(String cuadranteId) {
    // Nuevo criterio: 100% si nada está marcado; baja al marcar
    if (!_resultados.containsKey(cuadranteId)) {
      return Text('Sin datos disponibles', style: TextStyle(color: Colors.grey));
    }

    final cuadranteResultados = _resultados[cuadranteId]!;
    int marcados = 0;
    const int paradas = 5;
    final int numItems = _items.length;

    for (final entry in cuadranteResultados.entries) {
      final mapaParadas = entry.value;
      for (int p = 1; p <= paradas; p++) {
        final v = mapaParadas[p];
        if (v != null && v.toString().isNotEmpty) marcados++;
      }
    }

    final int totalSlots = numItems * paradas;
    final int noMarcados = totalSlots - marcados;
    final double porcentaje = totalSlots > 0 ? (noMarcados / totalSlots) * 100 : 0.0;

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
          _getCumplimientoText(porcentaje),
          style: TextStyle(
            fontSize: 12,
            color: _getCumplimientoColor(porcentaje),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMuestrasTable(String cuadranteId) {
    if (!_resultados.containsKey(cuadranteId)) {
      return Text('Sin datos disponibles');
    }

    final cuadranteResultados = _resultados[cuadranteId]!;
    
    print('=== DEBUG: _buildMuestrasTable ===');
    print('cuadranteId: $cuadranteId');
    print('cuadranteResultados: $cuadranteResultados');
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
        columns: [
          DataColumn(label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
          for (int i = 1; i <= 5; i++) // Labores permanentes usa paradas 1-5, no muestras M1-M10
            DataColumn(label: Text('P$i', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _items.map((item) {
          final itemProceso = item['proceso']?.toString() ?? '';
          final paradas = cuadranteResultados[itemProceso] ?? {};
          
          print('Item: $itemProceso, Paradas: $paradas');
          
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
              for (int i = 1; i <= 5; i++) // Paradas 1-5 para labores permanentes
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

  Widget _buildFotosSection(Map<String, dynamic> cuadrante) {
    final List<Map<String, dynamic>> fotos = _getFotosFromCuadrante(cuadrante);
    if (fotos.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('Sin fotos adjuntas', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos adjuntas (${fotos.length}):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fotos.map((f) => _buildFotoPreview(f)).toList(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFotosFromCuadrante(Map<String, dynamic> cuadrante) {
    List<Map<String, dynamic>> fotos = [];
    if (cuadrante['fotos'] is List) {
      fotos = List<Map<String, dynamic>>.from(cuadrante['fotos']);
    } else if (cuadrante['fotos'] is String && (cuadrante['fotos'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(cuadrante['fotos'] as String);
        if (decoded is List) fotos = List<Map<String, dynamic>>.from(decoded);
      } catch (_) {}
    }
    if (fotos.isEmpty && cuadrante['fotoBase64'] != null && (cuadrante['fotoBase64'] as String).isNotEmpty) {
      fotos.add({'base64': cuadrante['fotoBase64'], 'etiqueta': null});
    }
    return fotos;
  }

  Widget _buildFotoPreview(Map<String, dynamic> foto) {
    final base64Image = foto['base64']?.toString();
    final etiqueta = foto['etiqueta']?.toString();
    if (base64Image == null || base64Image.isEmpty) {
      return Container(width: 90, height: 90, alignment: Alignment.center, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey));
    }
    try {
      final bytes = base64Decode(base64Image);
      final etiquetaText = _getItemNameFromEtiqueta(etiqueta);
      return GestureDetector(
        onTap: () => _showFullImage(bytes, etiquetaText),
        child: Container(
          width: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(bytes, width: 100, height: 100, fit: BoxFit.cover),
              ),
              if (etiquetaText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: Colors.deepPurple[600],
                  child: Text(
                    etiquetaText,
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (_) {
      return Container(width: 90, height: 90, alignment: Alignment.center, color: Colors.red[100], child: Icon(Icons.error, color: Colors.red));
    }
  }

  String _getItemNameFromEtiqueta(String? etiqueta) {
    if (etiqueta == null || etiqueta.isEmpty) return '';
    final int? id = int.tryParse(etiqueta);
    if (id == null) return '';
    try {
      final found = _items.firstWhere((it) => (it['id']?.toString() ?? '') == id.toString(), orElse: () => {});
      return found['proceso']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _showFullImage(Uint8List bytes, String etiquetaText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (etiquetaText.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  color: Colors.deepPurple[600],
                  child: Text(etiquetaText, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9, maxHeight: MediaQuery.of(context).size.height * 0.8),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cerrar')),
            ],
          ),
        );
      },
    );
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

  Color _getResultadoColor(String? resultado) {
    if (resultado == null || resultado.isEmpty) return Colors.grey[300]!;
    if (resultado.toLowerCase() == 'c' || resultado == '1') return Colors.green;
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return Colors.red;
    return Colors.orange;
  }

  String _getResultadoTexto(String? resultado) {
    if (resultado == null || resultado.isEmpty) return '';
    if (resultado.toLowerCase() == 'c' || resultado == '1') return 'X';
    if (resultado.toLowerCase() == 'nc' || resultado == '0') return 'NC';
    return resultado.toUpperCase();
  }

  Future<void> _showShareDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ShareDialog(
          recordData: widget.record,
          checklistType: 'labores_permanentes',
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
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Labores Permanentes - Detalles'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _showShareDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 20),
            _buildResumenCumplimiento(),
            SizedBox(height: 20),
            _buildCuadrantesSection(),
          ],
        ),
      ),
    );
  }
}
