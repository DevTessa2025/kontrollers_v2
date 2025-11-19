import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ChecklistAforoScreen extends StatefulWidget {
  @override
  _ChecklistAforoScreenState createState() => _ChecklistAforoScreenState();
}

class _ChecklistAforoScreenState extends State<ChecklistAforoScreen> {
  // Controladores para los campos de entrada
  final TextEditingController _aforoMedioController = TextEditingController();
  final TextEditingController _tiempoTranscurridoController = TextEditingController();

  // Datos fijos
  static const double _cReferencia = 12.13; // v/cama
  static const double _sCama = 80.0; // s/cama

  // Resultados calculados
  double? _volumenExtrapolado; // ml por cama
  double? _volumenRealAplicado; // Litros
  double? _diferenciaAbsoluta;
  double? _desviacionPorcentual;

  @override
  void dispose() {
    _aforoMedioController.dispose();
    _tiempoTranscurridoController.dispose();
    super.dispose();
  }

  void _calcularAforo() {
    // Validar que los campos tengan valores
    if (_aforoMedioController.text.trim().isEmpty || 
        _tiempoTranscurridoController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Por favor complete todos los campos',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    try {
      // Obtener valores de entrada
      double aforoMedio = double.parse(_aforoMedioController.text.trim());
      double tiempoTranscurrido = double.parse(_tiempoTranscurridoController.text.trim());

      // Validar que los valores sean positivos
      if (aforoMedio <= 0 || tiempoTranscurrido <= 0) {
        Fluttertoast.showToast(
          msg: 'Los valores deben ser mayores a cero',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
        return;
      }

      // 1. Calcular Volumen Extrapolado a mililitros por cama
      // (aforo medio de lanza en ml * s/cama) / tiempo transcurrido en segundos
      _volumenExtrapolado = (aforoMedio * _sCama) / tiempoTranscurrido;

      // 2. Calcular Volumen Real Aplicado en Litros
      // (volumen extrapolado a mililitros) / 1000
      _volumenRealAplicado = _volumenExtrapolado! / 1000;

      // 3. Calcular Diferencia Absoluta
      // (Volumen real aplicado) - (v/cama)
      _diferenciaAbsoluta = _volumenRealAplicado! - _cReferencia;

      // 4. Calcular Desviación Porcentual
      // ((Diferencia Absoluta) / (v/cama)) * 100
      _desviacionPorcentual = (_diferenciaAbsoluta! / _cReferencia) * 100;

      setState(() {});
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error en el cálculo: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  void _limpiarCampos() {
    _aforoMedioController.clear();
    _tiempoTranscurridoController.clear();
    setState(() {
      _volumenExtrapolado = null;
      _volumenRealAplicado = null;
      _diferenciaAbsoluta = null;
      _desviacionPorcentual = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Cálculo de Aforo'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de datos fijos
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Datos de Referencia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow('C de referencia (v/cama):', _cReferencia.toStringAsFixed(2)),
                  _buildInfoRow('s/cama:', _sCama.toStringAsFixed(0)),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Campos de entrada
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Datos de Entrada',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Campo: Aforo medio de la lanza
                  _buildTextField(
                    controller: _aforoMedioController,
                    label: 'Aforo medio de la lanza',
                    hint: 'Ingrese el valor en mililitros (ml)',
                    icon: Icons.water_drop,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {
                      // Limpiar resultados cuando cambia el input
                      _volumenExtrapolado = null;
                      _volumenRealAplicado = null;
                      _diferenciaAbsoluta = null;
                      _desviacionPorcentual = null;
                    }),
                  ),

                  SizedBox(height: 16),

                  // Campo: Tiempo transcurrido
                  _buildTextField(
                    controller: _tiempoTranscurridoController,
                    label: 'Tiempo transcurrido durante la medición',
                    hint: 'Ingrese el tiempo en segundos',
                    icon: Icons.timer,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {
                      // Limpiar resultados cuando cambia el input
                      _volumenExtrapolado = null;
                      _volumenRealAplicado = null;
                      _diferenciaAbsoluta = null;
                      _desviacionPorcentual = null;
                    }),
                  ),

                  SizedBox(height: 24),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _limpiarCampos,
                          icon: Icon(Icons.clear),
                          label: Text('Limpiar'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _calcularAforo,
                          icon: Icon(Icons.calculate),
                          label: Text('Calcular'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Resultados calculados
            if (_volumenExtrapolado != null) ...[
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calculate, color: Colors.green[700], size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Resultados Calculados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Volumen Extrapolado
                    _buildResultCard(
                      'Volumen Extrapolado',
                      'Mililitros por cama',
                      _volumenExtrapolado!,
                      'ml',
                      Colors.blue,
                    ),

                    SizedBox(height: 12),

                    // Volumen Real Aplicado
                    _buildResultCard(
                      'Volumen Real Aplicado',
                      'Litros',
                      _volumenRealAplicado!,
                      'L',
                      Colors.green,
                    ),

                    SizedBox(height: 12),

                    // Diferencia Absoluta
                    _buildResultCard(
                      'Diferencia Absoluta',
                      'Diferencia respecto a v/cama',
                      _diferenciaAbsoluta!,
                      'L',
                      _diferenciaAbsoluta!.abs() <= 1.0 ? Colors.orange : Colors.red,
                    ),

                    SizedBox(height: 12),

                    // Desviación Porcentual
                    _buildResultCard(
                      'Desviación Porcentual',
                      'Porcentaje de desviación',
                      _desviacionPorcentual!,
                      '%',
                      _desviacionPorcentual!.abs() <= 10.0 ? Colors.green : 
                      _desviacionPorcentual!.abs() <= 20.0 ? Colors.orange : Colors.red,
                    ),

                    SizedBox(height: 16),

                    // Información adicional
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _desviacionPorcentual!.abs() <= 10.0 ? Icons.check_circle : 
                            _desviacionPorcentual!.abs() <= 20.0 ? Icons.warning : Icons.error,
                            color: _desviacionPorcentual!.abs() <= 10.0 ? Colors.green : 
                            _desviacionPorcentual!.abs() <= 20.0 ? Colors.orange : Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _desviacionPorcentual!.abs() <= 10.0 
                                ? 'Desviación dentro del rango aceptable (≤10%)'
                                : _desviacionPorcentual!.abs() <= 20.0
                                  ? 'Desviación moderada (10-20%)'
                                  : 'Desviación alta (>20%)',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildResultCard(
    String title,
    String subtitle,
    double value,
    String unit,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.analytics,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(4),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

