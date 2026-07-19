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

  factory Book.fromMap(Map<String, Object?> map) {
    final rawTags = map['tags'];
    List<String> tags = const [];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          tags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // Tags corruptos no deben tumbar toda la biblioteca.
        tags = const [];
      }
    }

    final addedRaw = map['added_at'];
    final addedAt = addedRaw is String && addedRaw.isNotEmpty
        ? (DateTime.tryParse(addedRaw) ?? DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);

    DateTime? lastReadAt;
    final lastReadRaw = map['last_read_at'];
    if (lastReadRaw is String && lastReadRaw.isNotEmpty) {
      lastReadAt = DateTime.tryParse(lastReadRaw);
    }

    final fileSizeRaw = map['file_size'];
    final fileSize = fileSizeRaw is int
        ? fileSizeRaw
        : int.tryParse('$fileSizeRaw') ?? 0;

    final pageRaw = map['last_page_read'];
    final lastPageRead = pageRaw is int
        ? pageRaw
        : int.tryParse('$pageRaw') ?? 0;

    return Book(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? 'Sin título',
      filePath: (map['file_path'] as String?) ?? '',
      fileSize: fileSize,
      addedAt: addedAt,
      lastReadAt: lastReadAt,
      lastPageRead: lastPageRead < 0 ? 0 : lastPageRead,
      author: map['author'] as String?,
      tags: tags,
      collectionId: map['collection_id'] as int?,
    );
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
