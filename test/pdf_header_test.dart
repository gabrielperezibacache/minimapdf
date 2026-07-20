import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/utils/pdf_header.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PdfHeader', () {
    test('matchesBytes detecta magia %PDF', () {
      expect(PdfHeader.matchesBytes(const [0x25, 0x50, 0x44, 0x46]), isTrue);
      expect(PdfHeader.matchesBytes(const [0x00, 0x01, 0x02, 0x03]), isFalse);
      expect(PdfHeader.matchesBytes(const [0x25]), isFalse);
    });

    test('assertFile acepta PDF y rechaza basura', () async {
      final dir = await Directory.systemTemp.createTemp('pdf_header_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final good = File(p.join(dir.path, 'ok.pdf'));
      await good.writeAsBytes(const [0x25, 0x50, 0x44, 0x46, 0x2D]);
      await PdfHeader.assertFile(good);

      final bad = File(p.join(dir.path, 'bad.pdf'));
      await bad.writeAsBytes(const [0x00, 0x01, 0x02, 0x03]);
      expect(
        () => PdfHeader.assertFile(bad),
        throwsA(isA<FormatException>()),
      );
    });

    test('assertBytes exige magia aunque el content-type diga pdf', () {
      expect(
        () => PdfHeader.assertBytes(
          Uint8List.fromList(const [1, 2, 3, 4]),
          contentType: 'application/pdf',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('assertBytes permite content-type si requireMagic es false', () {
      expect(
        () => PdfHeader.assertBytes(
          Uint8List.fromList(const [1, 2, 3, 4]),
          contentType: 'application/pdf',
          requireMagic: false,
        ),
        returnsNormally,
      );
    });

    test('acepta %PDF tras BOM/junk en la ventana inicial', () async {
      final dir = await Directory.systemTemp.createTemp('pdf_header_bom_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final file = File(p.join(dir.path, 'bom.pdf'));
      await file.writeAsBytes([
        0xEF, 0xBB, 0xBF, // BOM
        0x00, 0x00,
        0x25, 0x50, 0x44, 0x46, // %PDF
        0x2D, 0x31,
      ]);
      await PdfHeader.assertFile(file);
      expect(
        PdfHeader.containsMagic(const [
          0x00,
          0x25,
          0x50,
          0x44,
          0x46,
        ]),
        isTrue,
      );
    });

    test('assertFile exige %%EOF en PDFs grandes', () async {
      final dir = await Directory.systemTemp.createTemp('pdf_header_eof_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final truncated = File(p.join(dir.path, 'truncated.pdf'));
      await truncated.writeAsBytes([
        0x25, 0x50, 0x44, 0x46, // %PDF
        ...List<int>.filled(300, 0x20),
      ]);
      expect(
        () => PdfHeader.assertFile(truncated),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('incompleto'),
          ),
        ),
      );

      final complete = File(p.join(dir.path, 'complete.pdf'));
      await complete.writeAsBytes([
        0x25, 0x50, 0x44, 0x46,
        ...List<int>.filled(300, 0x20),
        0x25, 0x25, 0x45, 0x4F, 0x46, // %%EOF
      ]);
      await PdfHeader.assertFile(complete);
    });

    test('containsEofMarker detecta %%EOF', () {
      expect(
        PdfHeader.containsEofMarker(const [0x25, 0x25, 0x45, 0x4F, 0x46]),
        isTrue,
      );
      expect(PdfHeader.containsEofMarker(const [0x25, 0x50, 0x44, 0x46]), isFalse);
    });
  });
}
