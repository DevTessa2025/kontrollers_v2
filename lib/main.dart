import 'package:flutter/material.dart';
import 'package:kontrollers_v2/screens/admin_screen.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/checklist_fertirriego_screen.dart';
import 'services/PhysicalDeviceOptimizer.dart';
import 'database/database_helper.dart';

void main() async {
  // Inicializar el optimizador para dispositivos físicos
  await PhysicalDeviceOptimizer.initialize();
  
  // Inicializar la base de datos
  try {
    DatabaseHelper dbHelper = DatabaseHelper();
    await dbHelper.database; // Esto creará la base de datos si no existe
    print('Base de datos inicializada correctamente');
  } catch (e) {
    print('Error inicializando base de datos: $e');
  }
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeAuthListeners();
  }

  void _initializeAuthListeners() {
    // Configurar listeners del AuthService para manejar cambios de estado
    AuthService.setAuthStateListeners(
      onAuthStateChanged: (bool isLoggedIn) {
        print('Estado de autenticación cambió: $isLoggedIn');
        
        // Navegar según el estado de autenticación
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentState != null) {
            if (isLoggedIn) {
              navigatorKey.currentState!.pushNamedAndRemoveUntil(
                '/home',
                (route) => false,
              );
            } else {
              navigatorKey.currentState!.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          }
        });
      },
      onForceLogout: () {
        print('Logout forzado detectado');
        
        // Mostrar diálogo específico para logout forzado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentContext != null) {
            _showForceLogoutDialog();
          }
        });
      },
    );
  }

  void _showForceLogoutDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sesión Expirada'),
          ],
        ),
        content: Text(
          'Tu sesión ha expirado o tu cuenta ha sido desactivada. '
          'Por favor, inicia sesión nuevamente.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kontrollers App',
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: Colors.red[700],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          primary: Colors.red[700]!,
          secondary: Colors.red[600]!,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: SplashScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/checklist_fertirriego': (context) => ChecklistFertiriegoScreen(),
        '/admin': (context) => AdminScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      setState(() {
        _statusMessage = 'Inicializando...';
      });
      
      // Simular carga inicial
      await Future.delayed(Duration(seconds: 1));
      
      setState(() {
        _statusMessage = 'Verificando sesión...';
      });
      
      bool isLoggedIn = await AuthService.isLoggedIn();
      
      if (isLoggedIn) {
        print('Usuario con sesión activa, validando estado...');
        
        setState(() {
          _statusMessage = 'Validando usuario...';
        });
        
        // Validar si el usuario sigue activo
        Map<String, dynamic> validationResult = await AuthService.forceValidateActiveUser();
        
        print('Resultado de validación: ${validationResult['valid']}');
        print('Mensaje: ${validationResult['message']}');
        
        bool isUserValid = validationResult['valid'] == true;
        
        if (mounted) {
          // Pequeña pausa para mostrar el resultado
          await Future.delayed(Duration(milliseconds: 500));
          
          if (isUserValid) {
            setState(() {
              _statusMessage = 'Acceso autorizado';
            });
            
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            setState(() {
              _statusMessage = 'Sesión inválida';
            });
            
            // Mostrar mensaje antes de ir al login
            await Future.delayed(Duration(seconds: 1));
            Navigator.pushReplacementNamed(context, '/login');
          }
        }
      } else {
        print('No hay sesión activa, ir al login');
        
        setState(() {
          _statusMessage = 'Sin sesión activa';
        });
        
        await Future.delayed(Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error durante la verificación de login: $e');
      
      setState(() {
        _statusMessage = 'Error de conexión';
      });
      
      await Future.delayed(Duration(seconds: 1));
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[700],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset( 
                'assets/images/Tessa_logo.jpg',
                width: 100,
                height: 100,
              ),
            ),
            
            SizedBox(height: 32),
            
            Text(
              'KONTROLLERS',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            SizedBox(height: 8),
            
            Text(
              'Sistema de Gestión Agrícola',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            
            SizedBox(height: 48),
            
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            
            SizedBox(height: 16),
            
            // Mensaje de estado dinámico
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para mostrar estado de validación (opcional)
class AuthValidationStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AuthService.getValidationInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        
        Map<String, dynamic> info = snapshot.data!;
        bool needsValidation = info['needsValidation'] ?? false;
        int? hoursAgo = info['hoursAgo'];
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: needsValidation ? Colors.orange[100] : Colors.green[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: needsValidation ? Colors.orange : Colors.green,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                needsValidation ? Icons.schedule : Icons.verified_user,
                color: needsValidation ? Colors.orange[700] : Colors.green[700],
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                hoursAgo != null 
                  ? (needsValidation 
                      ? 'Validar en servidor' 
                      : 'Validado hace ${hoursAgo}h')
                  : 'Sin validar',
                style: TextStyle(
                  fontSize: 12,
                  color: needsValidation ? Colors.orange[700] : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}