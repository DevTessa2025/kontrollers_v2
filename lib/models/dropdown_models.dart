class Supervisor {
  final int id;
  final String nombre;
  final String? cedula;
  final bool activo;

  Supervisor({
    required this.id,
    required this.nombre,
    this.cedula,
    this.activo = true,
  });

  factory Supervisor.fromJson(Map<String, dynamic> json) {
    return Supervisor(
      id: json['id'],
      nombre: json['nombre'],
      cedula: json['cedula'],
      activo: json['activo'] == 1 || json['activo'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'cedula': cedula,
      'activo': activo,
    };
  }

  @override
  String toString() => nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supervisor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Pesador {
  final int id;
  final String nombre;
  final String? cedula;
  final bool activo;

  Pesador({
    required this.id,
    required this.nombre,
    this.cedula,
    this.activo = true,
  });

  factory Pesador.fromJson(Map<String, dynamic> json) {
    return Pesador(
      id: json['id'],
      nombre: json['nombre'],
      cedula: json['cedula'],
      activo: json['activo'] == 1 || json['activo'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'cedula': cedula,
      'activo': activo,
    };
  }

  @override
  String toString() => nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pesador && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Finca {
  final String nombre;

  Finca({
    required this.nombre,
  });

  factory Finca.fromJson(Map<String, dynamic> json) {
    return Finca(
      nombre: json['finca'] ?? json['LOCALIDAD'] ?? json['nombre'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
    };
  }

  @override
  String toString() => nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Finca && runtimeType == other.runtimeType && nombre == other.nombre;

  @override
  int get hashCode => nombre.hashCode;
}

class Bloque {
  final String nombre;
  final String? finca;

  Bloque({
    required this.nombre,
    this.finca,
  });

  factory Bloque.fromJson(Map<String, dynamic> json) {
    return Bloque(
      nombre: _convertToString(json['nombre'] ?? json['BLOCK']) ?? '',
      finca: json['finca'] ?? json['LOCALIDAD'],
    );
  }

  // Método helper para convertir cualquier tipo a String
  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) return value.toInt().toString();
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'finca': finca,
    };
  }

  @override
  String toString() => nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bloque && runtimeType == other.runtimeType && nombre == other.nombre;

  @override
  int get hashCode => nombre.hashCode;
}

class Variedad {
  final String nombre;
  final String? finca;
  final String? bloque;

  Variedad({
    required this.nombre,
    this.finca,
    this.bloque,
  });

  factory Variedad.fromJson(Map<String, dynamic> json) {
    return Variedad(
      nombre: json['nombre'] ?? json['PRODUCTO'],
      finca: json['finca'] ?? json['LOCALIDAD'],
      bloque: _convertToString(json['bloque'] ?? json['BLOCK']),
    );
  }

  // Método helper para convertir cualquier tipo a String
  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) return value.toInt().toString();
    return value.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'finca': finca,
      'bloque': bloque,
    };
  }

  @override
  String toString() => nombre;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Variedad && runtimeType == other.runtimeType && nombre == other.nombre;

  @override
  int get hashCode => nombre.hashCode;
}