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
    final bookIdRaw = map['book_id'];
    final bookId = bookIdRaw is int
        ? bookIdRaw
        : int.tryParse('$bookIdRaw') ?? 0;

    final pageRaw = map['page_number'];
    final pageNumber = pageRaw is int
        ? pageRaw
        : int.tryParse('$pageRaw') ?? 1;

    final createdRaw = map['created_at'];
    final createdAt = createdRaw is String && createdRaw.isNotEmpty
        ? (DateTime.tryParse(createdRaw) ??
            DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Bookmark(
      id: map['id'] as int?,
      bookId: bookId,
      pageNumber: pageNumber < 1 ? 1 : pageNumber,
      noteText: map['note_text'] as String?,
      createdAt: createdAt,
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
