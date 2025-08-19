import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _hasAdminPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminPermissions();
  }

  Future<void> _checkAdminPermissions() async {
    bool isAdmin = await AdminService.isCurrentUserAdmin();
    setState(() {
      _hasAdminPermissions = isAdmin;
      _isLoading = false;
    });

    if (!isAdmin) {
      // Si no es admin, regresar después de 2 segundos
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Verificando permisos...'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red[700]),
              SizedBox(height: 16),
              Text('Validando acceso...'),
            ],
          ),
        ),
      );
    }

    if (!_hasAdminPermissions) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Acceso Denegado'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 80,
                color: Colors.red[300],
              ),
              SizedBox(height: 20),
              Text(
                'No tienes permisos de administrador',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Contacta al administrador del sistema',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 30),
              Text(
                'Regresando automáticamente...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Administración'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red[700]!,
              Colors.red[50]!,
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con información del admin
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings, 
                          color: Colors.red[700], 
                          size: 32
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Panel de Administración',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Acceso completo a registros del sistema',
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
                
                SizedBox(height: 32),
                
                Text(
                  'Registros de Checklists',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                SizedBox(height: 8),
                
                Text(
                  'Selecciona el tipo de checklist para ver sus registros',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Grid de botones para cada tipo de checklist
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildChecklistCard(
                        title: 'Fertirriego',
                        subtitle: 'Sistema de riego',
                        icon: Icons.water_drop,
                        color: Colors.blue,
                        count: null,
                        onTap: () => _navigateToRecords('fertirriego'),
                      ),
                      _buildChecklistCard(
                        title: 'Bodega',
                        subtitle: 'Almacenamiento',
                        icon: Icons.warehouse,
                        color: Colors.orange,
                        count: null,
                        onTap: () => _navigateToRecords('bodega'),
                      ),
                      _buildChecklistCard(
                        title: 'Aplicaciones',
                        subtitle: 'Productos químicos',
                        icon: Icons.science,
                        color: Colors.green,
                        count: null,
                        onTap: () => _navigateToRecords('aplicaciones'),
                      ),
                      _buildChecklistCard(
                        title: 'Cosechas',
                        subtitle: 'Recolección',
                        icon: Icons.agriculture,
                        color: Colors.purple,
                        count: null,
                        onTap: () => _navigateToRecords('cosecha'),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Información adicional
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Información importante',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Los datos se consultan directamente del servidor. Requiere conexión a internet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildChecklistCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    int? count,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (count != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count registros',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRecords(String checklistType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistRecordsScreen(checklistType: checklistType),
      ),
    );
  }
}

// ==================== PANTALLA DE REGISTROS ====================

class ChecklistRecordsScreen extends StatefulWidget {
  final String checklistType;

  ChecklistRecordsScreen({required this.checklistType});

  @override
  _ChecklistRecordsScreenState createState() => _ChecklistRecordsScreenState();
}

class _ChecklistRecordsScreenState extends State<ChecklistRecordsScreen> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _users = [];
  List<String> _fincas = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showFilters = false;
  
  // Filtros
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  int? _selectedUserId;
  String? _selectedFinca;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadUsers();
    await _loadFincas();
    await _loadRecords();
  }

  Future<void> _loadUsers() async {
    try {
      List<Map<String, dynamic>> users = await AdminService.getAllUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      print('Error cargando usuarios: $e');
    }
  }

  Future<void> _loadFincas() async {
    try {
      List<String> fincas = await AdminService.getAllFincas();
      setState(() {
        _fincas = fincas;
      });
    } catch (e) {
      print('Error cargando fincas: $e');
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      Map<String, dynamic> result;
      
      switch (widget.checklistType) {
        case 'fertirriego':
          result = await AdminService.getFertiriegoRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'bodega':
          result = await AdminService.getBodegaRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'aplicaciones':
          result = await AdminService.getAplicacionesRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        case 'cosecha':
          result = await AdminService.getCosechasRecords(
            fechaInicio: _fechaInicio,
            fechaFin: _fechaFin,
            usuarioId: _selectedUserId,
            fincaNombre: _selectedFinca,
          );
          break;
        default:
          throw Exception('Tipo de checklist no válido');
      }

      setState(() {
        _records = result['records'] ?? [];
        _statistics = result['statistics'] ?? {};
        _isLoading = false;
        _hasError = !result['success'];
        _errorMessage = result['error'] ?? '';
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_getChecklistTitle()} - Registros'),
        backgroundColor: _getChecklistColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getChecklistColor(),
              Colors.grey[50]!,
            ],
            stops: [0.0, 0.2],
          ),
        ),
        child: Column(
          children: [
            // Panel de filtros (desplegable)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              height: _showFilters ? null : 0,
              child: _showFilters ? _buildFiltersPanel() : Container(),
            ),
            
            // Estadísticas
            if (_statistics.isNotEmpty && !_isLoading) _buildStatistics(),
            
            // Lista de registros
            Expanded(
              child: _buildRecordsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: _getChecklistColor()),
              SizedBox(width: 8),
              Text(
                'Filtros de búsqueda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Filtros de fecha
          Row(
            children: [
              Expanded(
                child: _buildDateFilter(
                  label: 'Fecha inicio',
                  date: _fechaInicio,
                  onTap: () => _selectDate(context, true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDateFilter(
                  label: 'Fecha fin',
                  date: _fechaFin,
                  onTap: () => _selectDate(context, false),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Filtros de usuario y finca
          Row(
            children: [
              Expanded(
                child: _buildDropdownFilter<int>(
                  label: 'Usuario',
                  value: _selectedUserId,
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('Todos los usuarios'),
                    ),
                    ..._users.map((user) => DropdownMenuItem<int>(
                      value: user['id'],
                      child: Text(user['nombre'] ?? user['username']),
                    )).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                    });
                    _loadRecords();
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildDropdownFilter<String>(
                  label: 'Finca',
                  value: _selectedFinca,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Todas las fincas'),
                    ),
                    ..._fincas.map((finca) => DropdownMenuItem<String>(
                      value: finca,
                      child: Text(finca),
                    )).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFinca = value;
                    });
                    _loadRecords();
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Botones de acción
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: Icon(Icons.clear_all),
                label: Text('Limpiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadRecords,
                  icon: Icon(Icons.search),
                  label: Text('Aplicar filtros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getChecklistColor(),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null 
                    ? DateFormat('dd/MM/yyyy').format(date)
                    : label,
                style: TextStyle(
                  color: date != null ? Colors.black : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            if (date != null)
              InkWell(
                onTap: () {
                  setState(() {
                    if (label.contains('inicio')) {
                      _fechaInicio = null;
                    } else {
                      _fechaFin = null;
                    }
                  });
                  _loadRecords();
                },
                child: Icon(Icons.clear, size: 16, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildStatistics() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: _getChecklistColor()),
              SizedBox(width: 8),
              Text(
                'Estadísticas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Registros',
                  _statistics['total_registros']?.toString() ?? '0',
                  Icons.list_alt,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Promedio',
                  '${(_statistics['promedio_cumplimiento']?.toStringAsFixed(1) ?? '0')}%',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Usuarios',
                  _statistics['total_usuarios']?.toString() ?? '0',
                  Icons.people,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Fincas',
                  _statistics['total_fincas']?.toString() ?? '0',
                  Icons.location_on,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _getChecklistColor()),
            SizedBox(height: 16),
            Text(
              'Cargando registros...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              SizedBox(height: 16),
              Text(
                'Error al cargar registros',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRecords,
                icon: Icon(Icons.refresh),
                label: Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getChecklistColor(),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No se encontraron registros',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Intenta ajustar los filtros de búsqueda',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: Icon(Icons.clear_all),
                label: Text('Limpiar filtros'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return _buildRecordCard(record);
      },
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 4,
      child: InkWell(
        onTap: () => _showRecordDetail(record),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getCumplimientoColor(record['porcentaje_cumplimiento']).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con ID y porcentaje
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getChecklistColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'ID ${record['id']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getChecklistColor(),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getCumplimientoColor(record['porcentaje_cumplimiento']).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCumplimientoIcon(record['porcentaje_cumplimiento']),
                            size: 14,
                            color: _getCumplimientoColor(record['porcentaje_cumplimiento']),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${record['porcentaje_cumplimiento']?.toStringAsFixed(1) ?? '0'}%',
                            style: TextStyle(
                              color: _getCumplimientoColor(record['porcentaje_cumplimiento']),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Información principal
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record['usuario_nombre'] ?? 'Usuario ${record['usuario_id']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 6),
                
                if (record['finca_nombre'] != null)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          record['finca_nombre'],
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                
                if (record['bloque_nombre'] != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.grid_view, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bloque: ${record['bloque_nombre']}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
                
                if (record['bomba_nombre'] != null) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.build, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bomba: ${record['bomba_nombre']}',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
                
                SizedBox(height: 12),
                
                // Fechas
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Creado: ${_formatDate(record['fecha_creacion'])}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload, size: 12, color: Colors.grey[500]),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Enviado: ${_formatDate(record['fecha_envio'])}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 8),
                
                // Indicador de "Ver más"
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Toca para ver detalles',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getChecklistColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: _getChecklistColor(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCumplimientoColor(dynamic porcentaje) {
    if (porcentaje == null) return Colors.grey;
    double value = porcentaje.toDouble();
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getCumplimientoIcon(dynamic porcentaje) {
    if (porcentaje == null) return Icons.help_outline;
    double value = porcentaje.toDouble();
    if (value >= 80) return Icons.check_circle;
    if (value >= 60) return Icons.warning;
    return Icons.error;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate 
          ? (_fechaInicio ?? DateTime.now().subtract(Duration(days: 30)))
          : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
      _loadRecords();
    }
  }

  void _clearFilters() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _selectedUserId = null;
      _selectedFinca = null;
    });
    _loadRecords();
  }

  void _showRecordDetail(Map<String, dynamic> record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordDetailScreen(
          record: record,
          checklistType: widget.checklistType,
        ),
      ),
    );
  }

  String _getChecklistTitle() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return 'Fertirriego';
      case 'bodega':
        return 'Bodega';
      case 'aplicaciones':
        return 'Aplicaciones';
      case 'cosecha':
        return 'Cosecha';
      default:
        return widget.checklistType;
    }
  }

  Color _getChecklistColor() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Colors.blue[700]!;
      case 'bodega':
        return Colors.orange[700]!;
      case 'aplicaciones':
        return Colors.green[700]!;
      case 'cosecha':
        return Colors.purple[700]!;
      default:
        return Colors.red[700]!;
    }
  }
}

// ==================== PANTALLA DE DETALLE DE REGISTRO ====================

class RecordDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;
  final String checklistType;

  RecordDetailScreen({required this.record, required this.checklistType});

  @override
  _RecordDetailScreenState createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  Map<String, dynamic>? _fullRecord;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFullRecord();
  }

  Future<void> _loadFullRecord() async {
    try {
      String tableName = 'check_${widget.checklistType}';
      Map<String, dynamic>? fullRecord = await AdminService.getRecordDetail(
        tableName, 
        widget.record['id']
      );
      
      setState(() {
        _fullRecord = fullRecord;
        _isLoading = false;
        _hasError = fullRecord == null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle - ID ${widget.record['id']}'),
        backgroundColor: _getChecklistColor(),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // TODO: Implementar compartir detalles
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getChecklistColor(),
              Colors.grey[50]!,
            ],
            stops: [0.0, 0.2],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState()
            : _hasError
                ? _buildErrorState()
                : _buildDetailContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _getChecklistColor()),
            SizedBox(height: 16),
            Text(
              'Cargando detalles...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              'Error cargando detalles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No se pudieron cargar los detalles del registro',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadFullRecord,
              icon: Icon(Icons.refresh),
              label: Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getChecklistColor(),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent() {
    if (_fullRecord == null) return Container();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información general
          _buildInfoCard(),
          SizedBox(height: 16),
          
          // Items del checklist
          _buildItemsSection(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 8,
      shadowColor: _getChecklistColor().withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getChecklistColor().withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getChecklistColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: _getChecklistColor(),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Información General',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              _buildInfoRow('ID', _fullRecord!['id'].toString()),
              _buildInfoRow('UUID', _fullRecord!['checklist_uuid'] ?? 'N/A'),
              _buildInfoRow('Usuario', _fullRecord!['usuario_nombre'] ?? 'N/A'),
              _buildInfoRow('Finca', _fullRecord!['finca_nombre'] ?? 'N/A'),
              
              if (_fullRecord!['bloque_nombre'] != null)
                _buildInfoRow('Bloque', _fullRecord!['bloque_nombre']),
              if (_fullRecord!['bomba_nombre'] != null)
                _buildInfoRow('Bomba', _fullRecord!['bomba_nombre']),
                
              _buildInfoRow('Fecha Creación', _formatDetailDate(_fullRecord!['fecha_creacion'])),
              _buildInfoRow('Fecha Envío', _formatDetailDate(_fullRecord!['fecha_envio'])),
              
              // Cumplimiento con estilo especial
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getCumplimientoColor(_fullRecord!['porcentaje_cumplimiento']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getCumplimientoColor(_fullRecord!['porcentaje_cumplimiento']).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCumplimientoIcon(_fullRecord!['porcentaje_cumplimiento']),
                      color: _getCumplimientoColor(_fullRecord!['porcentaje_cumplimiento']),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cumplimiento:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_fullRecord!['porcentaje_cumplimiento']?.toStringAsFixed(1) ?? '0'}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getCumplimientoColor(_fullRecord!['porcentaje_cumplimiento']),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    List<Widget> itemWidgets = [];
    
    // Buscar todos los items en el registro
    for (int i = 1; i <= 50; i++) {
      if (_fullRecord!.containsKey('item_${i}_respuesta')) {
        String? respuesta = _fullRecord!['item_${i}_respuesta'];
        int? valorNumerico = _fullRecord!['item_${i}_valor_numerico'];
        String? observaciones = _fullRecord!['item_${i}_observaciones'];
        String? fotoBase64 = _fullRecord!['item_${i}_foto_base64'];
        
        if (respuesta != null || valorNumerico != null || 
            (observaciones != null && observaciones.isNotEmpty) || 
            (fotoBase64 != null && fotoBase64.isNotEmpty)) {
          itemWidgets.add(_buildItemCard(i, respuesta, valorNumerico, observaciones, fotoBase64));
        }
      }
    }
    
    if (itemWidgets.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                SizedBox(height: 12),
                Text(
                  'No se encontraron items completados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getChecklistColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.checklist,
                    color: _getChecklistColor(),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Items del Checklist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getChecklistColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${itemWidgets.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getChecklistColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12),
        ...itemWidgets,
      ],
    );
  }

  Widget _buildItemCard(int itemNumber, String? respuesta, int? valorNumerico, String? observaciones, String? fotoBase64) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getRespuestaColor(respuesta).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getChecklistColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Item $itemNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getChecklistColor(),
                      ),
                    ),
                  ),
                  Spacer(),
                  if (respuesta != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRespuestaColor(respuesta).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRespuestaIcon(respuesta),
                            size: 12,
                            color: _getRespuestaColor(respuesta),
                          ),
                          SizedBox(width: 4),
                          Text(
                            respuesta.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getRespuestaColor(respuesta),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              if (valorNumerico != null || 
                  (observaciones != null && observaciones.isNotEmpty) ||
                  (fotoBase64 != null && fotoBase64.isNotEmpty)) ...[
                SizedBox(height: 12),
                
                if (valorNumerico != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.straighten, size: 16, color: Colors.blue[600]),
                        SizedBox(width: 6),
                        Text(
                          'Valor: $valorNumerico',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (valorNumerico != null && observaciones != null && observaciones.isNotEmpty)
                  SizedBox(height: 8),
                
                if (observaciones != null && observaciones.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note, size: 16, color: Colors.orange[600]),
                            SizedBox(width: 6),
                            Text(
                              'Observaciones:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          observaciones,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (fotoBase64 != null && fotoBase64.isNotEmpty) ...[
                  if ((valorNumerico != null) || (observaciones != null && observaciones.isNotEmpty))
                    SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.photo_camera, size: 16, color: Colors.green[600]),
                        SizedBox(width: 6),
                        Text(
                          'Foto adjunta',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.visibility, size: 14, color: Colors.green[600]),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getRespuestaColor(String? respuesta) {
    if (respuesta == null) return Colors.grey;
    switch (respuesta.toLowerCase()) {
      case 'si':
        return Colors.green;
      case 'no':
        return Colors.red;
      case 'na':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRespuestaIcon(String? respuesta) {
    if (respuesta == null) return Icons.help_outline;
    switch (respuesta.toLowerCase()) {
      case 'si':
        return Icons.check_circle;
      case 'no':
        return Icons.cancel;
      case 'na':
        return Icons.remove_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _getCumplimientoColor(dynamic porcentaje) {
    if (porcentaje == null) return Colors.grey;
    double value = porcentaje.toDouble();
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getCumplimientoIcon(dynamic porcentaje) {
    if (porcentaje == null) return Icons.help_outline;
    double value = porcentaje.toDouble();
    if (value >= 80) return Icons.check_circle;
    if (value >= 60) return Icons.warning;
    return Icons.error;
  }

  String _formatDetailDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy - HH:mm:ss').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getChecklistColor() {
    switch (widget.checklistType) {
      case 'fertirriego':
        return Colors.blue[700]!;
      case 'bodega':
        return Colors.orange[700]!;
      case 'aplicaciones':
        return Colors.green[700]!;
      case 'cosecha':
        return Colors.purple[700]!;
      default:
        return Colors.red[700]!;
    }
  }
}