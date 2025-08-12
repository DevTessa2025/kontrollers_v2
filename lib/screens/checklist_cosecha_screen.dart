import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../data/checklist_data_cosecha.dart';
import '../models/dropdown_models.dart';
import '../services/cosecha_dropdown_service.dart';
import '../services/image_service.dart';
import '../services/checklist_cosecha_storage_service.dart';
import 'checklist_cosecha_records_screen.dart';
import 'image_editor_screen.dart';

class ChecklistCosechaScreen extends StatefulWidget {
  final ChecklistCosecha? checklistToEdit;
  final int? recordId;

  ChecklistCosechaScreen({
    this.checklistToEdit,
    this.recordId,
  });

  @override
  _ChecklistCosechaScreenState createState() => _ChecklistCosechaScreenState();
}

class _ChecklistCosechaScreenState extends State<ChecklistCosechaScreen> {
  late ChecklistCosecha checklist;
  int _currentSectionIndex = 0;
  
  // Datos para los dropdowns
  List<Finca> fincas = [];
  List<Bloque> bloques = [];
  List<Variedad> variedades = [];
  
  // Valores seleccionados
  Finca? selectedFinca;
  Bloque? selectedBloque;
  Variedad? selectedVariedad;
  DateTime selectedDate = DateTime.now();
  
  bool _isLoadingDropdownData = true;
  bool _isLoadingBloques = false;
  bool _isLoadingVariedades = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _isEditMode = widget.checklistToEdit != null;
    
    if (_isEditMode) {
      _loadExistingChecklist();
    } else {
      _resetChecklist();
    }
    
    _loadDropdownData();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('es_ES', null);
  }

  void _loadExistingChecklist() {
    checklist = widget.checklistToEdit!;
    selectedFinca = checklist.finca;
    selectedBloque = checklist.bloque;
    selectedVariedad = checklist.variedad;
    selectedDate = checklist.fecha ?? DateTime.now();
    _currentSectionIndex = 0;
  }
  
  void _resetChecklist() {
    checklist = ChecklistDataCosecha.getChecklistCosecha();
    selectedDate = DateTime.now();
    _currentSectionIndex = 0;
  }

  Future<void> _loadDropdownData({bool forceSync = false}) async {
    setState(() {
      _isLoadingDropdownData = true;
    });

    try {
      Map<String, dynamic> dropdownData = await CosechaDropdownService.getCosechaDropdownData(forceSync: forceSync);
      
      setState(() {
        fincas = dropdownData['fincas'] ?? [];
        _isLoadingDropdownData = false;
      });

      // Si estamos editando, cargar bloques y variedades
      if (_isEditMode && selectedFinca != null) {
        await _loadBloquesForFinca(selectedFinca!.nombre);
        if (selectedBloque != null) {
          await _loadVariedadesForFincaAndBloque(selectedFinca!.nombre, selectedBloque!.nombre);
        }
      }

      if (fincas.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No se pudieron cargar las fincas. Verifique la conexión.',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingDropdownData = false;
      });
      
      Fluttertoast.showToast(
        msg: 'Error cargando datos: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _loadBloquesForFinca(String finca) async {
    setState(() {
      _isLoadingBloques = true;
      selectedBloque = null;
      selectedVariedad = null;
      bloques = [];
      variedades = [];
    });

    try {
      List<Bloque> loadedBloques = await CosechaDropdownService.getBloquesByFinca(finca);
      
      setState(() {
        bloques = loadedBloques;
        _isLoadingBloques = false;
      });

      if (bloques.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No se encontraron bloques para la finca $finca',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingBloques = false;
      });
      
      Fluttertoast.showToast(
        msg: 'Error cargando bloques: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  Future<void> _loadVariedadesForFincaAndBloque(String finca, String bloque) async {
    setState(() {
      _isLoadingVariedades = true;
      selectedVariedad = null;
      variedades = [];
    });

    try {
      List<Variedad> loadedVariedades = await CosechaDropdownService.getVariedadesByFincaAndBloque(finca, bloque);
      
      setState(() {
        variedades = loadedVariedades;
        _isLoadingVariedades = false;
      });

      if (variedades.isEmpty) {
        Fluttertoast.showToast(
          msg: 'No se encontraron variedades para finca $finca, bloque $bloque',
          backgroundColor: Colors.orange[600],
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingVariedades = false;
      });
      
      Fluttertoast.showToast(
        msg: 'Error cargando variedades: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  void _updateItemResponse(int itemId, String respuesta, {double? valorNumerico}) {
    setState(() {
      for (var seccion in checklist.secciones) {
        for (var item in seccion.items) {
          if (item.id == itemId) {
            item.respuesta = respuesta;
            item.valorNumerico = valorNumerico;
            break;
          }
        }
      }
    });
  }

  void _showValueSelector(ChecklistCosechaItem item) {
    if (!item.valores.tieneOpcionesMultiples()) {
      _updateItemResponse(item.id, 'si', valorNumerico: item.valores.max);
      return;
    }

    List<double> opciones = item.valores.getOpcionesSi();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Seleccionar Valor',
            style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: 400,
              maxWidth: 350,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(maxHeight: 80),
                  margin: EdgeInsets.only(bottom: 16),
                  child: Text(
                    item.proceso,
                    style: TextStyle(
                      fontSize: 14, 
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: opciones.map((valor) => Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 12),
                        child: ElevatedButton(
                          onPressed: () {
                            _updateItemResponse(item.id, 'si', valorNumerico: valor);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            valor == item.valores.max 
                                ? '$valor (Excelente)' 
                                : '$valor (Satisfactorio)',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        );
      },
    );
  }

  void _showObservationsDialog(ChecklistCosechaItem item) {
    TextEditingController observationsController = TextEditingController();
    observationsController.text = item.observaciones ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Observaciones',
            style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: 300,
              maxWidth: 400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxHeight: 60),
                  child: Text(
                    item.proceso,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: 120,
                  child: TextField(
                    controller: observationsController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Agregar observaciones...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.green[700]!),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  item.observaciones = observationsController.text.trim().isEmpty 
                      ? null 
                      : observationsController.text.trim();
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _deletePhoto(ChecklistCosechaItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar Foto',
          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxWidth: 300,
          ),
          child: Text(
            '¿Está seguro que desea eliminar esta foto?',
            style: TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                item.fotoBase64 = null;
              });
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: 'Foto eliminada',
                backgroundColor: Colors.orange[600],
                textColor: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPhoto(ChecklistCosechaItem item) async {
    if (item.fotoBase64 == null) return;

    try {
      final editedImage = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageEditorScreen(
            base64Image: item.fotoBase64!,
            imagePath: null,
          ),
        ),
      );

      if (editedImage != null) {
        setState(() {
          item.fotoBase64 = editedImage;
        });

        Map<String, dynamic> imageInfo = ImageService.getImageInfo(editedImage);
        
        Fluttertoast.showToast(
          msg: 'Foto editada (${imageInfo['sizeKB'].toStringAsFixed(1)} KB)',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error abriendo editor: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  void _showPhotoDialog(ChecklistCosechaItem item) async {
    ImageSource? source = await ImageService.showImageSourceDialog(context);
    
    if (source != null) {
      String? base64Image = await ImageService.pickAndCompressImage(source: source);

      if (base64Image != null) {
        bool? shouldEdit = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Editar Imagen',
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: 300,
                  maxWidth: 400,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          ImageService.base64ToBytes(base64Image),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.error,
                                color: Colors.grey[500],
                                size: 50,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Flexible(
                      child: Text(
                        '¿Desea editar esta imagen?\nPodrá dibujar y agregar anotaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Usar como está'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Editar'),
                ),
              ],
            );
          },
        );
        
        String finalImage = base64Image;
        
        if (shouldEdit == true) {
          try {
            final editedImage = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (context) => ImageEditorScreen(
                  base64Image: base64Image,
                  imagePath: null,
                ),
              ),
            );
            
            if (editedImage != null) {
              finalImage = editedImage;
            }
          } catch (e) {
            print('Editor no disponible: $e');
            Fluttertoast.showToast(
              msg: 'Editor no disponible, usando imagen original',
              backgroundColor: Colors.orange[600],
              textColor: Colors.white,
            );
          }
        }

        setState(() {
          item.fotoBase64 = finalImage;
        });
        
        Map<String, dynamic> imageInfo = ImageService.getImageInfo(finalImage);
        
        Fluttertoast.showToast(
          msg: 'Foto agregada (${imageInfo['sizeKB'].toStringAsFixed(1)} KB, ${imageInfo['resolution']})',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  void _showPhotoOptionsDialog(ChecklistCosechaItem item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Opciones de Foto',
          style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: 300,
            maxWidth: 350,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionTile(
                icon: Icons.visibility,
                color: Colors.blue[700]!,
                title: 'Ver Foto',
                subtitle: 'Visualizar imagen actual',
                onTap: () {
                  Navigator.pop(context);
                  _viewPhoto(item);
                },
              ),
              _buildOptionTile(
                icon: Icons.edit,
                color: Colors.green[700]!,
                title: 'Editar Foto',
                subtitle: 'Dibujar y agregar anotaciones',
                onTap: () async {
                  Navigator.pop(context);
                  await _editPhoto(item);
                },
              ),
              _buildOptionTile(
                icon: Icons.camera_alt,
                color: Colors.orange[700]!,
                title: 'Tomar Nueva Foto',
                subtitle: 'Reemplazar con nueva imagen',
                onTap: () {
                  Navigator.pop(context);
                  _showPhotoDialog(item);
                },
              ),
              _buildOptionTile(
                icon: Icons.delete,
                color: Colors.red[700]!,
                title: 'Eliminar Foto',
                subtitle: 'Remover imagen actual',
                onTap: () {
                  Navigator.pop(context);
                  _deletePhoto(item);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: Colors.grey[50],
      ),
    );
  }

  void _viewPhoto(ChecklistCosechaItem item) {
    if (item.fotoBase64 == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Foto - Item ${item.id}'),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _editPhoto(item);
                  },
                  tooltip: 'Editar foto',
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    Navigator.pop(context);
                    _deletePhoto(item);
                  },
                  tooltip: 'Eliminar foto',
                ),
              ],
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: ImageService.displayBase64Image(item.fotoBase64!),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                item.proceso,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _isEditMode ? Colors.blue[700]! : Colors.green[700]!,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  void _saveLocalChecklist() async {
    // Validar que los datos básicos estén completos
    if (selectedFinca == null || selectedBloque == null || selectedVariedad == null) {
      Fluttertoast.showToast(
        msg: 'Por favor complete todos los datos: Finca, Bloque, Variedad y Fecha',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    // Validar que la fecha no sea futura
    DateTime today = DateTime.now();
    DateTime todayOnly = DateTime(today.year, today.month, today.day);
    DateTime selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    
    if (selectedDateOnly.isAfter(todayOnly)) {
      bool? continueWithFutureDate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Fecha Futura',
            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Ha seleccionado una fecha futura (${DateFormat('dd/MM/yyyy').format(selectedDate)}). ¿Está seguro que desea continuar?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Continuar'),
            ),
          ],
        ),
      );

      if (continueWithFutureDate != true) {
        return;
      }
    }

    try {
      checklist.finca = selectedFinca;
      checklist.bloque = selectedBloque;
      checklist.variedad = selectedVariedad;
      checklist.fecha = selectedDate;

      int recordId;
      
      if (_isEditMode && widget.recordId != null) {
        await ChecklistCosechaStorageService.updateChecklistLocal(widget.recordId!, checklist);
        recordId = widget.recordId!;
        
        Fluttertoast.showToast(
          msg: 'Checklist cosecha actualizado localmente (ID: $recordId)',
          backgroundColor: Colors.blue[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      } else {
        recordId = await ChecklistCosechaStorageService.saveChecklistLocal(checklist);
        
        Fluttertoast.showToast(
          msg: 'Checklist cosecha guardado localmente (ID: $recordId)',
          backgroundColor: Colors.green[600],
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChecklistCosechaRecordsScreen()),
      );

    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error guardando checklist cosecha: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  void _navigateToRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChecklistCosechaRecordsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    var currentSection = checklist.secciones[_currentSectionIndex];
    int itemsRespondidosSeccionActual = currentSection.items.where((item) => item.respuesta != null).length;
    int totalItemsSeccionActual = currentSection.items.length;

    // Calcular progreso general
    int totalItemsGeneral = 0;
    int itemsRespondidosGeneral = 0;
    for (var seccion in checklist.secciones) {
      totalItemsGeneral += seccion.items.length;
      itemsRespondidosGeneral += seccion.items.where((item) => item.respuesta != null).length;
    }

    double progressPercentage = totalItemsGeneral > 0 ? itemsRespondidosGeneral / totalItemsGeneral : 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // AppBar moderno con gradiente verde para cosecha
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: _isEditMode ? Colors.blue[700] : Colors.green[700],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isEditMode 
                        ? [Colors.blue[800]!, Colors.blue[600]!, Colors.blue[700]!]
                        : [Colors.green[800]!, Colors.green[600]!, Colors.green[700]!],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 70, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _isEditMode ? Icons.edit_note : Icons.grass,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isEditMode ? 'Editando Cosecha' : 'Nueva Cosecha',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_isEditMode) ...[
                                      SizedBox(height: 2),
                                      Text(
                                        'ID: ${widget.recordId}',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        // Barra de progreso
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Progreso General',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '$itemsRespondidosGeneral/$totalItemsGeneral',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressPercentage,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '${(progressPercentage * 100).toInt()}%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
            ),
            actions: [
              if (!_isEditMode) ...[
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.sync, color: Colors.white, size: 20),
                  ),
                  onPressed: () => _loadDropdownData(forceSync: true),
                  tooltip: 'Sincronizar datos',
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.folder_open, color: Colors.white, size: 20),
                  ),
                  onPressed: _navigateToRecords,
                  tooltip: 'Ver registros',
                ),
              ],
              IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.save, color: Colors.white, size: 20),
                ),
                onPressed: _saveLocalChecklist,
                tooltip: _isEditMode ? 'Actualizar' : 'Guardar localmente',
              ),
              SizedBox(width: 8),
            ],
          ),

          // Contenido principal
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Formulario principal con diseño para cosecha
                Container(
                  margin: EdgeInsets.all(16),
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
                      // Header del formulario
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (_isEditMode ? Colors.blue[50] : Colors.green[50]),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isEditMode ? Colors.blue[100] : Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.grass_outlined,
                                color: _isEditMode ? Colors.blue[700] : Colors.green[700],
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Información del Checklist Cosecha',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    'Complete todos los campos requeridos',
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

                      // Contenido del formulario
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: _isLoadingDropdownData
                            ? Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: _isEditMode ? Colors.blue[700] : Colors.green[700],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Cargando datos...',
                                      style: TextStyle(
                                        color: _isEditMode ? Colors.blue[700] : Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Dropdown de Finca
                                  _buildModernDropdown<Finca>(
                                    label: 'Finca',
                                    icon: Icons.location_on,
                                    value: selectedFinca,
                                    items: fincas,
                                    itemBuilder: (finca) => finca.nombre,
                                    onChanged: (Finca? newValue) {
                                      setState(() {
                                        selectedFinca = newValue;
                                        selectedBloque = null;
                                        selectedVariedad = null;
                                        bloques = [];
                                        variedades = [];
                                      });
                                      if (newValue != null) {
                                        _loadBloquesForFinca(newValue.nombre);
                                      }
                                    },
                                    hint: 'Seleccione una finca',
                                  ),

                                  SizedBox(height: 16),

                                  // Dropdown de Bloque
                                  _buildModernDropdown<Bloque>(
                                    label: 'Bloque',
                                    icon: Icons.view_module,
                                    value: selectedBloque,
                                    items: bloques,
                                    itemBuilder: (bloque) => bloque.nombre,
                                    onChanged: (Bloque? newValue) {
                                      setState(() {
                                        selectedBloque = newValue;
                                        selectedVariedad = null;
                                        variedades = [];
                                      });
                                      if (newValue != null && selectedFinca != null) {
                                        _loadVariedadesForFincaAndBloque(selectedFinca!.nombre, newValue.nombre);
                                      }
                                    },
                                    hint: 'Seleccione un bloque',
                                    isLoading: _isLoadingBloques,
                                    isEnabled: selectedFinca != null,
                                  ),

                                  SizedBox(height: 16),

                                  // Dropdown de Variedad
                                  _buildModernDropdown<Variedad>(
                                    label: 'Variedad',
                                    icon: Icons.eco,
                                    value: selectedVariedad,
                                    items: variedades,
                                    itemBuilder: (variedad) => variedad.nombre,
                                    onChanged: (Variedad? newValue) {
                                      setState(() {
                                        selectedVariedad = newValue;
                                      });
                                    },
                                    hint: 'Seleccione una variedad',
                                    isLoading: _isLoadingVariedades,
                                    isEnabled: selectedBloque != null,
                                  ),

                                  SizedBox(height: 16),

                                  // Campo de fecha moderno
                                  _buildModernDateField(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // Navegación de secciones mejorada con tema verde
                Container(
                  height: 90,
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    itemCount: checklist.secciones.length,
                    itemBuilder: (context, index) {
                      bool isSelected = index == _currentSectionIndex;
                      var seccion = checklist.secciones[index];
                      
                      int itemsRespondidos = seccion.items.where((item) => item.respuesta != null).length;
                      int totalItems = seccion.items.length;
                      double sectionProgress = totalItems > 0 ? itemsRespondidos / totalItems : 0;
                      
                      Color sectionColor = _isEditMode ? Colors.blue[700]! : Colors.green[700]!;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentSectionIndex = index;
                          });
                        },
                        child: Container(
                          width: 180,
                          margin: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? sectionColor : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? sectionColor : Colors.grey[300]!,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: sectionColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ] : [],
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    seccion.nombre,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : sectionColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                      height: 1.1,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Colors.white.withOpacity(0.2)
                                        : sectionColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$itemsRespondidos/$totalItems',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : sectionColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: sectionProgress,
                                    backgroundColor: isSelected 
                                        ? Colors.white.withOpacity(0.3)
                                        : Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isSelected ? Colors.white : sectionColor,
                                    ),
                                    minHeight: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),

          // Lista de items con diseño mejorado
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  var item = currentSection.items[index];
                  return _buildModernItemCard(item);
                },
                childCount: currentSection.items.length,
              ),
            ),
          ),

          // Espaciado final
          SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  // Widget para dropdowns modernos
  Widget _buildModernDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required void Function(T?) onChanged,
    required String hint,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isEnabled ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: (_isEditMode ? Colors.blue[700] : Colors.green[700])?.withOpacity(isEnabled ? 1.0 : 0.5),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_isEditMode ? Colors.blue[700] : Colors.green[700])?.withOpacity(isEnabled ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isLoading 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: (_isEditMode ? Colors.blue[700] : Colors.green[700])?.withOpacity(isEnabled ? 1.0 : 0.5),
                    ),
                  )
                : Icon(
                    icon,
                    color: (_isEditMode ? Colors.blue[700] : Colors.green[700])?.withOpacity(isEnabled ? 1.0 : 0.5),
                    size: 20,
                  ),
          ),
        ),
        items: isEnabled ? items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              itemBuilder(item),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList() : [],
        onChanged: isEnabled && !isLoading ? onChanged : null,
        hint: Text(
          isLoading ? 'Cargando...' : hint,
          style: TextStyle(color: Colors.grey[500]),
        ),
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: Container(
          margin: EdgeInsets.only(right: 8),
          child: Icon(
            Icons.keyboard_arrow_down,
            color: (_isEditMode ? Colors.blue[700] : Colors.green[700])?.withOpacity(isEnabled ? 1.0 : 0.5),
          ),
        ),
      ),
    );
  }

  // Widget para el campo de fecha moderno
  Widget _buildModernDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_isEditMode ? Colors.blue[700] : Colors.green[700])?.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today,
                color: _isEditMode ? Colors.blue[700] : Colors.green[700],
                size: 20,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha del Checklist',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isEditMode ? Colors.blue[700] : Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_calendar,
                color: Colors.grey[600],
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para las tarjetas de items modernos
  Widget _buildModernItemCard(ChecklistCosechaItem item) {
    Color primaryColor = _isEditMode ? Colors.blue[700]! : Colors.green[700]!;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.respuesta != null 
              ? primaryColor.withOpacity(0.3)
              : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del item
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.respuesta != null 
                  ? primaryColor.withOpacity(0.05)
                  : Colors.grey[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.respuesta != null ? primaryColor : Colors.grey[400],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      item.id.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.proceso,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (item.valores.tieneOpcionesMultiples()) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Valores: ${item.valores.getOpcionesSi().join(', ')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.comment_outlined,
                      isActive: item.observaciones != null,
                      onTap: () => _showObservationsDialog(item),
                      activeColor: Colors.orange[600]!,
                    ),
                    SizedBox(width: 8),
                    _buildActionButton(
                      icon: item.fotoBase64 != null ? Icons.photo : Icons.photo_camera_outlined,
                      isActive: item.fotoBase64 != null,
                      onTap: () {
                        if (item.fotoBase64 != null) {
                          _showPhotoOptionsDialog(item);
                        } else {
                          _showPhotoDialog(item);
                        }
                      },
                      activeColor: Colors.blue[600]!,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Botones de respuesta
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildResponseButton(
                        label: 'SÍ',
                        isSelected: item.respuesta == 'si',
                        color: Colors.green[600]!,
                        onPressed: () => _showValueSelector(item),
                        subtitle: item.respuesta == 'si' && item.valorNumerico != null
                            ? '(${item.valorNumerico})'
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildResponseButton(
                        label: 'NO',
                        isSelected: item.respuesta == 'no',
                        color: Colors.red[600]!,
                        onPressed: item.valores.min != null 
                            ? () => _updateItemResponse(item.id, 'no', valorNumerico: item.valores.min)
                            : () => _updateItemResponse(item.id, 'no', valorNumerico: 0),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildResponseButton(
                        label: 'N/A',
                        isSelected: item.respuesta == 'na',
                        color: Colors.orange[600]!,
                        onPressed: () => _updateItemResponse(item.id, 'na'),
                      ),
                    ),
                  ],
                ),

                // Mostrar observaciones y foto si existen
                if (item.observaciones != null || item.fotoBase64 != null) ...[
                  SizedBox(height: 16),
                  
                  if (item.observaciones != null)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.comment, color: Colors.orange[600], size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.observaciones!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (item.fotoBase64 != null)
                    GestureDetector(
                      onTap: () => _viewPhoto(item),
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Image.memory(
                                ImageService.base64ToBytes(item.fotoBase64!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red),
                                        Text(
                                          'Error cargando imagen',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para botones de acción
  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.3) : Colors.grey[300]!,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.grey[500],
          size: 20,
        ),
      ),
    );
  }

  // Widget para botones de respuesta
  Widget _buildResponseButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback? onPressed,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? Colors.white70 : Colors.grey[500],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}