import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// ==================== OPTIMIZADOR PARA DISPOSITIVOS FÍSICOS ====================

class PhysicalDeviceOptimizer {
  static bool _isPhysicalDevice = false;
  static bool _isInitialized = false;
  
  // Configuraciones específicas para dispositivos físicos
  static const Duration PHYSICAL_DEVICE_TIMEOUT = Duration(seconds: 45);
  static const Duration PHYSICAL_DEVICE_RETRY_DELAY = Duration(seconds: 5);
  static const int PHYSICAL_DEVICE_MAX_RETRIES = 4;
  
  // Configuraciones para emulador
  static const Duration EMULATOR_TIMEOUT = Duration(seconds: 15);
  static const Duration EMULATOR_RETRY_DELAY = Duration(seconds: 1);
  static const int EMULATOR_MAX_RETRIES = 2;
  
  // Inicializar el optimizador
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isPhysicalDevice = await _detectPhysicalDevice();
    _isInitialized = true;
    
    print('PhysicalDeviceOptimizer inicializado - Dispositivo físico: $_isPhysicalDevice');
  }
  
  // Detectar si es dispositivo físico
  static Future<bool> _detectPhysicalDevice() async {
    try {
      // Verificar si estamos en modo debug (emulador)
      if (kDebugMode) {
        // Verificar conectividad específica del emulador
        var connectivityResult = await Connectivity().checkConnectivity();
        
        // El emulador típicamente usa WiFi
        if (connectivityResult == ConnectivityResult.wifi) {
          // Verificar si es la IP del emulador
          try {
            final result = await InternetAddress.lookup('10.0.2.2').timeout(
              Duration(seconds: 2),
            );
            if (result.isNotEmpty) {
              print('Detectado emulador Android');
              return false;
            }
          } catch (e) {
            // No es emulador
          }
        }
      }
      
      // Verificar características específicas de dispositivos físicos
      try {
        // Intentar acceder a características que solo existen en dispositivos físicos
        final result = await InternetAddress.lookup('8.8.8.8').timeout(
          Duration(seconds: 5),
        );
        
        // Si podemos resolver DNS externo, probablemente es dispositivo físico
        if (result.isNotEmpty) {
          print('Detectado dispositivo físico');
          return true;
        }
      } catch (e) {
        print('Error detectando tipo de dispositivo: $e');
      }
      
      // Por defecto, asumir dispositivo físico
      return true;
    } catch (e) {
      print('Error en detección de dispositivo: $e');
      return true; // Por defecto, asumir dispositivo físico
    }
  }
  
  // Obtener timeout apropiado según el tipo de dispositivo
  static Duration getConnectionTimeout() {
    return _isPhysicalDevice ? PHYSICAL_DEVICE_TIMEOUT : EMULATOR_TIMEOUT;
  }
  
  // Obtener delay de reintento apropiado
  static Duration getRetryDelay() {
    return _isPhysicalDevice ? PHYSICAL_DEVICE_RETRY_DELAY : EMULATOR_RETRY_DELAY;
  }
  
  // Obtener número máximo de reintentos
  static int getMaxRetries() {
    return _isPhysicalDevice ? PHYSICAL_DEVICE_MAX_RETRIES : EMULATOR_MAX_RETRIES;
  }
  
  // Verificar conectividad optimizada para el tipo de dispositivo
  static Future<bool> checkOptimizedConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // Para dispositivos físicos, hacer verificación más robusta
      if (_isPhysicalDevice) {
        // Verificar múltiples servidores DNS
        List<String> dnsServers = ['8.8.8.8', '1.1.1.1', '208.67.222.222'];
        
        for (String dns in dnsServers) {
          try {
            final result = await InternetAddress.lookup(dns).timeout(
              Duration(seconds: 3),
            );
            if (result.isNotEmpty) {
              print('Conectividad confirmada con DNS: $dns');
              return true;
            }
          } catch (e) {
            continue;
          }
        }
        
        return false;
      } else {
        // Para emulador, verificación más simple
        final result = await InternetAddress.lookup('google.com').timeout(
          Duration(seconds: 5),
        );
        return result.isNotEmpty;
      }
    } catch (e) {
      print('Error verificando conectividad optimizada: $e');
      return false;
    }
  }
  
  // Ejecutar operación con configuración optimizada
  static Future<T> executeOptimizedOperation<T>(
    Future<T> Function() operation, {
    String operationName = 'Operation',
    T? fallbackValue,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final maxRetries = getMaxRetries();
    final retryDelay = getRetryDelay();
    final timeout = getConnectionTimeout();
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('$operationName - Intento $attempt/$maxRetries (${_isPhysicalDevice ? 'Físico' : 'Emulador'})');
        
        // Verificar conectividad antes del intento
        if (attempt > 1) {
          bool hasConnectivity = await checkOptimizedConnectivity();
          if (!hasConnectivity) {
            print('Sin conectividad - esperando antes del reintento');
            await Future.delayed(retryDelay);
            continue;
          }
        }
        
        // Ejecutar operación con timeout apropiado
        T result = await operation().timeout(timeout);
        
        print('$operationName completada exitosamente en intento $attempt');
        return result;
        
      } on TimeoutException catch (e) {
        print('Timeout en $operationName (intento $attempt): ${timeout.inSeconds}s');
        
        if (attempt == maxRetries) {
          if (fallbackValue != null) {
            print('Usando valor fallback para $operationName');
            return fallbackValue;
          }
          throw Exception('Timeout después de $maxRetries intentos: $operationName');
        }
        
        // Esperar antes del siguiente intento
        await Future.delayed(retryDelay);
        
      } catch (e) {
        print('Error en $operationName (intento $attempt): $e');
        
        if (attempt == maxRetries) {
          if (fallbackValue != null) {
            print('Usando valor fallback para $operationName');
            return fallbackValue;
          }
          rethrow;
        }
        
        // Esperar antes del siguiente intento
        await Future.delayed(retryDelay);
      }
    }
    
    throw Exception('Operación falló después de $maxRetries intentos');
  }
  
  // Obtener información de diagnóstico
  static Map<String, dynamic> getDiagnosticInfo() {
    return {
      'is_physical_device': _isPhysicalDevice,
      'is_initialized': _isInitialized,
      'connection_timeout': getConnectionTimeout().inSeconds,
      'retry_delay': getRetryDelay().inSeconds,
      'max_retries': getMaxRetries(),
    };
  }
}
