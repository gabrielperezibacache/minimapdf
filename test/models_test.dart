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
  });
}
