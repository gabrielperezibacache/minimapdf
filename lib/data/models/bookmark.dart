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

  factory Bookmark.fromMap(Map<String, Object?> map) {
    return Bookmark(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      pageNumber: map['page_number'] as int,
      noteText: map['note_text'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
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
