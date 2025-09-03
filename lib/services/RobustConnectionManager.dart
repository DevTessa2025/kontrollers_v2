import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sql_server_service.dart';
import 'auth_service.dart';

// ==================== GESTOR DE CONECTIVIDAD ROBUSTO ====================

class RobustConnectionManager {
  static const int MAX_RETRIES = 5;
  static const Duration BASE_TIMEOUT = Duration(seconds: 20);  // Aumentado para dispositivos físicos
  static const Duration MAX_TIMEOUT = Duration(seconds: 90);   // Aumentado para mayor tolerancia
  static const Duration INITIAL_RETRY_DELAY = Duration(seconds: 3);  // Aumentado delay inicial
  static const Duration MAX_RETRY_DELAY = Duration(seconds: 20);     // Aumentado delay máximo
  
  static int _consecutiveFailures = 0;
  static DateTime? _lastFailureTime;
  static bool _isServerDown = false;
  static Duration _currentTimeout = BASE_TIMEOUT;
  
  // Circuit breaker pattern
  static const int CIRCUIT_BREAKER_THRESHOLD = 5;
  static const Duration CIRCUIT_BREAKER_RESET_TIME = Duration(minutes: 5);
  
  // Verificar si el circuit breaker está abierto
  static bool _isCircuitBreakerOpen() {
    if (_consecutiveFailures >= CIRCUIT_BREAKER_THRESHOLD) {
      if (_lastFailureTime != null) {
        Duration timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
        if (timeSinceLastFailure < CIRCUIT_BREAKER_RESET_TIME) {
          return true;
        } else {
          // Reset circuit breaker después del tiempo de espera
          _consecutiveFailures = 0;
          _isServerDown = false;
          _currentTimeout = BASE_TIMEOUT;
          print('Circuit breaker reset - reintentando conexiones');
        }
      }
    }
    return false;
  }
  
  // Registrar fallo de conexión
  static void _recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    
    // Incrementar timeout dinámicamente
    if (_currentTimeout < MAX_TIMEOUT) {
      _currentTimeout = Duration(
        seconds: min(MAX_TIMEOUT.inSeconds, _currentTimeout.inSeconds + 5)
      );
    }
    
    if (_consecutiveFailures >= CIRCUIT_BREAKER_THRESHOLD) {
      _isServerDown = true;
      print('Circuit breaker activado - servidor marcado como no disponible');
    }
  }
  
  // Registrar éxito de conexión
  static void _recordSuccess() {
    _consecutiveFailures = 0;
    _isServerDown = false;
    _currentTimeout = BASE_TIMEOUT;
    _lastFailureTime = null;
  }
  
  // Verificar conectividad de red básica
  static Future<bool> checkNetworkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('Sin conectividad de red');
        return false;
      }
      
      // Verificar conectividad real haciendo ping a un servidor confiable
      final result = await InternetAddress.lookup('google.com').timeout(
        Duration(seconds: 5),
      );
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Conectividad de red confirmada');
        return true;
      }
      
      print('No se pudo verificar conectividad de internet');
      return false;
    } catch (e) {
      print('Error verificando conectividad de red: $e');
      return false;
    }
  }
  
  // Verificar si el servidor SQL específico está alcanzable
  static Future<bool> checkServerReachability() async {
    try {
      print('Verificando alcance del servidor SQL...');
      
      // Intentar resolver DNS del servidor
      final result = await InternetAddress.lookup('181.198.42.194').timeout(
        Duration(seconds: 8),
      );
      
      if (result.isNotEmpty) {
        print('Servidor SQL es alcanzable por DNS');
        
        // Intentar conexión TCP al puerto específico
        Socket? socket;
        try {
          socket = await Socket.connect(
            '181.198.42.194', 
            5010,
            timeout: Duration(seconds: 20),  // Aumentado para dispositivos físicos
          );
          print('Puerto 5010 está abierto en el servidor');
          await socket.close();
          return true;
        } catch (e) {
          print('Puerto 5010 no está accesible: $e');
          return false;
        }
      }
      
      print('Servidor SQL no es alcanzable');
      return false;
    } catch (e) {
      print('Error verificando alcance del servidor SQL: $e');
      return false;
    }
  }
  
  // Ejecutar operación con manejo robusto de errores
  static Future<T> executeRobustOperation<T>(
    Future<T> Function() operation,
    {
      String operationName = 'SQL Operation',
      T? fallbackValue,
    }
  ) async {
    // Verificar circuit breaker
    if (_isCircuitBreakerOpen()) {
      print('Circuit breaker abierto - operación rechazada: $operationName');
      if (fallbackValue != null) {
        return fallbackValue;
      }
      throw Exception('Servidor no disponible (Circuit Breaker abierto)');
    }
    
    for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        print('Ejecutando $operationName - Intento $attempt/$MAX_RETRIES');
        
        // Verificar red antes del intento
        if (attempt > 1) {
          bool networkOk = await checkNetworkConnectivity();
          if (!networkOk) {
            print('Sin conectividad de red - saltando intento $attempt');
            await _waitBeforeRetry(attempt);
            continue;
          }
          
          bool serverOk = await checkServerReachability();
          if (!serverOk) {
            print('Servidor SQL no alcanzable - saltando intento $attempt');
            await _waitBeforeRetry(attempt);
            continue;
          }
        }
        
        // Ejecutar operación con timeout dinámico
        T result = await operation().timeout(_currentTimeout);
        
        // Operación exitosa
        _recordSuccess();
        print('$operationName completada exitosamente en intento $attempt');
        return result;
        
      } on TimeoutException catch (e) {
        print('Timeout en $operationName (intento $attempt): ${_currentTimeout.inSeconds}s');
        _recordFailure();
        
        if (attempt == MAX_RETRIES) {
          if (fallbackValue != null) {
            print('Usando valor fallback para $operationName');
            return fallbackValue;
          }
          throw Exception('Timeout después de $MAX_RETRIES intentos: $operationName');
        }
        
      } on SocketException catch (e) {
        print('Error de red en $operationName (intento $attempt): $e');
        _recordFailure();
        
        if (attempt == MAX_RETRIES) {
          if (fallbackValue != null) {
            print('Usando valor fallback para $operationName después de errores de red');
            return fallbackValue;
          }
          throw Exception('Error de conectividad después de $MAX_RETRIES intentos: $operationName');
        }
        
      } catch (e) {
        print('Error general en $operationName (intento $attempt): $e');
        
        // Para errores no relacionados con conectividad, fallar inmediatamente
        if (!_isNetworkError(e)) {
          if (fallbackValue != null) {
            return fallbackValue;
          }
          rethrow;
        }
        
        _recordFailure();
        
        if (attempt == MAX_RETRIES) {
          if (fallbackValue != null) {
            print('Usando valor fallback para $operationName después de errores diversos');
            return fallbackValue;
          }
          rethrow;
        }
      }
      
      // Esperar antes del siguiente intento
      if (attempt < MAX_RETRIES) {
        await _waitBeforeRetry(attempt);
      }
    }
    
    // Esto no debería alcanzarse nunca
    if (fallbackValue != null) {
      return fallbackValue;
    }
    throw Exception('Fallo después de todos los intentos: $operationName');
  }
  
  // Determinar si un error es relacionado con la red
  static bool _isNetworkError(dynamic error) {
    String errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
           errorStr.contains('connection') ||
           errorStr.contains('timeout') ||
           errorStr.contains('socket') ||
           errorStr.contains('failed to connect') ||
           errorStr.contains('no route to host') ||
           errorStr.contains('connection refused');
  }
  
  // Esperar antes del siguiente intento con backoff exponencial + jitter
  static Future<void> _waitBeforeRetry(int attempt) async {
    // Backoff exponencial: 2s, 4s, 8s, 15s, 15s
    int baseDelay = min(
      INITIAL_RETRY_DELAY.inSeconds * (1 << (attempt - 1)),
      MAX_RETRY_DELAY.inSeconds,
    );
    
    // Agregar jitter aleatorio (±25%)
    int jitter = (baseDelay * 0.25 * (Random().nextDouble() * 2 - 1)).round();
    int totalDelay = baseDelay + jitter;
    
    print('Esperando ${totalDelay}s antes del siguiente intento...');
    await Future.delayed(Duration(seconds: totalDelay));
  }
  
  // Obtener estado actual del gestor
  static Map<String, dynamic> getStatus() {
    return {
      'consecutive_failures': _consecutiveFailures,
      'is_server_down': _isServerDown,
      'current_timeout_seconds': _currentTimeout.inSeconds,
      'circuit_breaker_open': _isCircuitBreakerOpen(),
      'last_failure_time': _lastFailureTime?.toIso8601String(),
      'next_circuit_reset': _lastFailureTime != null
          ? _lastFailureTime!.add(CIRCUIT_BREAKER_RESET_TIME).toIso8601String()
          : null,
    };
  }
  
  // Reset manual del gestor
  static void reset() {
    _consecutiveFailures = 0;
    _lastFailureTime = null;
    _isServerDown = false;
    _currentTimeout = BASE_TIMEOUT;
    print('RobustConnectionManager reseteado manualmente');
  }
}

// ==================== SERVICIO SQL ROBUSTO ====================

class RobustSqlServerService {
  
  // Wrapper robusto para executeQuery
  static Future<String> executeQueryRobust(String query, {String? operationName}) async {
    return await RobustConnectionManager.executeRobustOperation<String>(
      () async {
        return await SqlServerService.executeQuery(query);
      },
      operationName: operationName ?? 'SQL Query',
      fallbackValue: '[]', // JSON vacío como fallback
    );
  }
  
  // Wrapper robusto para obtener usuarios
  static Future<List<Map<String, dynamic>>> getUsersFromServerRobust() async {
    return await RobustConnectionManager.executeRobustOperation<List<Map<String, dynamic>>>(
      () async {
        return await SqlServerService.getUsersFromServer();
      },
      operationName: 'Get Users',
      fallbackValue: [], // Lista vacía como fallback
    );
  }
  
  // Wrapper robusto para autenticación
  static Future<Map<String, dynamic>?> authenticateUserRobust(String username, String password) async {
    return await RobustConnectionManager.executeRobustOperation<Map<String, dynamic>?>(
      () async {
        return await SqlServerService.authenticateUser(username, password);
      },
      operationName: 'User Authentication',
      fallbackValue: null, // null como fallback para autenticación fallida
    );
  }
  
  // Verificar salud del servidor con diagnóstico completo
  static Future<Map<String, dynamic>> performHealthCheck() async {
    Map<String, dynamic> healthStatus = {
      'timestamp': DateTime.now().toIso8601String(),
      'overall_status': 'unknown',
    };
    
    try {
      // Verificar conectividad de red
      bool networkOk = await RobustConnectionManager.checkNetworkConnectivity();
      healthStatus['network_connectivity'] = networkOk;
      
      if (!networkOk) {
        healthStatus['overall_status'] = 'network_error';
        healthStatus['message'] = 'Sin conectividad de red';
        return healthStatus;
      }
      
      // Verificar alcance del servidor
      bool serverReachable = await RobustConnectionManager.checkServerReachability();
      healthStatus['server_reachable'] = serverReachable;
      
      if (!serverReachable) {
        healthStatus['overall_status'] = 'server_unreachable';
        healthStatus['message'] = 'Servidor SQL no alcanzable';
        return healthStatus;
      }
      
      // Intentar consulta simple
      try {
        String result = await executeQueryRobust('SELECT GETDATE() as server_time', operationName: 'Health Check');
        List<Map<String, dynamic>> data = SqlServerService.processQueryResult(result);
        
        if (data.isNotEmpty) {
          healthStatus['sql_server_status'] = 'operational';
          healthStatus['server_time'] = data.first['server_time'];
          healthStatus['overall_status'] = 'healthy';
          healthStatus['message'] = 'Todos los servicios funcionando correctamente';
        } else {
          healthStatus['sql_server_status'] = 'responding_but_empty';
          healthStatus['overall_status'] = 'degraded';
          healthStatus['message'] = 'Servidor responde pero sin datos';
        }
      } catch (e) {
        healthStatus['sql_server_status'] = 'error';
        healthStatus['sql_error'] = e.toString();
        healthStatus['overall_status'] = 'sql_error';
        healthStatus['message'] = 'Error ejecutando consultas SQL';
      }
      
    } catch (e) {
      healthStatus['overall_status'] = 'error';
      healthStatus['error'] = e.toString();
      healthStatus['message'] = 'Error durante verificación de salud';
    }
    
    // Agregar estado del connection manager
    healthStatus['connection_manager'] = RobustConnectionManager.getStatus();
    
    return healthStatus;
  }
}

// ==================== SERVICIO DE SINCRONIZACIÓN INTELIGENTE ====================

class IntelligentSyncService {
  
  // Sincronización inteligente que se adapta a las condiciones de red
  static Future<Map<String, dynamic>> performIntelligentSync() async {
    print('Iniciando sincronización inteligente...');
    
    Map<String, dynamic> result = {
      'timestamp': DateTime.now().toIso8601String(),
      'sync_status': 'unknown',
      'synced_items': 0,
      'errors': <String>[],
      'warnings': <String>[],
    };
    
    try {
      // Verificar estado de salud antes de sincronizar
      Map<String, dynamic> health = await RobustSqlServerService.performHealthCheck();
      result['health_check'] = health;
      
      if (health['overall_status'] != 'healthy') {
        result['sync_status'] = 'skipped_unhealthy';
        result['message'] = 'Sincronización omitida - servidor no saludable: ${health['message']}';
        return result;
      }
      
      // Realizar sincronización por partes
      int totalSynced = 0;
      List<String> errors = [];
      
      // Sincronizar usuarios
      try {
        List<Map<String, dynamic>> users = await RobustSqlServerService.getUsersFromServerRobust();
        totalSynced += users.length;
        print('Usuarios sincronizados: ${users.length}');
      } catch (e) {
        errors.add('Usuarios: $e');
        result['warnings'].add('Fallo sincronización de usuarios');
      }
      
      // Agregar más sincronizaciones según necesites...
      
      result['synced_items'] = totalSynced;
      result['errors'] = errors;
      
      if (errors.isEmpty) {
        result['sync_status'] = 'success';
        result['message'] = 'Sincronización completada exitosamente';
      } else {
        result['sync_status'] = 'partial';
        result['message'] = 'Sincronización parcial con algunos errores';
      }
      
    } catch (e) {
      result['sync_status'] = 'failed';
      result['error'] = e.toString();
      result['message'] = 'Sincronización falló completamente';
    }
    
    return result;
  }
  
  // Sincronización en segundo plano con reintento automático
  static Future<void> startBackgroundSync() async {
    Timer.periodic(Duration(minutes: 15), (timer) async {
      try {
        print('Ejecutando sincronización automática en segundo plano...');
        Map<String, dynamic> result = await performIntelligentSync();
        print('Sincronización automática completada: ${result['sync_status']}');
      } catch (e) {
        print('Error en sincronización automática: $e');
      }
    });
  }
}

// ==================== EJEMPLO DE USO EN TU APLICACIÓN ====================

/*
// Reemplaza tus llamadas actuales:

// En lugar de:
// String result = await RobustSqlServerService.executeQueryRobust(
  query, 
  operationName: 'Get Fincas Aplicaciones'
);

// Usar:
String result = await RobustSqlServerService.executeQueryRobust(query, operationName: 'Get Fincas');

// En lugar de tu sincronización actual:
// syncData();

// Usar:
Map<String, dynamic> syncResult = await IntelligentSyncService.performIntelligentSync();
print('Resultado de sincronización: ${syncResult['message']}');

// Para verificar estado del servidor:
Map<String, dynamic> health = await RobustSqlServerService.performHealthCheck();
print('Estado del servidor: ${health['overall_status']}');

// Para obtener estado del connection manager:
Map<String, dynamic> status = RobustConnectionManager.getStatus();
print('Estado del gestor de conexiones: $status');

// Para reset manual en caso de problemas:
RobustConnectionManager.reset();
*/