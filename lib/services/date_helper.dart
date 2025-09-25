class DateHelper {
  /// Formatea una fecha para SQL Server usando CONVERT con estilo 126 (ISO 8601)
  /// Más robusto para fechas con zona horaria
  static String formatForSqlServer(DateTime? date) {
    if (date == null) return 'GETDATE()';
    try {
      // Usar CONVERT con estilo 126 (ISO 8601) para mayor compatibilidad
      final iso = date.toIso8601String();
      final trimmed = iso.length >= 19 ? iso.substring(0, 19) : iso;
      return "CONVERT(DATETIME2, '${trimmed.replaceAll('T', ' ')}', 126)";
    } catch (e) {
      print('[DateHelper] Error formateando fecha: $e');
      return 'GETDATE()';
    }
  }

  /// Formatea una fecha para SQL Server usando CONVERT con estilo 126 (ISO 8601)
  /// Más robusto para fechas con zona horaria
  static String formatForSqlServerWithConvert(DateTime? date) {
    if (date == null) return 'GETDATE()';
    try {
      final iso = date.toIso8601String();
      final trimmed = iso.length >= 19 ? iso.substring(0, 19) : iso;
      return "CONVERT(DATETIME2, '$trimmed', 126)";
    } catch (e) {
      print('[DateHelper] Error formateando fecha con CONVERT: $e');
      return 'GETDATE()';
    }
  }

  /// Obtiene la fecha actual formateada para SQL Server
  static String getCurrentDateForSqlServer() {
    return formatForSqlServer(DateTime.now());
  }

  /// Valida si una fecha es válida para SQL Server
  static bool isValidForSqlServer(DateTime? date) {
    if (date == null) return false;
    try {
      // SQL Server acepta fechas desde 1753-01-01 hasta 9999-12-31
      final minDate = DateTime(1753, 1, 1);
      final maxDate = DateTime(9999, 12, 31);
      return date.isAfter(minDate.subtract(const Duration(days: 1))) && 
             date.isBefore(maxDate.add(const Duration(days: 1)));
    } catch (e) {
      return false;
    }
  }

  /// Método de debug para probar formatos de fecha
  static void debugDateFormat(DateTime? date) {
    if (date == null) {
      print('🔍 DEBUG FECHA - Fecha es null');
      return;
    }
    
    print('🔍 DEBUG FECHA - Fecha original: $date');
    print('🔍 DEBUG FECHA - ISO String: ${date.toIso8601String()}');
    print('🔍 DEBUG FECHA - Formato SQL Server: ${formatForSqlServer(date)}');
    print('🔍 DEBUG FECHA - Es válida: ${isValidForSqlServer(date)}');
  }

  /// Método de debug para probar parsing de fechas desde string
  static void debugDateString(String dateString) {
    print('🔍 DEBUG FECHA STRING - Input: $dateString');
    try {
      DateTime parsed = DateTime.parse(dateString);
      print('🔍 DEBUG FECHA STRING - Parsed successfully: $parsed');
      print('🔍 DEBUG FECHA STRING - Formatted: ${formatForSqlServer(parsed)}');
    } catch (e) {
      print('🔍 DEBUG FECHA STRING - Error parsing: $e');
    }
  }
}
