import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/utils/pdf_url_utils.dart';

void main() {
  group('PdfUrlUtils', () {
    test('valida URLs http(s)', () {
      expect(PdfUrlUtils.isValidHttpUrl('https://a.com/x.pdf'), isTrue);
      expect(PdfUrlUtils.isValidHttpUrl('ftp://a.com/x.pdf'), isFalse);
      expect(PdfUrlUtils.isValidHttpUrl('no-url'), isFalse);
    });

    test('detecta URLs con apariencia de PDF', () {
      expect(
        PdfUrlUtils.looksLikePdfUrl('https://cdn.example.com/doc.pdf?dl=1'),
        isTrue,
      );
      expect(
        PdfUrlUtils.looksLikePdfUrl('https://arxiv.org/pdf/2401.12345'),
        isTrue,
      );
      expect(
        PdfUrlUtils.looksLikePdfUrl('https://example.com/pdf/report'),
        isTrue,
      );
      expect(
        PdfUrlUtils.looksLikePdfUrl('https://example.com/page'),
        isFalse,
      );
      expect(
        PdfUrlUtils.looksLikePdfUrl('https://example.com/pdf'),
        isFalse,
      );
    });

    test('extrae nombre de archivo desde la URL', () {
      expect(
        PdfUrlUtils.fileNameFromUrl('https://x.com/files/Manual%20Final.pdf'),
        'Manual Final.pdf',
      );
    });
  });
}
