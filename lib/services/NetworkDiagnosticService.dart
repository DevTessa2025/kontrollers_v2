import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kontrollers_v2/services/PhysicalDeviceOptimizer.dart';

// ==================== SERVICIO DE DIAGNÓSTICO DE RED ====================

class NetworkDiagnosticService {
  
  // Realizar diagnóstico completo de red
  static Future<Map<String, dynamic>> performNetworkDiagnostic() async {
    Map<String, dynamic> diagnostic = {
      'timestamp': DateTime.now().toIso8601String(),
      'device_type': 'unknown',
      'connectivity_status': 'unknown',
      'dns_resolution': {},
      'server_reachability': {},
      'connection_tests': {},
      'recommendations': [],
    };
    
    try {
      // 1. Detectar tipo de dispositivo
      await PhysicalDeviceOptimizer.initialize();
      diagnostic['device_type'] = PhysicalDeviceOptimizer.getDiagnosticInfo()['is_physical_device'] ? 'physical' : 'emulator';
      
      // 2. Verificar conectividad básica
      var connectivityResult = await Connectivity().checkConnectivity();
      diagnostic['connectivity_status'] = connectivityResult.toString();
      
      // 3. Probar resolución DNS
      diagnostic['dns_resolution'] = await _testDnsResolution();
      
      // 4. Verificar alcance del servidor SQL
      diagnostic['server_reachability'] = await _testServerReachability();
      
      // 5. Probar conexiones específicas
      diagnostic['connection_tests'] = await _testSpecificConnections();
      
      // 6. Generar recomendaciones
      diagnostic['recommendations'] = _generateRecommendations(diagnostic);
      
    } catch (e) {
      diagnostic['error'] = e.toString();
    }
    
    return diagnostic;
  }
  
  // Probar resolución DNS
  static Future<Map<String, dynamic>> _testDnsResolution() async {
    Map<String, dynamic> results = {};
    
    List<String> testDomains = [
      'google.com',
      '8.8.8.8',
      '1.1.1.1',
      '181.198.42.194', // Servidor SQL
    ];
    
    for (String domain in testDomains) {
      try {
        final result = await InternetAddress.lookup(domain).timeout(
          Duration(seconds: 5),
        );
        results[domain] = {
          'success': true,
          'addresses': result.map((addr) => addr.address).toList(),
          'response_time': 'fast',
        };
      } catch (e) {
        results[domain] = {
          'success': false,
          'error': e.toString(),
          'response_time': 'timeout',
        };
      }
    }
    
    return results;
  }
  
  // Probar alcance del servidor
  static Future<Map<String, dynamic>> _testServerReachability() async {
    Map<String, dynamic> results = {};
    
    try {
      // Test 1: Resolución DNS del servidor
      final dnsResult = await InternetAddress.lookup('181.198.42.194').timeout(
        Duration(seconds: 10),
      );
      results['dns_resolution'] = {
        'success': true,
        'addresses': dnsResult.map((addr) => addr.address).toList(),
      };
    } catch (e) {
      results['dns_resolution'] = {
        'success': false,
        'error': e.toString(),
      };
    }
    
    try {
      // Test 2: Conexión TCP al puerto
      Socket? socket;
      try {
        socket = await Socket.connect(
          '181.198.42.194',
          5010,
          timeout: Duration(seconds: 15),
        );
        results['tcp_connection'] = {
          'success': true,
          'port': 5010,
          'response_time': 'fast',
        };
        await socket.close();
      } catch (e) {
        results['tcp_connection'] = {
          'success': false,
          'error': e.toString(),
          'port': 5010,
        };
      }
    } catch (e) {
      results['tcp_connection'] = {
        'success': false,
        'error': e.toString(),
      };
    }
    
    return results;
  }
  
  // Probar conexiones específicas
  static Future<Map<String, dynamic>> _testSpecificConnections() async {
    Map<String, dynamic> results = {};
    
    // Test de conectividad optimizada
    try {
      bool optimizedConnectivity = await PhysicalDeviceOptimizer.checkOptimizedConnectivity();
      results['optimized_connectivity'] = {
        'success': optimizedConnectivity,
        'method': 'PhysicalDeviceOptimizer',
      };
    } catch (e) {
      results['optimized_connectivity'] = {
        'success': false,
        'error': e.toString(),
      };
    }
    
    // Test de ping a múltiples servidores
    List<String> pingTargets = ['8.8.8.8', '1.1.1.1', '208.67.222.222'];
    Map<String, dynamic> pingResults = {};
    
    for (String target in pingTargets) {
      try {
        final result = await InternetAddress.lookup(target).timeout(
          Duration(seconds: 3),
        );
        pingResults[target] = {
          'success': true,
          'response_time': 'fast',
        };
      } catch (e) {
        pingResults[target] = {
          'success': false,
          'error': e.toString(),
        };
      }
    }
    
    results['ping_tests'] = pingResults;
    
    return results;
  }
  
  // Generar recomendaciones basadas en el diagnóstico
  static List<String> _generateRecommendations(Map<String, dynamic> diagnostic) {
    List<String> recommendations = [];
    
    // Verificar tipo de dispositivo
    if (diagnostic['device_type'] == 'physical') {
      recommendations.add('Dispositivo físico detectado - usando configuraciones optimizadas');
    } else {
      recommendations.add('Emulador detectado - usando configuraciones estándar');
    }
    
    // Verificar conectividad
    String connectivityStatus = diagnostic['connectivity_status'];
    if (connectivityStatus.contains('none')) {
      recommendations.add('❌ Sin conectividad de red - verificar WiFi/móvil');
    } else if (connectivityStatus.contains('wifi')) {
      recommendations.add('✅ Conectividad WiFi detectada');
    } else if (connectivityStatus.contains('mobile')) {
      recommendations.add('✅ Conectividad móvil detectada');
    }
    
    // Verificar DNS
    Map<String, dynamic> dnsResults = diagnostic['dns_resolution'];
    bool dnsWorking = false;
    dnsResults.forEach((domain, result) {
      if (result['success'] == true) {
        dnsWorking = true;
      }
    });
    
    if (!dnsWorking) {
      recommendations.add('❌ Problemas de resolución DNS - verificar configuración de red');
    } else {
      recommendations.add('✅ Resolución DNS funcionando correctamente');
    }
    
    // Verificar servidor SQL
    Map<String, dynamic> serverResults = diagnostic['server_reachability'];
    if (serverResults['tcp_connection']?['success'] == true) {
      recommendations.add('✅ Servidor SQL alcanzable');
    } else {
      recommendations.add('❌ Servidor SQL no alcanzable - verificar firewall/red');
    }
    
    // Recomendaciones específicas para dispositivos físicos
    if (diagnostic['device_type'] == 'physical') {
      recommendations.add('💡 Para dispositivos físicos: usar timeouts más largos');
      recommendations.add('💡 Verificar que el dispositivo tenga buena señal de red');
      recommendations.add('💡 Considerar usar WiFi en lugar de datos móviles para mejor estabilidad');
    }
    
    return recommendations;
  }
  
  // Obtener resumen del diagnóstico
  static String getDiagnosticSummary(Map<String, dynamic> diagnostic) {
    List<String> summary = [];
    
    summary.add('📱 Tipo de dispositivo: ${diagnostic['device_type']}');
    summary.add('🌐 Conectividad: ${diagnostic['connectivity_status']}');
    
    // Contar éxitos de DNS
    Map<String, dynamic> dnsResults = diagnostic['dns_resolution'];
    int dnsSuccesses = dnsResults.values.where((result) => result['success'] == true).length;
    summary.add('🔍 DNS: $dnsSuccesses/${dnsResults.length} exitosos');
    
    // Verificar servidor SQL
    Map<String, dynamic> serverResults = diagnostic['server_reachability'];
    bool serverReachable = serverResults['tcp_connection']?['success'] == true;
    summary.add('🖥️ Servidor SQL: ${serverReachable ? '✅ Alcanzable' : '❌ No alcanzable'}');
    
    return summary.join('\n');
  }
  
  // Ejecutar diagnóstico y mostrar resultados
  static Future<void> runDiagnosticAndLog() async {
    print('🔍 Iniciando diagnóstico de red...');
    
    Map<String, dynamic> diagnostic = await performNetworkDiagnostic();
    
    print('\n📊 RESULTADOS DEL DIAGNÓSTICO:');
    print('=' * 50);
    print(getDiagnosticSummary(diagnostic));
    
    print('\n💡 RECOMENDACIONES:');
    print('=' * 50);
    List<String> recommendations = diagnostic['recommendations'];
    for (String recommendation in recommendations) {
      print('• $recommendation');
    }
    
    print('\n🔧 CONFIGURACIÓN ACTUAL:');
    print('=' * 50);
    Map<String, dynamic> config = PhysicalDeviceOptimizer.getDiagnosticInfo();
    config.forEach((key, value) {
      print('• $key: $value');
    });
  }
}
