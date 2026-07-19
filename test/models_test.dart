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

    test('tryFromMap ignora filas corruptas', () {
      expect(Book.tryFromMap(const {}), isNull);
      expect(
        Book.tryFromMap({
          'title': 'Solo título',
          'file_path': '',
          'file_size': 1,
          'added_at': 'no-es-fecha',
          'tags': '{',
        }),
        isNull,
      );
    });

    test('tryFromMap tolera tags corruptos y file_size string', () {
      final book = Book.tryFromMap({
        'id': '12',
        'title': 'Resiliente',
        'file_path': '/a.pdf',
        'file_size': '2048',
        'added_at': '2026-07-01T12:00:00.000Z',
        'tags': 'no-json',
        'last_page_read': '4',
      });

      expect(book, isNotNull);
      expect(book!.id, 12);
      expect(book.fileSize, 2048);
      expect(book.lastPageRead, 4);
      expect(book.tags, isEmpty);
    });

    test('matchesQuery busca en título, autor y tags', () {
      final book = Book(
        title: 'Clean Architecture',
        filePath: '/a.pdf',
        fileSize: 1,
        addedAt: DateTime.utc(2026, 1, 1),
        author: 'Uncle Bob',
        tags: const ['software', 'design'],
      );

      expect(book.matchesQuery('clean'), isTrue);
      expect(book.matchesQuery('uncle'), isTrue);
      expect(book.matchesQuery('design'), isTrue);
      expect(book.matchesQuery('xyz'), isFalse);
      expect(book.matchesQuery('  '), isTrue);
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

  group('DocumentSignature serialization', () {
    test('round-trip firma mecanografiada', () {
      final signature = DocumentSignature(
        id: 4,
        bookId: 2,
        pageNumber: 8,
        type: SignatureType.typed,
        signerName: 'Eva Ruiz',
        typedText: 'Eva R.',
        reason: 'Aprobado',
        offsetX: 0.6,
        offsetY: 0.8,
        signedAt: DateTime.utc(2026, 7, 19, 18),
      );
      expect(DocumentSignature.fromMap(signature.toMap()), signature);
      expect(signature.displayText, 'Eva R.');
    });

    test('inkStrokes parsea JSON de trazo', () {
      final signature = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'Leo',
        inkJson: '[[[0.1,0.2],[0.3,0.4]]]',
        signedAt: DateTime.utc(2026, 7, 19),
      );
      expect(signature.inkStrokes, [
        [
          [0.1, 0.2],
          [0.3, 0.4],
        ],
      ]);
    });

    test('inkStrokes ignora puntos malformados', () {
      final signature = DocumentSignature(
        bookId: 1,
        pageNumber: 1,
        type: SignatureType.drawn,
        signerName: 'Leo',
        inkJson: '[[[0.1,0.2],null,[0.3,0.4]]]',
        signedAt: DateTime.utc(2026, 7, 19),
      );
      expect(signature.inkStrokes.single, [
        [0.1, 0.2],
        [0.3, 0.4],
      ]);
    });
  });
}
