import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../data/checklist_data_labores_permanentes.dart';
import '../models/dropdown_models.dart';
import '../services/cosecha_dropdown_service.dart';
import '../services/dropdown_service.dart';
import '../services/checklist_labores_permanentes_storage_service.dart';
import '../services/auth_service.dart';
import 'checklist_labores_permanentes_records_screen.dart';

class ChecklistLaboresPermanentesScreen extends StatefulWidget {
  final ChecklistLaboresPermanentes? checklistToEdit;
  final int? recordId;

  ChecklistLaboresPermanentesScreen({
    this.checklistToEdit,
    this.recordId,
  });

  @override
  _ChecklistLaboresPermanentesScreenState createState() => _ChecklistLaboresPermanentesScreenState();
}

class _ChecklistLaboresPermanentesScreenState extends State<ChecklistLaboresPermanentesScreen> with WidgetsBindingObserver {
  late ChecklistLaboresPermanentes checklist;
  
  // Datos para los dropdowns
  List<Finca> fincas = [];
  List<Bloque> bloques = [];
  List<Variedad> variedades = [];
  List<Usuario> usuarios = [];
  
  // Valores seleccionados
  Finca? selectedFinca;
  Bloque? selectedBloque;
  Variedad? selectedVariedad;
  Usuario? selectedUsuario;
  DateTime selectedDate = DateTime.now();
  
  // Estructura: supervisor_bloque_cuadrante -> {supervisor, bloque, variedad, cuadrante, paradas}
  // paradas: parada (1-5) -> {resultados por item (1-16)}
  Map<String, Map<String, dynamic>> matrizLabores = {};
  
  // Controladores para agregar nuevas filas
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _cuadranteController = TextEditingController();
  
  // Valores seleccionados para el formulario de agregar
  Bloque? _selectedBloqueForm;
  Variedad? _selectedVariedadForm;
  
  // Controladores para campos adicionales
  final TextEditingController _semanaController = TextEditingController();
  final TextEditingController _kontrollerController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  
  bool _isLoadingDropdownData = true;
  bool _isLoadingBloques = false;
  bool _isLoadingVariedades = false;
  bool _isEditMode = false;

  // Lista de labores permanentes (16 items actualizados)
  final List<String> laboresPermanentes = [
    "Desyeme conforme",
    "Descabece conforme", 
    "Deshooting conforme",
    "Rectificación de tocones conforme",
    "Deschupone conforme",
    "Deshierbe conforme",
    "Encanaste y peinado conforme",
    "Escarificado conforme",
    "Escobillado conforme",
    "Limpieza de hojas secas",
    "Mangueras de goteo descubiertas",
    "Presencia de charcos de agua",
    "Tutoreo y tensado de alambres",
    "Drenchado",
    "Erradicación de velloso",
    "Pinch (tallos > 7mm)",
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
    _semanaController.dispose();
    _kontrollerController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('es_ES', null);
  }

  // Método para detectar si hay cambios sin guardar
  bool _hasUnsavedChanges() {
    // Verificar si hay datos básicos completos
    if (selectedFinca == null || selectedBloque == null || selectedVariedad == null) {
      return false; // No hay datos para perder
    }

    // Verificar si hay datos en la matriz de labores
    if (matrizLabores.isNotEmpty) {
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
              color: Colors.deepPurple[800],
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
                backgroundColor: Colors.deepPurple[600],
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

  void _loadExistingChecklist() {
    checklist = widget.checklistToEdit!;
    selectedFinca = checklist.finca;
    selectedDate = checklist.fecha ?? DateTime.now();
    
    // Cargar campos adicionales
    _semanaController.text = checklist.semana ?? '';
    _kontrollerController.text = checklist.kontroller ?? '';
    _observacionesController.text = checklist.observacionesGenerales ?? '';
    
    // Reconstruir matriz desde el checklist cargado
    _reconstructMatrixFromChecklist();
  }
  
  // Método para cargar automáticamente el usuario actual del sistema
  Future<void> _loadCurrentUser() async {
    try {
      Map<String, dynamic>? currentUser = await AuthService.getCurrentUser();
      if (currentUser != null && usuarios.isNotEmpty) {
        // Buscar el usuario actual en la lista de usuarios disponibles
        var usuarioEncontrado = usuarios.firstWhere(
          (usuario) => usuario.nombre == currentUser['nombre'],
          orElse: () => Usuario(
            id: currentUser['id'],
            nombre: currentUser['nombre'],
            username: currentUser['username'],
            email: currentUser['email'],
            activo: currentUser['activo'],
          ),
        );
        setState(() {
          selectedUsuario = usuarioEncontrado;
        });
        
        // Actualizar el controlador del kontroller con el nombre del usuario actual
        _kontrollerController.text = currentUser['nombre'] ?? '';
      }
    } catch (e) {
      print('Error cargando usuario actual: $e');
    }
  }

  // Método para seleccionar el usuario basado en el nombre del kontroller
  void _selectUsuarioFromKontroller() {
    if (checklist.kontroller != null && checklist.kontroller!.isNotEmpty && usuarios.isNotEmpty) {
      // Buscar el usuario por nombre
      var usuarioEncontrado = usuarios.firstWhere(
        (usuario) => usuario.nombre == checklist.kontroller,
        orElse: () => usuarios.first, // Si no se encuentra, usar el primero
      );
      setState(() {
        selectedUsuario = usuarioEncontrado;
      });
    }
  }
  
  void _resetChecklist() {
    checklist = ChecklistDataLaboresPermanentes.getChecklistLaboresPermanentes();
    selectedDate = DateTime.now();
    matrizLabores.clear();
    
    _semanaController.clear();
    _kontrollerController.clear();
    _observacionesController.clear();
  }

  void _reconstructMatrixFromChecklist() {
    matrizLabores.clear();
    
    print('=== RECONSTRUYENDO MATRIZ ===');
    print('Checklist tiene ${checklist.cuadrantes.length} cuadrantes y ${checklist.items.length} items');
    
    for (var cuadrante in checklist.cuadrantes) {
      String clave = cuadrante.claveUnica;
      print('Procesando cuadrante: ${cuadrante.supervisor} - ${cuadrante.bloque} - ${cuadrante.cuadrante}');
      print('Clave única generada: $clave');
      
      // Inicializar paradas para este cuadrante
      Map<int, Map<int, String?>> paradas = {};
      for (int parada = 1; parada <= 5; parada++) {
        paradas[parada] = {};
        // Inicializar todos los items como null
        for (int itemId = 1; itemId <= laboresPermanentes.length; itemId++) {
          paradas[parada]![itemId] = null;
        }
      }
      
      // Convertir el string del bloque a un objeto Bloque si es necesario
      Bloque? bloqueObj;
      if (cuadrante.bloque is String) {
        // Buscar el bloque en la lista de bloques disponibles si ya están cargados
        if (bloques.isNotEmpty) {
          bloqueObj = bloques.firstWhere(
            (b) => b.nombre == cuadrante.bloque,
            orElse: () => Bloque(nombre: cuadrante.bloque),
          );
        } else {
          // Si no están cargados, crear un objeto temporal
          bloqueObj = Bloque(nombre: cuadrante.bloque);
        }
      } else if (cuadrante.bloque is Bloque) {
        bloqueObj = cuadrante.bloque as Bloque;
      }
      
      // Convertir el string de la variedad a un objeto Variedad si es necesario
      Variedad? variedadObj;
      if (cuadrante.variedad is String && cuadrante.variedad != null) {
        // Buscar la variedad en la lista de variedades disponibles si ya están cargados
        if (variedades.isNotEmpty) {
          variedadObj = variedades.firstWhere(
            (v) => v.nombre == cuadrante.variedad,
            orElse: () => Variedad(nombre: cuadrante.variedad!),
          );
        } else {
          // Si no están cargados, crear un objeto temporal
          variedadObj = Variedad(nombre: cuadrante.variedad!);
        }
      } else if (cuadrante.variedad is Variedad) {
        variedadObj = cuadrante.variedad as Variedad;
      }
      
      matrizLabores[clave] = {
        'supervisor': cuadrante.supervisor,
        'bloque': bloqueObj,
        'variedad': variedadObj,
        'cuadrante': cuadrante.cuadrante,
        'paradas': paradas,
      };
      
      print('Fila agregada a matriz con clave: $clave');
    }
    
    print('=== CARGANDO RESULTADOS DE ITEMS ===');
    // Cargar resultados existentes de todos los items para todas las paradas
    for (var item in checklist.items) {
      print('Procesando item ${item.id}: ${item.proceso}');
      print('Item tiene ${item.resultadosPorCuadranteParada.length} cuadrantes con resultados');
      
      for (var cuadrante in checklist.cuadrantes) {
        String clave = cuadrante.claveUnica;
        print('  Buscando resultados para cuadrante: $clave');
        
        for (int parada = 1; parada <= 5; parada++) {
          String? resultado = item.getResultado(clave, parada);
          if (resultado != null && resultado.trim().isNotEmpty) {
            print('    Parada $parada: resultado = $resultado');
            // Asegurarse de que la clave existe en la matriz
            if (matrizLabores.containsKey(clave)) {
              matrizLabores[clave]!['paradas'][parada][item.id] = resultado;
              print('    ✓ Resultado cargado en matriz[clave][parada][itemId]');
            } else {
              print('    ✗ ERROR: Clave $clave no encontrada en matriz');
            }
          }
        }
      }
    }
    
    print('=== RESUMEN FINAL ===');
    print('Matriz reconstruida con ${matrizLabores.length} filas');
    // Debug: imprimir algunos resultados para verificar
    matrizLabores.forEach((clave, data) {
      Map<int, Map<int, String?>> paradas = data['paradas'];
      int totalResultados = 0;
      paradas.forEach((parada, items) {
        items.forEach((itemId, resultado) {
          if (resultado != null && resultado.trim().isNotEmpty) {
            totalResultados++;
          }
        });
      });
      print('Fila $clave: $totalResultados resultados cargados');
    });
  }

  Future<void> _loadDropdownData({bool forceSync = false}) async {
    setState(() {
      _isLoadingDropdownData = true;
    });

    try {
      // Cargar datos de cosecha (fincas, bloques, variedades)
      Map<String, dynamic> cosechaData = await CosechaDropdownService.getCosechaDropdownData(forceSync: forceSync);
      
      // Cargar datos de bodega (usuarios)
      Map<String, dynamic> bodegaData = await DropdownService.getChecklistDropdownData(forceSync: forceSync);
      
      setState(() {
        fincas = cosechaData['fincas'] ?? [];
        usuarios = bodegaData['usuarios'] ?? [];
        _isLoadingDropdownData = false;
      });

      if (_isEditMode && selectedFinca != null) {
        bool fincaExists = fincas.any((f) => f.nombre == selectedFinca!.nombre);
        if (!fincaExists) {
          setState(() {
            selectedFinca = null;
          });
        }
      }
      
      // Cargar automáticamente el usuario actual del sistema
      await _loadCurrentUser();
      
      // En modo edición, seleccionar el usuario basado en el kontroller
      if (_isEditMode) {
        _selectUsuarioFromKontroller();
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

  // Método para cargar bloques según la finca seleccionada
  Future<void> _loadBloquesForFinca(String finca) async {
    setState(() {
      _isLoadingBloques = true;
      // Resetear todas las selecciones cuando cambia la finca
      selectedBloque = null;
      selectedVariedad = null;
      variedades = [];
      // También resetear los valores del formulario
      _selectedBloqueForm = null;
      _selectedVariedadForm = null;
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
        
        // En modo edición, verificar que el bloque seleccionado esté en la lista
        if (_isEditMode && selectedBloque != null) {
          bool bloqueExists = bloques.any((b) => b.nombre == selectedBloque!.nombre);
          if (!bloqueExists) {
            print('Bloque seleccionado ${selectedBloque!.nombre} no encontrado en la lista');
            setState(() {
              selectedBloque = null;
              selectedVariedad = null;
              variedades = [];
            });
          }
        }
        
        // En modo edición, actualizar los objetos Bloque en la matriz con los objetos reales
        if (_isEditMode) {
          setState(() {
            matrizLabores.forEach((clave, data) {
              if (data['bloque'] is Bloque && data['bloque'].nombre != null) {
                // Buscar el bloque real en la lista cargada
                var bloqueReal = bloques.firstWhere(
                  (b) => b.nombre == data['bloque'].nombre,
                  orElse: () => data['bloque'],
                );
                data['bloque'] = bloqueReal;
              }
            });
          });
        }
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

  // Método para cargar variedades según la finca y bloque seleccionados
  Future<void> _loadVariedadesForFincaAndBloque(String finca, String bloque) async {
    setState(() {
      _isLoadingVariedades = true;
      // Resetear selección de variedad cuando cambia el bloque
      selectedVariedad = null;
      // También resetear el valor del formulario
      _selectedVariedadForm = null;
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
        
        // En modo edición, verificar que la variedad seleccionada esté en la lista
        if (_isEditMode && selectedVariedad != null) {
          bool variedadExists = variedades.any((v) => v.nombre == selectedVariedad!.nombre);
          if (!variedadExists) {
            print('Variedad seleccionada ${selectedVariedad!.nombre} no encontrada en la lista');
            setState(() {
              selectedVariedad = null;
            });
          }
        }
        
        // En modo edición, actualizar los objetos Variedad en la matriz con los objetos reales
        if (_isEditMode) {
          setState(() {
            matrizLabores.forEach((clave, data) {
              if (data['variedad'] is Variedad && data['variedad'].nombre != null) {
                // Buscar la variedad real en la lista cargada
                var variedadReal = variedades.firstWhere(
                  (v) => v.nombre == data['variedad'].nombre,
                  orElse: () => data['variedad'],
                );
                data['variedad'] = variedadReal;
              }
            });
          });
        }
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

    // Crear clave única (debe coincidir con CuadranteLaboresInfo.claveUnica)
    String clave = '${supervisor}_${_selectedBloqueForm?.nombre ?? ''}_${cuadrante}';

    // Verificar si ya existe esta combinación
    if (matrizLabores.containsKey(clave)) {
      Fluttertoast.showToast(
        msg: 'Ya existe: $supervisor - Bloque ${_selectedBloqueForm?.nombre ?? ''} - Cuadrante $cuadrante',
        backgroundColor: Colors.orange[600],
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      // Inicializar paradas vacías (1-5)
      Map<int, Map<int, String?>> paradas = {};
      for (int parada = 1; parada <= 5; parada++) {
        paradas[parada] = {};
        // Inicializar todos los items (1-12) como null
        for (int itemId = 1; itemId <= laboresPermanentes.length; itemId++) {
          paradas[parada]![itemId] = null;
        }
      }

      matrizLabores[clave] = {
        'supervisor': supervisor,
        'bloque': _selectedBloqueForm,
        'variedad': _selectedVariedadForm,
        'cuadrante': cuadrante,
        'paradas': paradas,
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

  void _eliminarFila(String clave) {
    var data = matrizLabores[clave]!;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Eliminar Fila'),
          content: Text('¿Está seguro de eliminar: ${data['supervisor']} - Cuadrante ${data['cuadrante']}?'),
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
                  matrizLabores.remove(clave);
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

  // Duplica una fila existente generando una nueva clave con cuadrante incremental
  void _duplicarFila(String clave) {
    final data = matrizLabores[clave];
    if (data == null) return;

    final String supervisor = data['supervisor'] ?? '';
    final String bloqueNombre = data['bloque']?.nombre ?? '';
    final String cuadranteOriginal = (data['cuadrante'] ?? '').toString();

    // Encontrar siguiente cuadrante numérico disponible para este supervisor+bloque
    final Iterable<String> clavesMismoSB = matrizLabores.keys.where((k) =>
        (matrizLabores[k]?['supervisor'] ?? '') == supervisor &&
        (matrizLabores[k]?['bloque']?.nombre ?? '') == bloqueNombre);

    final Set<int> cuadrantesNumericos = {};
    for (final k in clavesMismoSB) {
      final String? cuad = matrizLabores[k]?['cuadrante'];
      final match = RegExp(r'^\d+').firstMatch(cuad ?? '');
      if (match != null) {
        cuadrantesNumericos.add(int.parse(match.group(0)!));
      }
    }
    int nextCuadrante = 1;
    while (cuadrantesNumericos.contains(nextCuadrante)) {
      nextCuadrante++;
    }

    // Construir nueva clave manteniendo el mismo número visible de cuadrante
    String nuevaClave = '${supervisor}_${bloqueNombre}_${cuadranteOriginal}';
    int intento = 1;
    while (matrizLabores.containsKey(nuevaClave)) {
      intento++;
      nuevaClave = '${supervisor}_${bloqueNombre}_${cuadranteOriginal} *$intento';
    }

    // Clonar paradas pero SIN ítems seleccionados (todo null)
    final Map<int, Map<int, String?>> paradasOriginal = data['paradas'];
    final Map<int, Map<int, String?>> nuevasParadas = {};
    paradasOriginal.forEach((p, items) {
      final Map<int, String?> nuevosItems = {};
      items.forEach((itemId, _) {
        nuevosItems[itemId] = null;
      });
      nuevasParadas[p] = nuevosItems;
    });

    setState(() {
      matrizLabores[nuevaClave] = {
        'supervisor': supervisor,
        'bloque': data['bloque'],
        'variedad': data['variedad'],
        // Mantener el mismo número visible de cuadrante
        'cuadrante': cuadranteOriginal,
        'paradas': nuevasParadas,
      };
    });

    Fluttertoast.showToast(
      msg: 'Fila duplicada: $supervisor - Cuadrante $cuadranteOriginal',
      backgroundColor: Colors.blue[600],
      textColor: Colors.white,
    );
  }

  void _updateResultado(String clave, int parada, int itemId, String? resultado) {
    setState(() {
      if (matrizLabores.containsKey(clave)) {
        matrizLabores[clave]!['paradas'][parada][itemId] = resultado;
      }
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple[700]!, Colors.deepPurple[500]!],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.agriculture, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'CHECK LIST LABORES CULTURALES PERMANENTE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple[700],
              ),
            ),
            SizedBox(height: 24),
            
            // Fila 1: Fecha y Finca
            Row(
              children: [
                Expanded(child: _buildDateSelector()),
                SizedBox(width: 20),
                Expanded(child: _buildFincaDropdown()),
              ],
            ),
            
            SizedBox(height: 24),
            

            
            // Fila 2: Semana
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _semanaController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Semana',
                      hintText: 'Ej: 31',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: Icon(Icons.calendar_view_week, color: Colors.deepPurple[700]),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Container(), // Espacio vacío para mantener el layout
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Fila 4: Kontroller (línea separada)
            _buildUsuarioDropdown(),
            
            SizedBox(height: 24),
            
            // Observaciones Generales
            TextField(
              controller: _observacionesController,
              decoration: InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Observaciones generales...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.note_alt, color: Colors.deepPurple[700]),
              ),
              maxLines: 3,
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
          locale: Locale('es', 'ES'),
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
            Icon(Icons.calendar_today, color: Colors.deepPurple[700]),
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
        labelText: 'Unidad Productiva',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.location_on, color: Colors.deepPurple[700]),
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
          // También resetear los valores del formulario de agregar
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

  Widget _buildBloqueDropdown() {
    return DropdownButtonFormField<Bloque>(
      decoration: InputDecoration(
        labelText: 'Bloque',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.view_module, color: Colors.deepPurple[700]),
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
      hint: Text('Seleccione'),
    );
  }

  Widget _buildVariedadDropdown() {
    return DropdownButtonFormField<Variedad>(
      decoration: InputDecoration(
        labelText: 'Variedad',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.eco, color: Colors.deepPurple[700]),
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
      hint: Text('Seleccione'),
    );
  }

  Widget _buildUsuarioDropdown() {
    return DropdownButtonFormField<Usuario>(
      decoration: InputDecoration(
        labelText: 'Kontroller',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.person_outline, color: Colors.deepPurple[700]),
        filled: true,
        fillColor: Colors.grey[100],
        suffixIcon: Icon(Icons.lock, color: Colors.grey[600], size: 16),
      ),
      value: selectedUsuario,
      onChanged: null, // Campo bloqueado - no se puede cambiar
      items: usuarios.map<DropdownMenuItem<Usuario>>((Usuario usuario) {
        return DropdownMenuItem<Usuario>(
          value: usuario,
          child: Text(usuario.nombre),
        );
      }).toList(),
      hint: Text('Usuario actual del sistema'),
    );
  }

  Widget _buildFormularioAgregar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: Colors.blue[700], size: 24),
                SizedBox(width: 12),
                Text(
                  'Agregar Nueva Fila',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  // Fila 1: Supervisor y Cuadrante
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _supervisorController,
                          decoration: InputDecoration(
                            labelText: 'Supervisor *',
                            hintText: 'Nombre del supervisor',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _cuadranteController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Cuadrante *',
                            hintText: 'Número de cuadrante',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Fila 2: Bloque y Variedad (dropdowns dependientes)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Bloque>(
                          decoration: InputDecoration(
                            labelText: 'Bloque',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.view_module, color: Colors.blue[700]),
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
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<Variedad>(
                          decoration: InputDecoration(
                            labelText: 'Variedad',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
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
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _agregarFilaMatrix,
                      icon: Icon(Icons.add, size: 20),
                      label: Text(
                        'Agregar Fila a la Matriz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
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

  Widget _buildMatrizLabores() {
    if (matrizLabores.isEmpty) {
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
                'Agregue supervisores con bloques y cuadrantes para comenzar a evaluar',
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
                Icon(Icons.table_chart, color: Colors.deepPurple[700]),
                SizedBox(width: 8),
                Text(
                  'Matriz de Evaluación de Labores Permanentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '1 = Conforme, 0 = No Conforme • 5 paradas por fila • 12 ítems por parada',
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
            'Cuadrante',
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
      // Columnas para las 5 paradas
      for (int parada = 1; parada <= 5; parada++)
        DataColumn(
          label: Container(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Parada',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                Text(
                  '$parada',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue[700]),
                ),
              ],
            ),
          ),
        ),
      DataColumn(
        label: Container(
          width: 160,
          child: Text(
            'Acciones',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    ];

    List<DataRow> rows = [];
    
    matrizLabores.forEach((clave, data) {
      rows.add(
        DataRow(
          cells: [
            // Supervisor
            DataCell(
              Container(
                width: 100,
                child: Text(
                  data['supervisor'],
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
                  data['cuadrante'] ?? '',
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
                  data['bloque']?.nombre ?? '',
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
                  data['variedad']?.nombre ?? '',
                  style: TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Celdas para las 5 paradas
            for (int parada = 1; parada <= 5; parada++)
              DataCell(
                Container(
                  width: 60,
                  child: _buildParadaCell(clave, parada, data['paradas']),
                ),
              ),
            // Acciones
            DataCell(
              Container(
                width: 160,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue, size: 18),
                      onPressed: () => _editarFila(clave),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: 'Editar Fila',
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.purple, size: 18),
                      onPressed: () => _duplicarFila(clave),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 30, minHeight: 30),
                      tooltip: 'Duplicar Fila',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 18),
                      onPressed: () => _eliminarFila(clave),
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

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DataTable(
        columnSpacing: 4,
        horizontalMargin: 8,
        headingRowColor: MaterialStateProperty.all(Colors.deepPurple[50]),
        dataRowHeight: 60,
        headingRowHeight: 60,
        border: TableBorder.all(color: Colors.grey[300]!),
        columns: columns,
        rows: rows,
      ),
    );
  }

  Widget _buildParadaCell(String clave, int parada, Map<int, Map<int, String?>> paradas) {
    Map<int, String?> itemsEvaluados = paradas[parada] ?? {};
    int totalItems = laboresPermanentes.length;
    // Contar ítems marcados (cualquier valor no nulo)
    int itemsMarcados = 0;
    itemsEvaluados.forEach((_, resultado) {
      if (resultado != null && resultado.trim().isNotEmpty) {
        itemsMarcados++;
      }
    });
    // Restantes (tratados como "conformes" según la nueva regla)
    final int itemsRestantes = totalItems - itemsMarcados;

    return InkWell(
      onTap: () => _editarParada(clave, parada),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
          color: itemsRestantes == totalItems ? Colors.green[50] : Colors.grey[50],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$itemsRestantes/$totalItems',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: itemsRestantes == totalItems ? Colors.green[700] : Colors.grey[600],
              ),
            ),
            Text(
              'Items',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editarFila(String clave) {
    var data = matrizLabores[clave]!;
    
    // Controladores temporales para la edición
    final TextEditingController _editSupervisorController = TextEditingController(text: data['supervisor']);
    final TextEditingController _editCuadranteController = TextEditingController(text: data['cuadrante'] ?? '');
    Bloque? _editBloque = data['bloque'];
    Variedad? _editVariedad = data['variedad'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: Text('Editar Fila'),
              content: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    Text(
                      'Modifique los campos de la fila:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    
                    // Supervisor
                    TextField(
                      controller: _editSupervisorController,
                      decoration: InputDecoration(
                        labelText: 'Supervisor *',
                        hintText: 'Nombre del supervisor',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Cuadrante
                    TextField(
                      controller: _editCuadranteController,
                      decoration: InputDecoration(
                        labelText: 'Cuadrante *',
                        hintText: 'Número de cuadrante',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.grid_on, color: Colors.blue[700]),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Bloque
                    DropdownButtonFormField<Bloque>(
                      decoration: InputDecoration(
                        labelText: 'Bloque',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.view_module, color: Colors.blue[700]),
                      ),
                      value: _editBloque,
                      onChanged: selectedFinca != null ? (Bloque? newValue) {
                        setModalState(() {
                          _editBloque = newValue;
                          _editVariedad = null; // Resetear variedad al cambiar bloque
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
                    
                    SizedBox(height: 16),
                    
                    // Variedad
                    DropdownButtonFormField<Variedad>(
                      decoration: InputDecoration(
                        labelText: 'Variedad',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
                      ),
                      value: _editVariedad,
                      onChanged: _editBloque != null ? (Variedad? newValue) {
                        setModalState(() {
                          _editVariedad = newValue;
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
                    // Validar campos obligatorios
                    if (_editSupervisorController.text.trim().isEmpty || 
                        _editCuadranteController.text.trim().isEmpty) {
                      Fluttertoast.showToast(
                        msg: 'Supervisor y Cuadrante son obligatorios',
                        backgroundColor: Colors.orange[600],
                        textColor: Colors.white,
                      );
                      return;
                    }
                    
                                         // Crear nueva clave si cambió supervisor, bloque o cuadrante (debe coincidir con CuadranteLaboresInfo.claveUnica)
                     String nuevaClave = '${_editSupervisorController.text.trim()}_${_editBloque?.nombre ?? ''}_${_editCuadranteController.text.trim()}';
                    
                    // Si la clave cambió, verificar que no exista
                    if (nuevaClave != clave && matrizLabores.containsKey(nuevaClave)) {
                      Fluttertoast.showToast(
                        msg: 'Ya existe una fila con ese supervisor y cuadrante',
                        backgroundColor: Colors.orange[600],
                        textColor: Colors.white,
                      );
                      return;
                    }
                    
                    // Actualizar la matriz
                    setState(() {
                      // Si la clave cambió, eliminar la antigua y crear la nueva
                      if (nuevaClave != clave) {
                        var paradas = matrizLabores[clave]!['paradas'];
                        matrizLabores.remove(clave);
                        matrizLabores[nuevaClave] = {
                          'supervisor': _editSupervisorController.text.trim(),
                          'bloque': _editBloque,
                          'variedad': _editVariedad,
                          'cuadrante': _editCuadranteController.text.trim(),
                          'paradas': paradas,
                        };
                      } else {
                        // Actualizar en la misma clave
                        matrizLabores[clave]!['supervisor'] = _editSupervisorController.text.trim();
                        matrizLabores[clave]!['bloque'] = _editBloque;
                        matrizLabores[clave]!['variedad'] = _editVariedad;
                        matrizLabores[clave]!['cuadrante'] = _editCuadranteController.text.trim();
                      }
                    });
                    
                    Navigator.of(context).pop();
                    
                    Fluttertoast.showToast(
                      msg: 'Fila actualizada exitosamente',
                      backgroundColor: Colors.green[600],
                      textColor: Colors.white,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editarParada(String clave, int parada) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              title: Text('Editar Parada $parada'),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      'Seleccione los items conformes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: laboresPermanentes.length,
                        itemBuilder: (context, index) {
                          int itemId = index + 1;
                          String itemNombre = laboresPermanentes[index];
                          String? resultadoActual = matrizLabores[clave]?['paradas']?[parada]?[itemId];
                          bool isConforme = resultadoActual == '1' || resultadoActual?.toLowerCase() == 'c';
                          
                          return CheckboxListTile(
                            title: Text(
                              '${itemId}. $itemNombre',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: isConforme,
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  matrizLabores[clave]!['paradas'][parada][itemId] = '1';
                                } else {
                                  matrizLabores[clave]!['paradas'][parada][itemId] = null;
                                }
                              });
                              // También actualizar el estado principal
                              setState(() {});
                            },
                          );
                        },
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
            );
          },
        );
      },
    );
  }

  Widget _buildResumenEstadisticas() {
    if (matrizLabores.isEmpty) return SizedBox.shrink();

    // Nueva lógica de contadores
    // - 100% cuando nada está marcado
    // - Al marcar cualquier ítem, baja el % de cumplimiento
    // - "Conformes" = no marcados; "No Conformes" = marcados
    final int totalFilas = matrizLabores.length;
    final int totalParadas = totalFilas * 5;
    final int itemsPorParada = laboresPermanentes.length;
    final int totalSlots = totalParadas * itemsPorParada;

    int marcados = 0;
    matrizLabores.forEach((_, data) {
      final Map<int, Map<int, String?>> paradas = data['paradas'];
      paradas.forEach((_, items) {
        items.forEach((_, resultado) {
          if (resultado != null && resultado.trim().isNotEmpty) {
            marcados++;
          }
        });
      });
    });

    final int conformes = totalSlots - marcados; // no marcados
    final int noConformes = marcados;            // marcados
    final double porcentajeGeneral = totalSlots > 0
        ? (conformes / totalSlots) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen de Evaluación',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple[700],
          ),
        ),
        SizedBox(height: 12),
        
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.deepPurple[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard('Filas', '$totalFilas', Colors.blue),
              _buildStatCard('Paradas', '$totalParadas', Colors.orange),
              _buildStatCard('Total Ítems', '$totalSlots', Colors.green),
              _buildStatCard('Conformes', '$conformes', Colors.green),
              _buildStatCard('No Conformes', '$noConformes', Colors.red),
              _buildStatCard('% Cumplimiento', '${porcentajeGeneral.toStringAsFixed(1)}%', Colors.deepPurple),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // Lista de ítems de control como referencia
        Text(
          'Ítems de Control (12):',
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
            spacing: 6,
            runSpacing: 4,
            children: laboresPermanentes.asMap().entries.map((entry) => 
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple[300]!),
                ),
                child: Text(
                  '${entry.key + 1}. ${entry.value}',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.deepPurple[700],
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
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
                    builder: (context) => ChecklistLaboresPermanentesRecordsScreen(),
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
    // Verificar que se haya seleccionado finca y usuario
    if (selectedFinca == null || selectedUsuario == null) {
      return false;
    }
    
    // Verificar que haya filas en la matriz
    if (matrizLabores.isEmpty) {
      return false;
    }
    
    // En modo edición, permitir guardar si hay datos existentes
    if (_isEditMode) {
      return true;
    }
    
    // En modo creación, verificar que todas las filas tengan bloque y variedad seleccionados
    for (var data in matrizLabores.values) {
      if (data['bloque'] == null || data['variedad'] == null) {
        return false;
      }
    }
    
    return true;
  }

  Future<void> _saveChecklist() async {
    if (!_canSave()) return;

    try {
      // Convertir la matriz a la estructura del checklist
      List<CuadranteLaboresInfo> cuadrantes = [];
      List<ChecklistLaboresPermanentesItem> items = [];
      
      // Preparar items de control con resultados existentes
      for (int itemId = 1; itemId <= laboresPermanentes.length; itemId++) {
        var item = ChecklistLaboresPermanentesItem(
          id: itemId,
          proceso: laboresPermanentes[itemId - 1],
          resultadosPorCuadranteParada: {},
        );
        
        // Cargar resultados existentes para este item desde la matriz
        matrizLabores.forEach((clave, data) {
          Map<int, Map<int, String?>> paradas = data['paradas'];
          for (int parada = 1; parada <= 5; parada++) {
            String? resultado = paradas[parada]?[itemId];
            if (resultado != null && resultado.trim().isNotEmpty) {
              item.setResultado(clave, parada, resultado);
            }
          }
        });
        
        items.add(item);
      }

      // Procesar matriz y extraer datos de cuadrantes
      matrizLabores.forEach((clave, data) {
        String supervisor = data['supervisor'];
        String bloque = data['bloque']?.nombre ?? '';
        String? variedad = data['variedad']?.nombre;
        String cuadrante = data['cuadrante'] ?? '';
        
        // Agregar cuadrante
        cuadrantes.add(CuadranteLaboresInfo(
          supervisor: supervisor,
          bloque: bloque,
          variedad: variedad,
          cuadrante: cuadrante,
        ));
      });

      // Crear checklist actualizado
      checklist = ChecklistLaboresPermanentes(
        id: checklist.id,
        fecha: selectedDate,
        finca: selectedFinca,
        up: selectedFinca?.nombre,
        semana: _semanaController.text.trim().isEmpty ? null : _semanaController.text.trim(),
        kontroller: selectedUsuario?.nombre ?? 'Usuario no identificado',
        cuadrantes: cuadrantes,
        items: items,
        porcentajeCumplimiento: _calcularPorcentajeGeneral(),
        observacionesGenerales: _observacionesController.text.trim().isEmpty ? null : _observacionesController.text.trim(),
      );

      int? savedId;
      if (_isEditMode) {
        await ChecklistLaboresPermanentesStorageService.updateChecklist(checklist);
        savedId = checklist.id;
      } else {
        savedId = await ChecklistLaboresPermanentesStorageService.saveChecklist(checklist);
      }

      Fluttertoast.showToast(
        msg: _isEditMode ? 'Checklist actualizado exitosamente' : 'Checklist guardado exitosamente',
        backgroundColor: Colors.green[600],
        textColor: Colors.white,
      );

      Navigator.pop(context, savedId);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error guardando checklist: $e',
        backgroundColor: Colors.red[600],
        textColor: Colors.white,
      );
    }
  }

  double _calcularPorcentajeGeneral() {
    // 100% si nada está marcado; baja al marcar
    int filas = matrizLabores.length;
    if (filas == 0) return 0.0;
    final int itemsPorParada = laboresPermanentes.length;
    final int paradasPorFila = 5;
    final int totalSlots = filas * paradasPorFila * itemsPorParada;

    int marcados = 0;
    matrizLabores.forEach((clave, data) {
      final Map<int, Map<int, String?>> paradas = data['paradas'];
      paradas.forEach((_, items) {
        items.forEach((_, resultado) {
          if (resultado != null && resultado.trim().isNotEmpty) {
            marcados++;
          }
        });
      });
    });

    final int noMarcados = totalSlots - marcados;
    return totalSlots > 0 ? (noMarcados / totalSlots) * 100 : 0.0;
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
        title: Text('Labores Permanentes'),
        backgroundColor: Colors.deepPurple[700],
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
                        Text('CHECK LIST LABORES CULTURALES PERMANENTE ', 
                             style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 8),
                        
                        SizedBox(height: 12),
                        Text('Instrucciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('1. Complete información general (Semana, Kontroller)'),
                        Text('2. Seleccione fecha y finca'),
                        Text('3. Agregue filas: supervisor, bloque, variedad, cuadrante'),
                        Text('4. Evalúe cada parada (1-5) para cada ítem (1-16)'),
                        Text('5. Use 1 para Conforme, 0 para No Conforme'),
                        Text('6. Agregue observaciones si necesario'),
                        Text('7. Guarde cuando termine'),
                        SizedBox(height: 12),
                        Text('Estructura:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• Cada fila = Supervisor + Bloque + Cuadrante'),
                        Text('• 5 paradas por fila'),
                        Text('• 16 ítems de control por parada'),
                        Text('• Valores: 1=Conforme, 0=No Conforme'),
                        SizedBox(height: 12),
                        Text('16 Ítems de Control:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          height: 200,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: laboresPermanentes.asMap().entries.map((entry) => 
                                Text('${entry.key + 1}. ${entry.value}', style: TextStyle(fontSize: 11))
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
                  CircularProgressIndicator(color: Colors.deepPurple[600]),
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
                  _buildMatrizLabores(),
                  SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
      ),
    );
  }
}