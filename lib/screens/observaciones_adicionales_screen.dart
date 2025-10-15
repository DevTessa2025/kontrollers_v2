import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/observaciones_adicionales_service.dart';
import '../services/auth_service.dart';
import '../services/cosecha_dropdown_service.dart';
import '../models/dropdown_models.dart';
import 'observaciones_adicionales_records_screen.dart';

class ObservacionesAdicionalesScreen extends StatefulWidget {
  final ObservacionAdicional? observacionParaEditar;
  
  const ObservacionesAdicionalesScreen({
    Key? key,
    this.observacionParaEditar,
  }) : super(key: key);

  @override
  State<ObservacionesAdicionalesScreen> createState() => _ObservacionesAdicionalesScreenState();
}

class _ObservacionesAdicionalesScreenState extends State<ObservacionesAdicionalesScreen> with WidgetsBindingObserver {
  // Datos para los dropdowns
  List<Finca> fincas = [];
  List<Bloque> bloques = [];
  List<Variedad> variedades = [];
  
  // Valores seleccionados
  Finca? selectedFinca;
  Bloque? selectedBloque;
  Variedad? selectedVariedad;
  String _tipo = 'MIPE';
  final TextEditingController _obsController = TextEditingController();
  final List<String> _imagenes = [];
  bool _saving = false;
  bool _isLoadingDropdownData = true;
  
  // Campos específicos para MIPE
  final TextEditingController _blancoBiologicoController = TextEditingController();
  final TextEditingController _incidenciaController = TextEditingController();
  final TextEditingController _severidadController = TextEditingController();
  String _tercio = 'Alto';
  String _incidenciaNivel = 'Medio';
  String _severidadNivel = 'Medio';

  // Helpers de mapeo nivel<->porcentaje
  String _mapPctToNivel(double? pct) {
    if (pct == null) return 'Medio';
    if (pct >= 67) return 'Alto';
    if (pct >= 34) return 'Medio';
    return 'Bajo';
  }

  double _mapNivelToPct(String nivel) {
    switch (nivel) {
      case 'Alto':
        return 90;
      case 'Bajo':
        return 10;
      default:
        return 50;
    }
  }

  Widget _buildNivelRadios({
    required String titulo,
    required String nivel,
    required ValueChanged<String> onChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _nivelRadioOption('Bajo', nivel, onChange)),
            const SizedBox(width: 8),
            Expanded(child: _nivelRadioOption('Medio', nivel, onChange)),
            const SizedBox(width: 8),
            Expanded(child: _nivelRadioOption('Alto', nivel, onChange)),
          ],
        ),
      ],
    );
  }

  Widget _nivelRadioOption(String value, String group, ValueChanged<String> onChange) {
    final bool selected = group == value;
    return InkWell(
      onTap: () => onChange(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.teal[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.teal[700]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Radio<String>(
              value: value,
              groupValue: group,
              onChanged: (v) => onChange(v ?? value),
              activeColor: Colors.teal[700],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.teal[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDropdownData();
    _cargarDatosParaEditar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Método para detectar si hay cambios sin guardar
  bool _hasUnsavedChanges() {
    // Verificar si hay datos básicos completos
    if (selectedFinca == null || selectedBloque == null || selectedVariedad == null) {
      return false; // No hay datos para perder
    }

    // Verificar si hay contenido en los campos
    if (_obsController.text.trim().isNotEmpty || 
        _imagenes.isNotEmpty || 
        _tipo.isNotEmpty) {
      return true; // Hay datos sin guardar
    }

    return false;
  }

  // Método para mostrar diálogo de confirmación
  Future<bool> _showExitConfirmation() async {
    if (!_hasUnsavedChanges()) {
      return true; // No hay cambios, puede salir
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '¿Salir sin guardar?',
            style: TextStyle(
              color: Colors.teal[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Tienes cambios sin guardar. ¿Estás seguro de que quieres salir?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Salir'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Manejar el botón atrás del sistema
  @override
  Future<bool> didPopRoute() async {
    if (_hasUnsavedChanges()) {
      bool shouldExit = await _showExitConfirmation();
      if (!shouldExit) {
        return false; // No permitir salir
      }
    }
    return true; // Permitir salir
  }

  void _cargarDatosParaEditar() {
    if (widget.observacionParaEditar != null) {
      final obs = widget.observacionParaEditar!;
      
      // Cargar datos del registro a editar
      _tipo = obs.tipo;
      _obsController.text = obs.observacion;
      _imagenes.clear();
      _imagenes.addAll(obs.imagenesBase64);
      
      // Cargar campos específicos de MIPE si están disponibles
      if (obs.tipo == 'MIPE') {
        _blancoBiologicoController.text = obs.blancoBiologico ?? '';
        _incidenciaController.text = obs.incidencia?.toString() ?? '';
        _severidadController.text = obs.severidad?.toString() ?? '';
        _tercio = obs.tercio ?? 'Alto';
        // Nivel para radios en base al valor existente
        _incidenciaNivel = _mapPctToNivel(obs.incidencia);
        _severidadNivel = _mapPctToNivel(obs.severidad);
      }
      
      // Los dropdowns se cargarán después de _loadDropdownData()
      // y se seleccionarán en _loadDropdownData()
    }
  }

  Future<void> _loadDropdownData() async {
    setState(() {
      _isLoadingDropdownData = true;
    });

    try {
      // Cargar fincas
      List<Finca> loadedFincas = await CosechaDropdownService.getFincas();
      
      setState(() {
        fincas = loadedFincas;
        _isLoadingDropdownData = false;
      });

      if (fincas.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No se encontraron fincas disponibles',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      } else {
        // Si estamos editando, seleccionar los valores del registro
        if (widget.observacionParaEditar != null) {
          await _seleccionarValoresParaEditar();
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingDropdownData = false;
      });
      
      Fluttertoast.showToast(
        msg: 'Error cargando datos: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _seleccionarValoresParaEditar() async {
    if (widget.observacionParaEditar == null) return;
    
    final obs = widget.observacionParaEditar!;
    
    // Seleccionar finca
    selectedFinca = fincas.firstWhere(
      (f) => f.nombre == obs.fincaNombre,
      orElse: () => fincas.first,
    );
    
    // Cargar bloques para la finca seleccionada
    if (selectedFinca != null) {
      await _loadBloquesForFinca(selectedFinca!.nombre);
      
      // Seleccionar bloque
      selectedBloque = bloques.firstWhere(
        (b) => b.nombre == obs.bloqueNombre,
        orElse: () => bloques.first,
      );
      
      // Cargar variedades para el bloque seleccionado
      if (selectedBloque != null) {
        await _loadVariedadesForFincaAndBloque(selectedFinca!.nombre, selectedBloque!.nombre);
        
        // Seleccionar variedad
        selectedVariedad = variedades.firstWhere(
          (v) => v.nombre == obs.variedadNombre,
          orElse: () => variedades.first,
        );
      }
    }
    
    setState(() {});
  }

  // Método para cargar bloques según la finca seleccionada
  Future<void> _loadBloquesForFinca(String finca) async {
    setState(() {
      // Resetear selección de bloque y variedad cuando cambia la finca
      selectedBloque = null;
      selectedVariedad = null;
      // Limpiar las listas dependientes
      bloques = [];
      variedades = [];
    });

    try {
      List<Bloque> loadedBloques = await CosechaDropdownService.getBloquesByFinca(finca);
      
      setState(() {
        bloques = loadedBloques;
      });

      if (bloques.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No se encontraron bloques para la finca $finca',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error cargando bloques: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  // Método para cargar variedades según la finca y bloque seleccionados
  Future<void> _loadVariedadesForFincaAndBloque(String finca, String bloque) async {
    setState(() {
      // Resetear selección de variedad cuando cambia el bloque
      selectedVariedad = null;
      // Limpiar la lista de variedades
      variedades = [];
    });

    try {
      List<Variedad> loadedVariedades = await CosechaDropdownService.getVariedadesByFincaAndBloque(finca, bloque);
      
      setState(() {
        variedades = loadedVariedades;
      });

      if (variedades.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No se encontraron variedades para finca $finca, bloque $bloque',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error cargando variedades: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
    if (images.isEmpty) return;
    
    for (final image in images) {
      final bytes = await image.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() {
        _imagenes.add(b64);
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() {
      _imagenes.add(b64);
    });
  }

  Uint8List _b64ToBytes(String b64) => base64Decode(b64);

  Future<void> _guardar() async {
    if (selectedFinca == null || selectedBloque == null || selectedVariedad == null) {
      Fluttertoast.showToast(
        msg: 'Debe seleccionar finca, bloque y variedad',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    if (_obsController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Debe ingresar una observación',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await AuthService.getCurrentUser();
      
      if (widget.observacionParaEditar != null) {
        // Modo edición - actualizar registro existente
        final obs = widget.observacionParaEditar!;
        obs.fincaNombre = selectedFinca!.nombre;
        obs.bloqueNombre = selectedBloque!.nombre;
        obs.variedadNombre = selectedVariedad!.nombre;
        obs.tipo = _tipo;
        obs.observacion = _obsController.text.trim();
        obs.imagenesBase64 = _imagenes;
        obs.fechaActualizacion = DateTime.now();
        
        // Actualizar campos específicos de MIPE
        if (_tipo == 'MIPE') {
          obs.blancoBiologico = _blancoBiologicoController.text.trim();
          obs.incidencia = _mapNivelToPct(_incidenciaNivel);
          obs.severidad = _mapNivelToPct(_severidadNivel);
          obs.tercio = _tercio;
        } else {
          // Limpiar campos MIPE si no es tipo MIPE
          obs.blancoBiologico = null;
          obs.incidencia = null;
          obs.severidad = null;
          obs.tercio = null;
        }
        
        await ObservacionesAdicionalesService.update(obs);
        
        if (!mounted) return;
        Fluttertoast.showToast(
          msg: 'Observación actualizada localmente',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      } else {
        // Modo creación - crear nuevo registro
        final obs = ObservacionAdicional(
          fecha: DateTime.now(),
          fincaNombre: selectedFinca!.nombre,
          bloqueNombre: selectedBloque!.nombre,
          variedadNombre: selectedVariedad!.nombre,
          tipo: _tipo,
          observacion: _obsController.text.trim(),
          imagenesBase64: _imagenes,
          usuarioUsername: user?['username'],
          usuarioNombre: (user?['nombre'] as String?) ?? user?['username'],
        );
        
        // Agregar campos específicos de MIPE
        if (_tipo == 'MIPE') {
          obs.blancoBiologico = _blancoBiologicoController.text.trim();
          obs.incidencia = _mapNivelToPct(_incidenciaNivel);
          obs.severidad = _mapNivelToPct(_severidadNivel);
          obs.tercio = _tercio;
        }
        
        await ObservacionesAdicionalesService.save(obs);
        
        if (!mounted) return;
        Fluttertoast.showToast(
          msg: 'Observación guardada localmente',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
        );
      }
      
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error al guardar: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (_hasUnsavedChanges()) {
          bool shouldExit = await _showExitConfirmation();
          if (shouldExit) {
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
        title: Text(widget.observacionParaEditar != null 
            ? 'Editar Observación' 
            : 'Observaciones Adicionales'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (_hasUnsavedChanges()) {
              bool shouldExit = await _showExitConfirmation();
              if (shouldExit) {
                Navigator.of(context).pop();
              }
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ObservacionesAdicionalesRecordsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Ver registros',
          ),
        ],
      ),
      body: _isLoadingDropdownData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del usuario
                  _buildUserInfo(),
                  const SizedBox(height: 24),
                  
                  // Formulario principal
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Información de la Observación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[700],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Dropdowns de finca, bloque y variedad
                          _buildFincaDropdown(),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Expanded(child: _buildBloqueDropdown()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildVariedadDropdown()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Tipo de observación
                          Text(
                            'Tipo de Observación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTipoSelection(),
                          const SizedBox(height: 20),
                          
                          // Campos específicos para MIPE
                          if (_tipo == 'MIPE') ...[
                            _buildMIPEFields(),
                            const SizedBox(height: 20),
                          ],
                          
                          // Campo de observación
                          Text(
                            'Observación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _obsController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              hintText: 'Describe la observación...',
                              prefixIcon: Icon(Icons.note_add, color: Colors.teal[700]),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Sección de imágenes
                          _buildImagenesSection(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: _saving 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving 
                            ? 'Guardando...' 
                            : (widget.observacionParaEditar != null 
                                ? 'Actualizar Observación' 
                                : 'Guardar Observación'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ),
    );
  }

  Widget _buildUserInfo() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AuthService.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person, color: Colors.teal[700]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuario',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user['nombre'] ?? user['username'] ?? 'Usuario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
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
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFincaDropdown() {
    return DropdownButtonFormField<Finca>(
      decoration: InputDecoration(
        labelText: 'Finca',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.location_on, color: Colors.teal[700]),
      ),
      value: selectedFinca,
      onChanged: (Finca? newValue) {
        setState(() {
          selectedFinca = newValue;
          // Resetear bloque y variedad cuando cambia la finca
          selectedBloque = null;
          selectedVariedad = null;
          bloques = [];
          variedades = [];
        });
        if (newValue != null) {
          _loadBloquesForFinca(newValue.nombre);
        }
      },
      items: fincas.map<DropdownMenuItem<Finca>>((Finca finca) {
        return DropdownMenuItem<Finca>(
          value: finca,
          child: Text(finca.nombre),
        );
      }).toList(),
      hint: const Text('Seleccione una finca'),
    );
  }

  Widget _buildBloqueDropdown() {
    return DropdownButtonFormField<Bloque>(
      decoration: InputDecoration(
        labelText: 'Bloque',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.view_module, color: Colors.teal[700]),
      ),
      value: selectedBloque,
      onChanged: selectedFinca != null ? (Bloque? newValue) {
        setState(() {
          selectedBloque = newValue;
          // Resetear variedad cuando cambia el bloque
          selectedVariedad = null;
          variedades = [];
        });
        if (newValue != null && selectedFinca != null) {
          _loadVariedadesForFincaAndBloque(selectedFinca!.nombre, newValue.nombre);
        }
      } : null,
      items: bloques.map<DropdownMenuItem<Bloque>>((Bloque bloque) {
        return DropdownMenuItem<Bloque>(
          value: bloque,
          child: Text(bloque.nombre),
        );
      }).toList(),
      hint: const Text('Seleccione'),
    );
  }

  Widget _buildVariedadDropdown() {
    return DropdownButtonFormField<Variedad>(
      decoration: InputDecoration(
        labelText: 'Variedad',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.eco, color: Colors.teal[700]),
      ),
      value: selectedVariedad,
      onChanged: selectedBloque != null ? (Variedad? newValue) {
        setState(() {
          selectedVariedad = newValue;
        });
      } : null,
      items: variedades.map<DropdownMenuItem<Variedad>>((Variedad variedad) {
        return DropdownMenuItem<Variedad>(
          value: variedad,
          child: Text(variedad.nombre),
        );
      }).toList(),
      hint: const Text('Seleccione'),
    );
  }

  Widget _buildTipoSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildRadioOption('MIPE', 'MIPE'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRadioOption('CULTIVO', 'CULTIVO'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRadioOption('MIRFE', 'MIRFE'),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String value, String label) {
    return InkWell(
      onTap: () => setState(() => _tipo = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: _tipo == value ? Colors.teal[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _tipo == value ? Colors.teal[700]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Radio<String>(
              value: value,
              groupValue: _tipo,
              onChanged: (v) => setState(() => _tipo = v ?? 'MIPE'),
              activeColor: Colors.teal[700],
            ),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _tipo == value ? Colors.teal[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagenesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imágenes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                if (_imagenes.isNotEmpty)
                  Text(
                    '${_imagenes.length} imagen${_imagenes.length == 1 ? '' : 'es'} agregada${_imagenes.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _pickImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_imagenes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No hay imágenes agregadas',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca "Agregar" para seleccionar desde galería o tomar foto',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagenes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final b64 = _imagenes[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _b64ToBytes(b64),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 16),
                              onPressed: () {
                                setState(() {
                                  _imagenes.removeAt(index);
                                });
                              },
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Puedes agregar más imágenes tocando "Agregar"',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMIPEFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Información MIPE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        
        // Campo Blanco Biológico
        TextField(
          controller: _blancoBiologicoController,
          decoration: InputDecoration(
            labelText: 'Blanco Biológico',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: Icon(Icons.bug_report_outlined, color: Colors.teal[700]),
            hintText: 'Ej: Trips, Mosca blanca, etc.',
          ),
        ),
        const SizedBox(height: 16),
        
        // Incidencia y Severidad como radios (uno por fila)
        _buildNivelRadios(
          titulo: 'Incidencia',
          nivel: _incidenciaNivel,
          onChange: (v) => setState(() => _incidenciaNivel = v),
        ),
        const SizedBox(height: 16),
        _buildNivelRadios(
          titulo: 'Severidad',
          nivel: _severidadNivel,
          onChange: (v) => setState(() => _severidadNivel = v),
        ),
        const SizedBox(height: 16),
        
        // Radio buttons para Tercio
        Text(
          'Tercio:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTercioRadioOption('Bajo', 'Bajo'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTercioRadioOption('Medio', 'Medio'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTercioRadioOption('Alto', 'Alto'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTercioRadioOption(String value, String label) {
    return InkWell(
      onTap: () => setState(() => _tercio = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: _tercio == value ? Colors.teal[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _tercio == value ? Colors.teal[700]! : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Radio<String>(
              value: value,
              groupValue: _tercio,
              onChanged: (v) => setState(() => _tercio = v ?? 'Alto'),
              activeColor: Colors.teal[700],
            ),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _tercio == value ? Colors.teal[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


