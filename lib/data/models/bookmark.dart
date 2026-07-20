/// Marcador o nota asociada a una página de un libro.
class Bookmark {
  const Bookmark({
    this.id,
    required this.bookId,
    required this.pageNumber,
    this.noteText,
    required this.createdAt,
  });

  final int? id;
  final int bookId;
  final int pageNumber;
  final String? noteText;
  final DateTime createdAt;

  Bookmark copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? noteText,
    DateTime? createdAt,
    bool clearNoteText = false,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      noteText: clearNoteText ? null : (noteText ?? this.noteText),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'page_number': pageNumber,
      'note_text': noteText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Parseo estricto; lanza si faltan campos obligatorios.
  factory Bookmark.fromMap(Map<String, Object?> map) {
    final bookmark = Bookmark.tryFromMap(map);
    if (bookmark == null) {
      throw FormatException('Fila de marcador inválida o corrupta');
    }
    return bookmark;
  }

  /// Parseo tolerante: filas corruptas → null.
  static Bookmark? tryFromMap(Map<String, Object?> map) {
    try {
      final bookId = _asInt(map['book_id']);
      if (bookId == null || bookId < 1) return null;

      final pageNumber = _asInt(map['page_number']);
      if (pageNumber == null || pageNumber < 1) return null;

      final createdAt = _asDateTime(map['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return Bookmark(
        id: _asInt(map['id']),
        bookId: bookId,
        pageNumber: pageNumber,
        noteText: _asNullableString(map['note_text']),
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

  static String? _asNullableString(Object? value) {
    if (value == null) return null;
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  @override
  bool operator ==(Object other) {
    return other is Bookmark &&
        other.id == id &&
        other.bookId == bookId &&
        other.pageNumber == pageNumber &&
        other.noteText == noteText &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, pageNumber, noteText, createdAt);
}
