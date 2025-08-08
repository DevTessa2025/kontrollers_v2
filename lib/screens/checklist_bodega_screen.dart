import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import '../data/checklist_data.dart';
import '../models/dropdown_models.dart';
import '../services/dropdown_service.dart';
import '../services/image_service.dart';
import '../services/checklist_storage_service.dart';
import 'checklist_records_screen.dart';

class ChecklistBodegaScreen extends StatefulWidget {
  @override
  _ChecklistBodegaScreenState createState() => _ChecklistBodegaScreenState();
}

class _ChecklistBodegaScreenState extends State<ChecklistBodegaScreen> {
  late ChecklistBodega checklist;
  int _currentSectionIndex = 0;
  
  // Datos para los dropdowns
  List<Finca> fincas = [];
  List<Supervisor> supervisores = [];
  List<Pesador> pesadores = [];
  
  // Valores seleccionados
  Finca? selectedFinca;
  Supervisor? selectedSupervisor;
  Pesador? selectedPesador;
  
  bool _isLoadingDropdownData = true;

  @override
  void initState() {
    super.initState();
    _resetChecklist();
    _loadDropdownData();
  }
  
  void _resetChecklist() {
    checklist = ChecklistDataBodega.getChecklistBodega();
    _currentSectionIndex = 0;
  }

  // Se corrige para aceptar el parámetro opcional forceSync
  Future<void> _loadDropdownData({bool forceSync = false}) async {
    setState(() {
      _isLoadingDropdownData = true;
    });

    try {
      Map<String, dynamic> dropdownData = await DropdownService.getChecklistDropdownData(forceSync: forceSync);
      
      setState(() {
        fincas = dropdownData['fincas'] ?? [];
        supervisores = dropdownData['supervisores'] ?? [];
        pesadores = dropdownData['pesadores'] ?? [];
        _isLoadingDropdownData = false;
      });

      if (fincas.isEmpty || supervisores.isEmpty || pesadores.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Algunos datos no se pudieron cargar. Verifique la conexión.',
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

  void _showValueSelector(ChecklistItem item) {
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
            style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.proceso,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              ...opciones.map((valor) => Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: () {
                    _updateItemResponse(item.id, 'si', valorNumerico: valor);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    valor == item.valores.max 
                        ? '$valor (Excelente)' 
                        : '$valor (Satisfactorio)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              )).toList(),
            ],
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

  void _showObservationsDialog(ChecklistItem item) {
    TextEditingController observationsController = TextEditingController();
    observationsController.text = item.observaciones ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Observaciones',
            style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.proceso,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              TextField(
                controller: observationsController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Agregar observaciones...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red[700]!),
                  ),
                ),
              ),
            ],
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
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // Actualizar este método en checklist_bodega_screen.dart

void _showPhotoDialog(ChecklistItem item) async {
  // Usar el nuevo diálogo que devuelve un Map con source y highQuality
  Map<String, dynamic>? result = await ImageService.showImageSourceDialog(context);
  
  if (result != null) {
    ImageSource source = result['source'];
    bool highQuality = result['highQuality'] ?? false;
    
    String? base64Image;
    
    if (highQuality) {
      // Usar configuración de alta calidad
      base64Image = await ImageService.pickHighQualityImage(source: source);
    } else {
      // Usar configuración estándar (ya mejorada)
      base64Image = await ImageService.pickAndCompressImage(source: source);
    }

    if (base64Image != null) {
      setState(() {
        item.fotoBase64 = base64Image;
      });
      
      // Mostrar información de la imagen
      Map<String, dynamic> imageInfo = ImageService.getImageInfo(base64Image);
      
      String message = highQuality 
          ? 'Foto HD agregada (${imageInfo['sizeKB'].toStringAsFixed(1)} KB, ${imageInfo['resolution']})'
          : 'Foto agregada (${imageInfo['sizeKB'].toStringAsFixed(1)} KB, ${imageInfo['resolution']})';
      
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }
}

  void _viewPhoto(ChecklistItem item) {
    if (item.fotoBase64 == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Foto - Item ${item.id}'),
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.delete),
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
                ),
              ],
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Image.memory(
                ImageService.base64ToBytes(item.fotoBase64!),
                fit: BoxFit.contain,
              ),
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

  void _saveLocalChecklist() async {
    // Validar que los datos básicos estén completos
    if (selectedFinca == null || selectedSupervisor == null || selectedPesador == null) {
      Fluttertoast.showToast(
        msg: 'Por favor complete todos los datos: Finca, Supervisor y Pesador',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }
    
    // Nueva validación: Asegurar que todos los ítems tengan una respuesta
    for (var seccion in checklist.secciones) {
      for (var item in seccion.items) {
        if (item.respuesta == null) {
          Fluttertoast.showToast(
            msg: 'Por favor, complete todos los ítems antes de guardar',
            backgroundColor: Colors.orange[600],
            textColor: Colors.white,
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }
      }
    }

    try {
      checklist.finca = selectedFinca;
      checklist.supervisor = selectedSupervisor;
      checklist.pesador = selectedPesador;
      checklist.fecha = DateTime.now();

      int recordId = await ChecklistStorageService.saveChecklistLocal(checklist);
      
      Fluttertoast.showToast(
        msg: 'Checklist guardado localmente (ID: $recordId)',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );

      setState(() {
        selectedFinca = null;
        selectedSupervisor = null;
        selectedPesador = null;
        checklist = ChecklistDataBodega.getChecklistBodega();
        _currentSectionIndex = 0;
      });

    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error guardando checklist: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  void _navigateToRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChecklistRecordsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    var currentSection = checklist.secciones[_currentSectionIndex];
    int itemsRespondidosSeccionActual = currentSection.items.where((item) => item.respuesta != null).length;
    int totalItemsSeccionActual = currentSection.items.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Checklist Bodega',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () => _loadDropdownData(forceSync: true),
            tooltip: 'Sincronizar datos',
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveLocalChecklist,
            tooltip: 'Guardar localmente',
          ),
          IconButton(
            icon: Icon(Icons.folder_open),
            onPressed: _navigateToRecords,
            tooltip: 'Ver registros',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con información general
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border(bottom: BorderSide(color: Colors.red[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingDropdownData)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red[700],
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Cargando datos...',
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      // Dropdown de Finca (ancho completo)
                      DropdownButtonFormField<Finca>(
                        value: selectedFinca,
                        decoration: InputDecoration(
                          labelText: 'Finca',
                          labelStyle: TextStyle(color: Colors.red[700]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.red[700]!),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixIcon: Icon(Icons.location_on, color: Colors.red[700]),
                        ),
                        items: fincas.map((Finca finca) {
                          return DropdownMenuItem<Finca>(
                            value: finca,
                            child: Text(
                              finca.nombre,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (Finca? newValue) {
                          setState(() {
                            selectedFinca = newValue;
                          });
                        },
                        hint: Text('Seleccione una finca'),
                        isExpanded: true,
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Row con Supervisor y Pesador
                      Row(
                        children: [
                          // Dropdown de Supervisor
                          Expanded(
                            child: DropdownButtonFormField<Supervisor>(
                              value: selectedSupervisor,
                              decoration: InputDecoration(
                                labelText: 'Supervisor',
                                labelStyle: TextStyle(color: Colors.red[700]),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.red[700]!),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                prefixIcon: Icon(Icons.supervisor_account, color: Colors.red[700]),
                              ),
                              items: supervisores.map((Supervisor supervisor) {
                                return DropdownMenuItem<Supervisor>(
                                  value: supervisor,
                                  child: Text(
                                    supervisor.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (Supervisor? newValue) {
                                setState(() {
                                  selectedSupervisor = newValue;
                                });
                              },
                              hint: Text('Supervisor'),
                              isExpanded: true,
                            ),
                          ),
                          
                          SizedBox(width: 12),
                          
                          // Dropdown de Pesador
                          Expanded(
                            child: DropdownButtonFormField<Pesador>(
                              value: selectedPesador,
                              decoration: InputDecoration(
                                labelText: 'Pesador',
                                labelStyle: TextStyle(color: Colors.red[700]),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.red[700]!),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                prefixIcon: Icon(Icons.scale, color: Colors.red[700]),
                              ),
                              items: pesadores.map((Pesador pesador) {
                                return DropdownMenuItem<Pesador>(
                                  value: pesador,
                                  child: Text(
                                    pesador.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (Pesador? newValue) {
                                setState(() {
                                  selectedPesador = newValue;
                                });
                              },
                              hint: Text('Pesador'),
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Navegación de secciones
          Container(
            height: 60,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: checklist.secciones.length,
              itemBuilder: (context, index) {
                bool isSelected = index == _currentSectionIndex;
                var seccion = checklist.secciones[index];
                
                int itemsRespondidos = seccion.items.where((item) => item.respuesta != null).length;
                int totalItems = seccion.items.length;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentSectionIndex = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red[700] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.red[700]! : Colors.red[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          seccion.nombre,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '$itemsRespondidos/$totalItems',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.red[500],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Título de la sección actual y progreso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red[100]!.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    currentSection.nombre,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ),
                Text(
                  'Progreso: $itemsRespondidosSeccionActual/$totalItemsSeccionActual',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Lista de items de la sección actual
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: currentSection.items.length,
              itemBuilder: (context, index) {
                var item = currentSection.items[index];
                
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.respuesta == null 
                          ? Colors.grey[300]! 
                          : Colors.red[200]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header del item
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.red[700],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  item.id.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.proceso,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.comment_outlined,
                                color: item.observaciones != null 
                                    ? Colors.red[700] 
                                    : Colors.grey[400],
                              ),
                              onPressed: () => _showObservationsDialog(item),
                              tooltip: 'Observaciones',
                            ),
                            IconButton(
                              icon: Icon(
                                item.fotoBase64 != null ? Icons.photo : Icons.photo_camera_outlined,
                                color: item.fotoBase64 != null 
                                    ? Colors.blue[700] 
                                    : Colors.grey[400],
                              ),
                              onPressed: () {
                                if (item.fotoBase64 != null) {
                                  _viewPhoto(item);
                                } else {
                                  _showPhotoDialog(item);
                                }
                              },
                              tooltip: item.fotoBase64 != null ? 'Ver foto' : 'Agregar foto',
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Información de valores
                        if (item.valores.tieneOpcionesMultiples())
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              'Valores SI: ${item.valores.getOpcionesSi().join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                        if (item.valores.tieneOpcionesMultiples()) SizedBox(height: 12),

                        // Botones de respuesta
                        Row(
                          children: [
                            // Botón SI
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _showValueSelector(item),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.respuesta == 'si' 
                                      ? Colors.green[600] 
                                      : Colors.grey[200],
                                  foregroundColor: item.respuesta == 'si' 
                                      ? Colors.white 
                                      : Colors.grey[700],
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'SÍ',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (item.respuesta == 'si' && item.valorNumerico != null)
                                      Text(
                                        '(${item.valorNumerico})',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(width: 8),

                            // Botón NO
                            Expanded(
                              child: ElevatedButton(
                                onPressed: item.valores.min != null 
                                    ? () => _updateItemResponse(item.id, 'no', valorNumerico: item.valores.min)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.respuesta == 'no' 
                                      ? Colors.red[600] 
                                      : Colors.grey[200],
                                  foregroundColor: item.respuesta == 'no' 
                                      ? Colors.white 
                                      : Colors.grey[700],
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'NO',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            SizedBox(width: 8),

                            // Botón N/A
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateItemResponse(item.id, 'na'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: item.respuesta == 'na' 
                                      ? Colors.orange[600] 
                                      : Colors.grey[200],
                                  foregroundColor: item.respuesta == 'na' 
                                      ? Colors.white 
                                      : Colors.grey[700],
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'N/A',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Mostrar observaciones y foto si existen
                        if (item.observaciones != null || item.fotoBase64 != null) ...[
                          SizedBox(height: 8),
                          
                          if (item.observaciones != null)
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.yellow[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.yellow[300]!),
                              ),
                              child: Text(
                                'Obs: ${item.observaciones}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          
                          if (item.fotoBase64 != null)
                            GestureDetector(
                              onTap: () => _viewPhoto(item),
                              child: Container(
                                width: double.infinity,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    ImageService.base64ToBytes(item.fotoBase64!),
                                    fit: BoxFit.cover,
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
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      
      // Botón flotante para mostrar progreso
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: () {
      //     double cumplimiento = checklist.calcularPorcentajeCumplimiento();
      //     int totalItems = 0;
      //     int itemsCompletados = 0;
      //     int itemsConFotos = 0;
      //     int itemsConObs = 0;

      //     for (var seccion in checklist.secciones) {
      //       totalItems += seccion.items.length;
      //       itemsCompletados += seccion.items.where((item) => item.respuesta != null).length;
      //       itemsConFotos += seccion.items.where((item) => item.fotoBase64 != null).length;
      //       itemsConObs += seccion.items.where((item) => item.observaciones != null && item.observaciones!.isNotEmpty).length;
      //     }

      //     showDialog(
      //       context: context,
      //       builder: (context) => AlertDialog(
      //         title: const Text('Progreso del Checklist'),
      //         content: SingleChildScrollView(
      //           child: ListBody(
      //             children: [
      //               _buildProgressIndicator(
      //                 'Progreso General',
      //                 itemsCompletados / totalItems,
      //                 'Items completados: $itemsCompletados/$totalItems',
      //               ),
      //               const SizedBox(height: 16),
      //               _buildProgressIndicator(
      //                 'Cumplimiento',
      //                 cumplimiento / 100,
      //                 '${cumplimiento.toStringAsFixed(1)}%',
      //                 Colors.red[600],
      //               ),
      //               const SizedBox(height: 16),
      //               _buildStatsRow(itemsConFotos, itemsConObs),
      //               const SizedBox(height: 16),
      //               const Text('Progreso por Sección:', style: TextStyle(fontWeight: FontWeight.bold)),
      //               ...checklist.secciones.map((seccion) {
      //                 int seccionItemsRespondidos = seccion.items.where((item) => item.respuesta != null).length;
      //                 int seccionTotalItems = seccion.items.length;
      //                 return Padding(
      //                   padding: const EdgeInsets.only(top: 8.0),
      //                   child: Row(
      //                     children: [
      //                       Expanded(
      //                         child: Text(seccion.nombre, style: const TextStyle(fontSize: 12)),
      //                       ),
      //                       Text('$seccionItemsRespondidos/$seccionTotalItems', style: const TextStyle(fontSize: 12)),
      //                       const SizedBox(width: 8),
      //                       SizedBox(
      //                         width: 80,
      //                         child: LinearProgressIndicator(
      //                           value: seccionItemsRespondidos / seccionTotalItems,
      //                           backgroundColor: Colors.grey[300],
      //                           color: Colors.red[400],
      //                         ),
      //                       ),
      //                     ],
      //                   ),
      //                 );
      //               }).toList(),
      //             ],
      //           ),
      //         ),
      //         actions: [
      //           TextButton(
      //             onPressed: () => Navigator.pop(context),
      //             child: const Text('Cerrar'),
      //           ),
      //         ],
      //       ),
      //     );
      //   },
      //   backgroundColor: Colors.red[700],
      //   foregroundColor: Colors.white,
      //   icon: const Icon(Icons.analytics),
      //   label: const Text('Progreso'),
      // ),
    );
  }

  Widget _buildProgressIndicator(String title, double value, String label, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey[300],
          color: color ?? Colors.green[600],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int photos, int observations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard(Icons.photo_camera, 'Fotos', photos, Colors.blue[600]!),
        _buildStatCard(Icons.comment, 'Observaciones', observations, Colors.orange[600]!),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String title, int value, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value.toString(), style: TextStyle(fontSize: 16, color: color)),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}