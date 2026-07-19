import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/data/models/models.dart';

void main() {
  group('Book serialization', () {
    test('round-trip toMap/fromMap preserva tags y nulos', () {
      final book = Book(
        id: 7,
        title: 'Hermes Notes',
        filePath: '/library/hermes.pdf',
        fileSize: 4096,
        addedAt: DateTime.utc(2026, 7, 1, 12),
        lastPageRead: 3,
        tags: const ['hermes', 'obsidian'],
      );

      final restored = Book.fromMap(book.toMap());
      expect(restored, book);
      expect(restored.author, isNull);
      expect(restored.collectionId, isNull);
    });

    test('fromMap tolera tags JSON corruptos y fechas inválidas', () {
      final book = Book.fromMap({
        'id': 1,
        'title': 'Roto',
        'file_path': '/x.pdf',
        'file_size': 10,
        'added_at': 'no-es-fecha',
        'last_read_at': 'tampoco',
        'last_page_read': 2,
        'tags': '{not-json',
      });

      expect(book.title, 'Roto');
      expect(book.tags, isEmpty);
      expect(book.lastReadAt, isNull);
      expect(book.addedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(book.lastPageRead, 2);
    });
  });

  group('Collection / Bookmark serialization', () {
    test('Collection round-trip', () {
      final collection = Collection(
        id: 1,
        name: 'Papers',
        createdAt: DateTime.utc(2026, 7, 2),
      );
      expect(Collection.fromMap(collection.toMap()), collection);
    });

    test('Bookmark round-trip', () {
      final bookmark = Bookmark(
        id: 2,
        bookId: 9,
        pageNumber: 15,
        noteText: null,
        createdAt: DateTime.utc(2026, 7, 3),
      );
      expect(Bookmark.fromMap(bookmark.toMap()), bookmark);
    });
  });
}
