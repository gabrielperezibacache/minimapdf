import 'dart:convert';

/// Libro/PDF almacenado en la biblioteca local.
class Book {
  const Book({
    this.id,
    required this.title,
    required this.filePath,
    required this.fileSize,
    required this.addedAt,
    this.lastReadAt,
    this.lastPageRead = 0,
    this.author,
    this.tags = const [],
    this.collectionId,
  });

  final int? id;
  final String title;
  final String filePath;
  final int fileSize;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final int lastPageRead;
  final String? author;
  final List<String> tags;
  final int? collectionId;

  Book copyWith({
    int? id,
    String? title,
    String? filePath,
    int? fileSize,
    DateTime? addedAt,
    DateTime? lastReadAt,
    int? lastPageRead,
    String? author,
    List<String>? tags,
    int? collectionId,
    bool clearAuthor = false,
    bool clearLastReadAt = false,
    bool clearCollectionId = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: clearLastReadAt ? null : (lastReadAt ?? this.lastReadAt),
      lastPageRead: lastPageRead ?? this.lastPageRead,
      author: clearAuthor ? null : (author ?? this.author),
      tags: tags ?? this.tags,
      collectionId:
          clearCollectionId ? null : (collectionId ?? this.collectionId),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'file_path': filePath,
      'file_size': fileSize,
      'added_at': addedAt.toIso8601String(),
      'last_read_at': lastReadAt?.toIso8601String(),
      'last_page_read': lastPageRead,
      'author': author,
      'tags': jsonEncode(tags),
      'collection_id': collectionId,
    };
  }

  /// Parseo estricto; lanza si faltan título o ruta.
  factory Book.fromMap(Map<String, Object?> map) {
    final book = Book.tryFromMap(map);
    if (book == null) {
      throw FormatException('Invalid or corrupt book row');
    }
    return book;
  }

  /// Parseo tolerante: filas corruptas → null (no tumba la biblioteca).
  static Book? tryFromMap(Map<String, Object?> map) {
    try {
      final title = _asNonEmptyString(map['title']);
      final filePath = _asNonEmptyString(map['file_path']);
      if (title == null || filePath == null) return null;

      final addedAt = _asDateTime(map['added_at']);
      if (addedAt == null) return null;

      return Book(
        id: _asInt(map['id']),
        title: title,
        filePath: filePath,
        fileSize: _asInt(map['file_size']) ?? 0,
        addedAt: addedAt,
        lastReadAt: _asDateTime(map['last_read_at']),
        lastPageRead: _asInt(map['last_page_read']) ?? 0,
        author: _asNullableString(map['author']),
        tags: _parseTags(map['tags']),
        collectionId: _asInt(map['collection_id']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Coincide con búsqueda por título, autor o etiquetas.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    final a = author;
    if (a != null && a.toLowerCase().contains(q)) return true;
    for (final tag in tags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  static List<String> _parseTags(Object? rawTags) {
    if (rawTags is! String || rawTags.isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawTags);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {
      // Tags corruptos → lista vacía.
    }
    return const [];
  }

  static String? _asNonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _asNullableString(Object? value) {
    if (value == null) return null;
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
    return other is Book &&
        other.id == id &&
        other.title == title &&
        other.filePath == filePath &&
        other.fileSize == fileSize &&
        other.addedAt == addedAt &&
        other.lastReadAt == lastReadAt &&
        other.lastPageRead == lastPageRead &&
        other.author == author &&
        _listEquals(other.tags, tags) &&
        other.collectionId == collectionId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        filePath,
        fileSize,
        addedAt,
        lastReadAt,
        lastPageRead,
        author,
        Object.hashAll(tags),
        collectionId,
      );
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
