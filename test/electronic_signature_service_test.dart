import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/data/models/document_signature.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/electronic_signature_service.dart';

void main() {
  const service = ElectronicSignatureService();

  group('ElectronicSignatureService.signDocument', () {
    test('crea firma mecanografiada con nombre y texto', () {
      final signature = service.signDocument(
        bookId: 3,
        pageNumber: 2,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'Ana Pérez',
          typedText: 'Ana Pérez',
          reason: 'Conformidad',
        ),
        signedAt: DateTime.utc(2026, 7, 19, 12),
      );

      expect(signature.type, SignatureType.typed);
      expect(signature.signerName, 'Ana Pérez');
      expect(signature.displayText, 'Ana Pérez');
      expect(signature.reason, 'Conformidad');
      expect(signature.inkJson, isNull);
      expect(signature.pageNumber, 2);
      expect(signature.offsetX, ElectronicSignatureService.defaultOffsetX);
    });

    test('crea firma dibujada con trazos normalizados', () {
      final signature = service.signDocument(
        bookId: 1,
        pageNumber: 1,
        draft: const SignatureDraft(
          type: SignatureType.drawn,
          signerName: 'Luis',
          inkStrokes: [
            [
              [0.1, 0.2],
              [0.4, 0.5],
              [1.5, -0.2],
            ],
          ],
        ),
      );

      expect(signature.type, SignatureType.drawn);
      expect(signature.inkJson, isNotNull);
      expect(signature.inkStrokes.length, 1);
      expect(signature.inkStrokes.first.last, [1.0, 0.0]);
    });

    test('sugiere offset distinto cuando ya hay firmas en la página', () {
      final existing = [
        DocumentSignature(
          bookId: 1,
          pageNumber: 1,
          type: SignatureType.typed,
          signerName: 'A',
          typedText: 'A',
          offsetX: ElectronicSignatureService.defaultOffsetX,
          offsetY: ElectronicSignatureService.defaultOffsetY,
          signedAt: DateTime.utc(2026, 7, 1),
        ),
      ];

      final signature = service.signDocument(
        bookId: 1,
        pageNumber: 1,
        existingOnPage: existing,
        draft: const SignatureDraft(
          type: SignatureType.typed,
          signerName: 'B',
          typedText: 'B',
        ),
      );

      expect(
        signature.offsetY,
        lessThan(ElectronicSignatureService.defaultOffsetY),
      );
    });

    test('validateDraft rechaza firmante vacío', () {
      expect(
        () => service.validateDraft(
          const SignatureDraft(
            type: SignatureType.typed,
            signerName: '   ',
            typedText: 'X',
          ),
          pageNumber: 1,
        ),
        throwsA(isA<SignatureValidationException>()),
      );
    });

    test('rechaza firma dibujada sin trazo', () {
      expect(
        () => service.signDocument(
          bookId: 1,
          pageNumber: 1,
          draft: const SignatureDraft(
            type: SignatureType.drawn,
            signerName: 'Luis',
            inkStrokes: [],
          ),
        ),
        throwsA(isA<SignatureValidationException>()),
      );
    });

    test('rechaza nombre demasiado largo', () {
      expect(
        () => service.validateDraft(
          SignatureDraft(
            type: SignatureType.typed,
            signerName: 'x' * 81,
            typedText: 'x',
          ),
          pageNumber: 1,
        ),
        throwsA(isA<SignatureValidationException>()),
      );
    });
  });
}
