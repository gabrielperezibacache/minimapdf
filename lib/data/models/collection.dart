/// Carpeta/colección de la biblioteca local.
class Collection {
  const Collection({
    this.id,
    required this.name,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final DateTime createdAt;

  Collection copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Parseo estricto; lanza si la fila es inválida.
  factory Collection.fromMap(Map<String, Object?> map) {
    final collection = Collection.tryFromMap(map);
    if (collection == null) {
      throw FormatException('Fila de colección inválida o corrupta');
    }
    return collection;
  }

  /// Parseo tolerante: filas corruptas → null.
  static Collection? tryFromMap(Map<String, Object?> map) {
    try {
      final id = _asInt(map['id']);
      final nameRaw = map['name'];
      if (nameRaw is! String) return null;
      final name = nameRaw.trim();
      if (name.isEmpty) return null;

      final createdAt = _asDateTime(map['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return Collection(
        id: id,
        name: name,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  @override
  bool operator ==(Object other) {
    return other is Collection &&
        other.id == id &&
        other.name == name &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
}
