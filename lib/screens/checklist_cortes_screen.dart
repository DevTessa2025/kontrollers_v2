import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../data/checklist_data_cortes.dart';
import '../models/dropdown_models.dart';
import '../services/cosecha_dropdown_service.dart';
import '../services/checklist_cortes_storage_service.dart';
import 'checklist_cortes_records_screen.dart';

class ChecklistCortesScreen extends StatefulWidget {
  final ChecklistCortes? checklistToEdit;
  final int? recordId;

  ChecklistCortesScreen({
    this.checklistToEdit,
    this.recordId,
  });

  @override
  _ChecklistCortesScreenState createState() => _ChecklistCortesScreenState();
}

class _ChecklistCortesScreenState extends State<ChecklistCortesScreen> with WidgetsBindingObserver {
  late ChecklistCortes checklist;
  
  // Datos para los dropdowns
  List<Finca> fincas = [];
  List<Bloque> bloques = [];
  List<Variedad> variedades = [];
  
  // Valores seleccionados
  Finca? selectedFinca;
  DateTime selectedDate = DateTime.now();
  
  // Estructura: supervisor -> cuadrante -> {bloque, variedad, muestras}
  // muestras: muestra -> [lista de items de control]
  Map<String, Map<String, Map<String, dynamic>>> matrizCortes = {};
  
  // Controladores para agregar nuevas filas
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _cuadranteController = TextEditingController();
  
  // Valores seleccionados para el formulario de agregar
  Bloque? _selectedBloqueForm;
  Variedad? _selectedVariedadForm;
  
  bool _isLoadingDropdownData = true;
  bool _isLoadingBloques = false;
  bool _isLoadingVariedades = false;
  bool _isEditMode = false;

  // Lista de ítems de control
  final List<String> itemsControl = [
    "Corte conforme",
    "Dentro de zona de manejo", 
    "Corte con desinfectante",
    "Calibre conforme (≥4)",
    "Distancia mínimo 10 cm (subiendo)",
    "Yema a yema (bajando)",
    "Orientación yema (orilleros)",
    "Tocón entre 0,5 cm-1 cm",
    "Desnuque total",
    "Corte sin desgarre",
    "Bisel corte",
    "Corte en zigzag"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDateFormatting();
    _isEditMode = widget.checklistToEdit != null;
    
    if (_isEditMode) {
      _loadExistingChecklist();
    } else {
      _resetChecklist();
    }
    
    _loadDropdownData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _supervisorController.dispose();
    _cuadranteController.dispose();
    super.dispose();
  }

  Future<void> _initializeDateFormatting() async {
    try {
      await initializeDateFormatting('es_ES', null);
    } catch (e) {
      print('Error inicializando formateo de fechas: $e');
      // Continuar sin formateo específico si falla
    }
  }

  // Método para detectar si hay cambios sin guardar
  bool _hasUnsavedChanges() {
    // Verificar si hay datos básicos completos
    if (selectedFinca == null) {
      return false; // No hay datos para perder
    }

    // Verificar si hay datos en la matriz de cortes
    if (matrizCortes.isNotEmpty) {
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
              color: Colors.purple[800],
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
                backgroundColor: Colors.purple[600],
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

  String? _nombreDe(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    try {
      final dynamic obj = value as dynamic;
      final dynamic nombreProp = obj.nombre;
      if (nombreProp is String) return nombreProp;
    } catch (_) {}
    if (value is Map && value['nombre'] is String) {
      return value['nombre'] as String;
    }
    return value.toString();
  }

  void _loadExistingChecklist() {
    checklist = widget.checklistToEdit!;
    selectedFinca = checklist.finca;
    selectedDate = checklist.fecha ?? DateTime.now();
    
    // Reconstruir matriz desde el checklist cargado
    _reconstructMatrixFromChecklist();
  }
  
  void _resetChecklist() {
    checklist = ChecklistDataCortes.getChecklistCortes();
    selectedDate = DateTime.now();
    matrizCortes.clear();
  }

  void _reconstructMatrixFromChecklist() {
    matrizCortes.clear();
    
    for (var cuadrante in checklist.cuadrantes) {
      String supervisor = checklist.supervisor ?? 'Supervisor';
      
      if (!matrizCortes.containsKey(supervisor)) {
        matrizCortes[supervisor] = {};
      }
      
      // Inicializar estructura para este cuadrante
      Map<int, List<int>> muestras = {};
      for (int muestra = 1; muestra <= 10; muestra++) {
        muestras[muestra] = [];
      }
      
      matrizCortes[supervisor]![cuadrante.cuadrante] = {
        'bloque': cuadrante.bloque,
        'variedad': cuadrante.variedad,
        'cuadranteDisplay': cuadrante.cuadrante,
        'muestras': muestras, // muestra -> [lista de items de control evaluados]
      };
      
      // Cargar resultados existentes (convertir desde estructura anterior)
      for (var item in checklist.items) {
        for (int muestra = 1; muestra <= 10; muestra++) {
          String? resultado = item.getResultado(cuadrante.cuadrante, muestra);
          if (resultado != null && (resultado.toLowerCase() == 'c' || resultado == '1')) {
            matrizCortes[supervisor]![cuadrante.cuadrante]!['muestras'][muestra].add(item.id);
          }
        }
      }
    }
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

      // SIEMPRE verificar si estamos en modo edición después de cargar las fincas
      if (_isEditMode) {
        await _loadDataForEditMode();
      }

      if (_isEditMode && selectedFinca != null) {
        bool fincaExists = fincas.any((f) => f.nombre == selectedFinca!.nombre);
        if (!fincaExists) {
          setState(() {
            selectedFinca = null;
          });
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

  // NUEVO MÉTODO: Cargar datos específicos para modo edición
  Future<void> _loadDataForEditMode() async {
    try {
      print('Cargando datos para modo edición...');
      
      // Si tenemos una finca seleccionada, cargar los bloques
      if (selectedFinca != null) {
        print('Cargando bloques para finca: ${selectedFinca!.nombre}');
        await _loadBloquesForFinca(selectedFinca!.nombre);
      }
    } catch (e) {
      print('Error cargando datos para modo edición: $e');
      Fluttertoast.showToast(
        msg: 'Error cargando datos del checklist: $e',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> _loadBloquesForFinca(String finca) async {
    setState(() {
      _isLoadingBloques = true;
      // Solo resetear selecciones si NO estamos en modo edición
      if (!_isEditMode) {
        bloques = [];
        variedades = [];
        // Resetear valores del formulario cuando se cambia de finca
        _selectedBloqueForm = null;
        _selectedVariedadForm = null;
      }
      // Siempre limpiar la lista de bloques para recargarla
      bloques = [];
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
      } else {
        print('Bloques cargados: ${bloques.length} para finca $finca');
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
      // Siempre limpiar la lista de variedades para recargarla
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
      } else {
        print('Variedades cargadas: ${variedades.length} para finca $finca, bloque $bloque');
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

  void _agregarFilaMatrix() {
    if (_supervisorController.text.trim().isEmpty || 
        _cuadranteController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Supervisor y Cuadrante son obligatorios',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    String supervisor = _supervisorController.text.trim();
    String cuadrante = _cuadranteController.text.trim();

    // Verificar si ya existe esta combinación
    if (matrizCortes.containsKey(supervisor) && 
        matrizCortes[supervisor]!.containsKey(cuadrante)) {
      Fluttertoast.showToast(
        msg: 'Ya existe el cuadrante $cuadrante para el supervisor $supervisor',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      if (!matrizCortes.containsKey(supervisor)) {
        matrizCortes[supervisor] = {};
      }

      // Inicializar muestras vacías
      Map<int, List<int>> muestras = {};
      for (int muestra = 1; muestra <= 10; muestra++) {
        muestras[muestra] = [];
      }

      matrizCortes[supervisor]![cuadrante] = {
        'bloque': _selectedBloqueForm,
        'variedad': _selectedVariedadForm,
        'cuadranteDisplay': cuadrante,
        'muestras': muestras,
      };
    });

    // Limpiar controladores y selecciones
    _supervisorController.clear();
    _cuadranteController.clear();
    _selectedBloqueForm = null;
    _selectedVariedadForm = null;

    Fluttertoast.showToast(
      msg: 'Fila agregada: $supervisor - Cuadrante $cuadrante',
      backgroundColor: Colors.green[600],
        textColor: Colors.white,
    );
  }

  void _eliminarFila(String supervisor, String cuadrante) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Eliminar Fila'),
          content: Text('¿Está seguro de eliminar la fila del supervisor $supervisor, cuadrante $cuadrante?'),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Eliminar'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  matrizCortes[supervisor]?.remove(cuadrante);
                  if (matrizCortes[supervisor]?.isEmpty == true) {
                    matrizCortes.remove(supervisor);
                  }
                });

                Fluttertoast.showToast(
                  msg: 'Fila eliminada',
                  backgroundColor: Colors.red[600],
                  textColor: Colors.white,
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Duplica una fila existente generando un nuevo cuadrante disponible
  void _duplicarFila(String supervisor, String cuadrante) {
    final Map<String, Map<String, dynamic>> cuadrantesDelSupervisor = matrizCortes[supervisor] ?? {};

    // Obtener siguiente número de cuadrante disponible (incremental)
    int nextCuadranteNum = 1;
    final RegExp soloNumero = RegExp(r'^\d+\u0000?');
    // Recolectar números existentes si los cuadrantes son numéricos
    final Set<int> existentes = {};
    for (final key in cuadrantesDelSupervisor.keys) {
      final match = RegExp(r'^\d+').firstMatch(key);
      if (match != null) {
        existentes.add(int.parse(match.group(0)!));
      }
    }
    while (existentes.contains(nextCuadranteNum)) {
      nextCuadranteNum++;
    }

    final String nuevoCuadrante = existentes.isEmpty
        ? (cuadrante + ' (cópia)')
        : nextCuadranteNum.toString();

    final Map<String, dynamic>? original = cuadrantesDelSupervisor[cuadrante];
    if (original == null) return;

    // Clonar estructura de muestras pero SIN ítems seleccionados (todas vacías)
    Map<int, List<int>> nuevasMuestras = {};
    final Map<int, List<int>> muestrasOriginal = Map<int, List<int>>.from(original['muestras'] ?? {});
    if (muestrasOriginal.isNotEmpty) {
      muestrasOriginal.forEach((muestra, _) {
        nuevasMuestras[muestra] = <int>[];
      });
    } else {
      for (int muestra = 1; muestra <= 10; muestra++) {
        nuevasMuestras[muestra] = <int>[];
      }
    }

    setState(() {
      if (!matrizCortes.containsKey(supervisor)) {
        matrizCortes[supervisor] = {};
      }
      // Ajuste: crear clave interna única manteniendo el mismo número visible
      String nuevaClave = cuadrante;
      while (cuadrantesDelSupervisor.containsKey(nuevaClave) || matrizCortes[supervisor]!.containsKey(nuevaClave)) {
        nuevaClave = nuevaClave + ' *';
      }
      matrizCortes[supervisor]![nuevaClave] = {
        'bloque': original['bloque'],
        'variedad': original['variedad'],
        'cuadranteDisplay': original['cuadranteDisplay'] ?? cuadrante,
        'muestras': nuevasMuestras,
      };
    });

    Fluttertoast.showToast(
      msg: 'Fila duplicada: $supervisor - Cuadrante ${original['cuadranteDisplay'] ?? cuadrante}',
      backgroundColor: Colors.blue[600],
      textColor: Colors.white,
    );
  }

  void _editarMuestra(String supervisor, String cuadrante, int muestra) {
    List<int> itemsActuales = List<int>.from(
      matrizCortes[supervisor]![cuadrante]!['muestras'][muestra] ?? []
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<bool> seleccionados = List.generate(
          itemsControl.length, 
          (index) => itemsActuales.contains(index + 1)
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Función para verificar si "Corte conforme" está seleccionado
            bool isCorteConformeSelected = seleccionados[0]; // "Corte conforme" es el primer ítem (índice 0)
            
            // Función para verificar si algún otro ítem está seleccionado
            bool hasOtherItemsSelected = seleccionados.skip(1).any((selected) => selected);
            
            return AlertDialog(
              title: Text('Muestra $muestra - ${supervisor}'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cuadrante: $cuadrante${matrizCortes[supervisor]![cuadrante]!['bloque'] != null ? ' - Bloque: ${_nombreDe(matrizCortes[supervisor]![cuadrante]!['bloque'])}' : ''}',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 16),
                    Text('Seleccione los ítems de control evaluados:'),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Nota: "Corte conforme" es exclusivo con otros ítems',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 300,
                      child: SingleChildScrollView(
                        child: Column(
                          children: itemsControl.asMap().entries.map((entry) {
                            int index = entry.key;
                            String item = entry.value;
                            
                            // Determinar si este ítem debe estar deshabilitado
                            bool isDisabled = false;
                            if (index == 0) {
                              // "Corte conforme" se deshabilita si hay otros ítems seleccionados
                              isDisabled = hasOtherItemsSelected;
                            } else {
                              // Otros ítems se deshabilitan si "Corte conforme" está seleccionado
                              isDisabled = isCorteConformeSelected;
                            }
                            
                            return CheckboxListTile(
                              title: Text(
                                '${index + 1}. $item',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDisabled ? Colors.grey[500] : null,
                                ),
                              ),
                              value: seleccionados[index],
                              onChanged: isDisabled ? null : (bool? value) {
                                setDialogState(() {
                                  if (index == 0 && value == true) {
                                    // Si se selecciona "Corte conforme", deseleccionar todos los demás
                                    for (int i = 1; i < seleccionados.length; i++) {
                                      seleccionados[i] = false;
                                    }
                                  } else if (index > 0 && value == true) {
                                    // Si se selecciona cualquier otro ítem, deseleccionar "Corte conforme"
                                    seleccionados[0] = false;
                                  }
                                  seleccionados[index] = value ?? false;
                                });
                              },
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: isDisabled ? Colors.grey[400] : Colors.blue[600],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('Guardar'),
                  onPressed: () {
                    setState(() {
                      List<int> nuevosItems = [];
                      for (int i = 0; i < seleccionados.length; i++) {
                        if (seleccionados[i]) {
                          nuevosItems.add(i + 1);
                        }
                      }
                      matrizCortes[supervisor]![cuadrante]!['muestras'][muestra] = nuevosItems;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editarBloqueVariedad(String supervisor, String cuadrante) {
    // Soportar que vengan como String u objeto
    final dynamic bloqueRaw = matrizCortes[supervisor]![cuadrante]!['bloque'];
    final dynamic variedadRaw = matrizCortes[supervisor]![cuadrante]!['variedad'];
    Bloque? bloqueActual = bloqueRaw is Bloque ? bloqueRaw : null;
    Variedad? variedadActual = variedadRaw is Variedad ? variedadRaw : null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Editar Bloque y Variedad'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Supervisor: $supervisor - Cuadrante: $cuadrante',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 16),
                    
                    // Dropdown de Bloque
                    DropdownButtonFormField<Bloque>(
                      decoration: InputDecoration(
                        labelText: 'Bloque',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.view_module, color: Colors.blue[700]),
                      ),
                      value: bloqueActual,
                      onChanged: (Bloque? newValue) {
                        setDialogState(() {
                          bloqueActual = newValue;
                          variedadActual = null; // Resetear variedad al cambiar bloque
                        });
                        if (newValue != null && selectedFinca != null) {
                    _loadVariedadesForFincaAndBloque(selectedFinca!.nombre, newValue.nombre);
                        }
                      },
                      items: bloques.map<DropdownMenuItem<Bloque>>((Bloque bloque) {
                        return DropdownMenuItem<Bloque>(
                          value: bloque,
                          child: Text(bloque.nombre),
                        );
                      }).toList(),
                      hint: Text('Seleccione'),
                    ),
                    
                    SizedBox(height: 16),
                    
                                          // Dropdown de Variedad
                      DropdownButtonFormField<Variedad>(
                        decoration: InputDecoration(
                          labelText: 'Variedad',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
                        ),
                        value: variedadActual,
                        onChanged: bloqueActual != null ? (Variedad? newValue) {
                          setDialogState(() {
                            variedadActual = newValue;
                          });
                        } : null,
                        items: variedades.map<DropdownMenuItem<Variedad>>((Variedad variedad) {
                          return DropdownMenuItem<Variedad>(
                            value: variedad,
                            child: Text(variedad.nombre),
                          );
                        }).toList(),
                        hint: Text('Seleccione'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('Guardar'),
                  onPressed: () {
                    setState(() {
                      matrizCortes[supervisor]![cuadrante]!['bloque'] = bloqueActual;
                      matrizCortes[supervisor]![cuadrante]!['variedad'] = variedadActual;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[700]!, Colors.green[500]!],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.content_cut, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LISTA DE CHEQUEO: CORTES DEL DÍA',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Código: R-CORP-CDP-GA-01 • Rev: 00 • Página: 1 de 1',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildDateSelector()),
                SizedBox(width: 16),
                Expanded(child: _buildFincaDropdown()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (pickedDate != null && pickedDate != selectedDate) {
          setState(() {
            selectedDate = pickedDate;
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.green[700]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('dd MMM yyyy', 'es_ES').format(selectedDate),
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFincaDropdown() {
    return DropdownButtonFormField<Finca>(
      decoration: InputDecoration(
        labelText: 'Finca',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.location_on, color: Colors.green[700]),
      ),
      value: selectedFinca,
      onChanged: (Finca? newValue) {
        setState(() {
          selectedFinca = newValue;
          bloques = [];
          variedades = [];
          // Resetear valores seleccionados en el formulario
          _selectedBloqueForm = null;
          _selectedVariedadForm = null;
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
    );
  }

  Widget _buildFormularioAgregar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  'Agregar Nueva Fila',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _supervisorController,
                          decoration: InputDecoration(
                            labelText: 'Supervisor *',
                            hintText: 'Ej: leonidas',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cuadranteController,
                          decoration: InputDecoration(
                            labelText: 'Cuadrante *',
                            hintText: 'Ej: 25',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                                     Row(
                     children: [
                       Expanded(
                         child: DropdownButtonFormField<Bloque>(
                           decoration: InputDecoration(
                             labelText: 'Bloque',
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                             prefixIcon: Icon(Icons.view_module, color: Colors.blue[700]),
                             isDense: true,
                           ),
                           value: _selectedBloqueForm,
                           onChanged: selectedFinca != null ? (Bloque? newValue) {
                             setState(() {
                               _selectedBloqueForm = newValue;
                               _selectedVariedadForm = null; // Resetear variedad al cambiar bloque
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
                           hint: Text('Seleccione'),
                         ),
                       ),
                       SizedBox(width: 8),
                       Expanded(
                         child: DropdownButtonFormField<Variedad>(
                           decoration: InputDecoration(
                             labelText: 'Variedad',
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                             prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
                             isDense: true,
                           ),
                           value: _selectedVariedadForm,
                           onChanged: _selectedBloqueForm != null ? (Variedad? newValue) {
                             setState(() {
                               _selectedVariedadForm = newValue;
                             });
                           } : null,
                           items: variedades.map<DropdownMenuItem<Variedad>>((Variedad variedad) {
                             return DropdownMenuItem<Variedad>(
                               value: variedad,
                               child: Text(variedad.nombre),
                             );
                           }).toList(),
                           hint: Text('Seleccione'),
                         ),
                       ),
                     ],
                   ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _agregarFilaMatrix,
                      icon: Icon(Icons.add),
                      label: Text('Agregar Fila a la Matriz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
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

  Widget _buildMatrizCortes() {
    if (matrizCortes.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.table_chart, size: 64, color: Colors.orange[400]),
              SizedBox(height: 16),
              Text(
                'Primero debe agregar filas a la matriz',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Agregue supervisores con sus cuadrantes para comenzar a evaluar',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart, color: Colors.purple[700]),
                SizedBox(width: 8),
                Text(
                  'Matriz de Evaluación de Cortes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Toque en cada muestra para seleccionar los ítems de control evaluados',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16),
            
            // Matriz principal con scroll horizontal
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildDataTable(),
            ),
            
            SizedBox(height: 16),
            _buildResumenEstadisticas(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    List<DataColumn> columns = [
      DataColumn(
        label: Container(
          width: 100,
          child: Text(
            'Supervisor',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      DataColumn(
        label: Container(
          width: 80,
          child: Text(
            'Cuadrantes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      DataColumn(
        label: Container(
          width: 70,
          child: Text(
            'Bloque',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      DataColumn(
        label: Container(
          width: 80,
          child: Text(
            'Variedad',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
      // Columnas para las 10 muestras
      for (int muestra = 1; muestra <= 10; muestra++)
        DataColumn(
          label: Container(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Muestra',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                Text(
                  '$muestra',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue[700]),
                ),
              ],
            ),
          ),
        ),
      DataColumn(
        label: Container(
          width: 150,
          child: Text(
            'Acciones',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    ];

    List<DataRow> rows = [];
    
    matrizCortes.forEach((supervisor, cuadrantes) {
      cuadrantes.forEach((cuadrante, cuadranteData) {
        rows.add(
          DataRow(
            cells: [
              // Supervisor
              DataCell(
                Container(
                  width: 100,
                  child: Text(
                    supervisor,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Cuadrante
              DataCell(
                Container(
                  width: 80,
                  child: Text(
                    (cuadranteData['cuadranteDisplay']) ?? cuadrante,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
                             // Bloque
               DataCell(
                 Container(
                   width: 70,
                   child: Text(
                    _nombreDe(cuadranteData['bloque']) ?? '',
                     style: TextStyle(fontSize: 12),
                     textAlign: TextAlign.center,
                   ),
                 ),
               ),
               // Variedad
               DataCell(
                 Container(
                   width: 80,
                   child: Text(
                    _nombreDe(cuadranteData['variedad']) ?? '',
                     style: TextStyle(fontSize: 12),
                     overflow: TextOverflow.ellipsis,
                   ),
                 ),
               ),
              // Celdas para las 10 muestras
              for (int muestra = 1; muestra <= 10; muestra++)
                DataCell(
                  Container(
                    width: 60,
                    child: _buildMuestraCell(supervisor, cuadrante, muestra, cuadranteData),
                  ),
                ),
              // Acciones
              DataCell(
                Container(
                  width: 150,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue, size: 18),
                        onPressed: () => _editarBloqueVariedad(supervisor, cuadrante),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: 'Editar Bloque y Variedad',
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, color: Colors.purple, size: 18),
                        onPressed: () => _duplicarFila(supervisor, cuadrante),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: 'Duplicar Fila',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 18),
                        onPressed: () => _eliminarFila(supervisor, cuadrante),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                        tooltip: 'Eliminar Fila',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      });
    });

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DataTable(
        columnSpacing: 4,
        horizontalMargin: 8,
        headingRowColor: MaterialStateProperty.all(Colors.purple[50]),
        dataRowHeight: 60,
        headingRowHeight: 60,
        border: TableBorder.all(color: Colors.grey[300]!),
        columns: columns,
        rows: rows,
      ),
    );
  }

  Widget _buildMuestraCell(String supervisor, String cuadrante, int muestra, Map<String, dynamic> cuadranteData) {
    List<int> itemsEvaluados = List<int>.from(cuadranteData['muestras'][muestra] ?? []);
    
    return InkWell(
      onTap: () => _editarMuestra(supervisor, cuadrante, muestra),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: itemsEvaluados.isEmpty ? Colors.grey[100] : Colors.green[50],
          border: Border.all(
            color: itemsEvaluados.isEmpty ? Colors.grey[300]! : Colors.green[300]!,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (itemsEvaluados.isEmpty)
              Icon(Icons.add, size: 16, color: Colors.grey[600])
            else
              Text(
                '${itemsEvaluados.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green[700],
                ),
              ),
            Text(
              itemsEvaluados.isEmpty ? 'Evaluar' : 'ítems',
              style: TextStyle(
                fontSize: 8,
                color: itemsEvaluados.isEmpty ? Colors.grey[600] : Colors.green[600],
              ),
            ),
            if (itemsEvaluados.isNotEmpty)
              Text(
                itemsEvaluados.take(3).join(',') + (itemsEvaluados.length > 3 ? '...' : ''),
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.green[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenEstadisticas() {
    if (matrizCortes.isEmpty) return SizedBox.shrink();

    // Calcular estadísticas
    int totalMuestras = 0;
    int muestrasEvaluadas = 0;
    int totalItemsEvaluados = 0;
    int totalFilas = 0;

    matrizCortes.forEach((supervisor, cuadrantes) {
      cuadrantes.forEach((cuadrante, cuadranteData) {
        totalFilas++;
        Map<int, List<int>> muestras = Map<int, List<int>>.from(cuadranteData['muestras'] ?? {});
        
        muestras.forEach((muestra, items) {
          totalMuestras++;
          if (items.isNotEmpty) {
            muestrasEvaluadas++;
            totalItemsEvaluados += items.length;
          }
        });
      });
    });

    double porcentajeEvaluacion = totalMuestras > 0 
        ? (muestrasEvaluadas / totalMuestras) * 100 
        : 0.0;
    
    double promedioItemsPorMuestra = muestrasEvaluadas > 0 
        ? totalItemsEvaluados / muestrasEvaluadas
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen de Evaluación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.purple[700],
          ),
        ),
        SizedBox(height: 12),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Filas', '$totalFilas', Colors.blue),
              _buildStatCard('Muestras Totales', '$totalMuestras', Colors.orange),
              _buildStatCard('Muestras Evaluadas', '$muestrasEvaluadas', Colors.green),
              _buildStatCard('% Completado', '${porcentajeEvaluacion.toStringAsFixed(1)}%', Colors.purple),
              _buildStatCard('Ítems Promedio', '${promedioItemsPorMuestra.toStringAsFixed(1)}', Colors.teal),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Lista de ítems de control como referencia
        Text(
          'Ítems de Control Disponibles:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: itemsControl.asMap().entries.map((entry) => 
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Text(
                  '${entry.key + 1}. ${entry.value}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _canSave() ? _saveChecklist : null,
              icon: Icon(Icons.save),
              label: Text(_isEditMode ? 'Actualizar' : 'Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChecklistCortesRecordsScreen(),
                  ),
                );
              },
              icon: Icon(Icons.history),
              label: Text('Ver Registros'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    return selectedFinca != null && matrizCortes.isNotEmpty;
  }

  Future<void> _saveChecklist() async {
    if (!_canSave()) return;

    try {
      // Convertir la matriz a la estructura del checklist
      List<CuadranteInfo> cuadrantes = [];
      List<ChecklistCortesItem> items = [];
      
      // Preparar items de control
      for (int itemId = 1; itemId <= itemsControl.length; itemId++) {
        items.add(ChecklistCortesItem(
          id: itemId,
          proceso: itemsControl[itemId - 1],
          resultadosPorCuadrante: {},
        ));
      }

      // Procesar matriz y extraer datos
      String? supervisorGeneral;
      matrizCortes.forEach((supervisor, cuadrantesMap) {
        supervisorGeneral ??= supervisor; // Usar el primer supervisor como general
        
        cuadrantesMap.forEach((cuadrante, cuadranteData) {
          // Agregar cuadrante
          cuadrantes.add(CuadranteInfo(
            cuadrante: cuadrante,
            bloque: _nombreDe(cuadranteData['bloque']),
            variedad: _nombreDe(cuadranteData['variedad']),
            supervisor: supervisor, // Supervisor específico del cuadrante
          ));

          // Procesar muestras y convertir a la estructura de items
          Map<int, List<int>> muestras = Map<int, List<int>>.from(cuadranteData['muestras'] ?? {});
          
          muestras.forEach((muestra, itemsEvaluados) {
            // Para cada ítem evaluado en esta muestra, marcar como conforme
            for (int itemId in itemsEvaluados) {
              if (itemId <= items.length) {
                var item = items[itemId - 1];
                if (!item.resultadosPorCuadrante.containsKey(cuadrante)) {
                  item.resultadosPorCuadrante[cuadrante] = {};
                }
                // Marcar como conforme (C) si el ítem fue evaluado en esta muestra
                item.resultadosPorCuadrante[cuadrante]![muestra] = 'C';
              }
            }
          });
        });
      });

      // Crear checklist actualizado
      checklist = ChecklistCortes(
        id: checklist.id,
        fecha: selectedDate,
        finca: selectedFinca,
        supervisor: supervisorGeneral,
        cuadrantes: cuadrantes,
        items: items,
        porcentajeCumplimiento: _calcularPorcentajeGeneral(),
      );

      int? savedId;
      if (_isEditMode) {
        await ChecklistCortesStorageService.updateChecklist(checklist);
        savedId = checklist.id;
      } else {
        savedId = await ChecklistCortesStorageService.saveChecklist(checklist);
      }

      Fluttertoast.showToast(
        msg: _isEditMode ? 'Checklist actualizado exitosamente' : 'Checklist guardado exitosamente',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
      );

      // Navegar a la pantalla de registros para ver y editar los datos
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistCortesRecordsScreen(),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error guardando checklist: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  double _calcularPorcentajeGeneral() {
    int totalMuestrasConCorteConforme = 0;
    int muestrasConCorteConforme = 0;

    matrizCortes.forEach((supervisor, cuadrantes) {
      cuadrantes.forEach((cuadrante, cuadranteData) {
        Map<int, List<int>> muestras = Map<int, List<int>>.from(cuadranteData['muestras'] ?? {});
        
        muestras.forEach((muestra, items) {
          // Solo contar muestras que tienen el item "Corte conforme" (item 1) evaluado
          if (items.contains(1)) {
            totalMuestrasConCorteConforme++;
            // Si tiene el item "Corte conforme", considerarlo como conforme
            muestrasConCorteConforme++;
          }
        });
      });
    });

    return totalMuestrasConCorteConforme > 0 ? (muestrasConCorteConforme / totalMuestrasConCorteConforme) * 100 : 0.0;
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
        appBar: AppBar(
        title: Text('Cortes del Día'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
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
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Información'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instrucciones de uso:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('1. Seleccione fecha y finca'),
                        Text('2. Agregue filas con supervisor y cuadrante'),
                        Text('3. Toque en cada muestra para seleccionar ítems evaluados'),
                        Text('4. Una muestra puede tener múltiples ítems de control'),
                        Text('5. Guarde cuando termine la evaluación'),
                        SizedBox(height: 12),
                        Text('Estructura de la Matriz:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• Cada fila = 1 supervisor + 1 cuadrante'),
                        Text('• 10 muestras por cuadrante'),
                        Text('• Cada muestra puede evaluar varios ítems'),
                        Text('• Toque la celda para seleccionar ítems'),
                        SizedBox(height: 12),
                        Text('Ítems de Control:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          height: 200,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: itemsControl.asMap().entries.map((entry) => 
                                Text('${entry.key + 1}. ${entry.value}', style: TextStyle(fontSize: 12))
                              ).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: Text('Cerrar'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Información y ayuda',
          ),
        ],
      ),
      body: _isLoadingDropdownData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green[600]),
                  SizedBox(height: 16),
                  Text('Cargando datos...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 16),
                  _buildControlPanel(),
                  SizedBox(height: 16),
                  _buildFormularioAgregar(),
                  SizedBox(height: 16),
                  _buildMatrizCortes(),
                  SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
      ),
    );
  }
}