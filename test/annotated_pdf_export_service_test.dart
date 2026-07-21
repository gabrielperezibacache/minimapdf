import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/data/models/book.dart';
import 'package:minimal_pdf/domain/annotated_pdf_export_service.dart';
import 'package:minimal_pdf/l10n/app_message_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildAnnotatedPdfBytes rechaza lista vacía', () async {
    final service = AnnotatedPdfExportService();
    final book = Book(
      id: 1,
      title: 'Demo',
      filePath: '/tmp/missing.pdf',
      fileSize: 1,
      addedAt: DateTime(2026, 7, 21),
    );

    expect(
      () => service.buildAnnotatedPdfBytes(
        book: book,
        annotations: const [],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          AppMessageKeys.needAnnotations,
        ),
      ),
    );
  });

  test('AnnotatedPdfSaveTarget distingue documento y copia', () {
    expect(
      AnnotatedPdfSaveTarget.currentDocument,
      isNot(AnnotatedPdfSaveTarget.libraryCopy),
    );
  });
}
