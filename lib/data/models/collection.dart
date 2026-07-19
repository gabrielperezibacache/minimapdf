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

  factory Collection.fromMap(Map<String, Object?> map) {
    final createdRaw = map['created_at'];
    final createdAt = createdRaw is String && createdRaw.isNotEmpty
        ? (DateTime.tryParse(createdRaw) ??
            DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Collection(
      id: map['id'] as int?,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Colección',
      createdAt: createdAt,
    );
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
