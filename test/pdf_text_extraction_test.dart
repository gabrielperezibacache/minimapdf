import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/domain/pdf_text_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

/// Caja de carácter en coords PDF (origen abajo-izquierda, top > bottom).
PdfRect _c(double left, double right, double top, double bottom) =>
    PdfRect(left, top, right, bottom);

void main() {
  group('linesFromCharRects (reconstrucción pura)', () {
    test('separa líneas por salto explícito y palabras por espacio', () {
      // Página 100x100. "Hola\nMundo aqui".
      const full = 'Hola\nMundo aqui';
      final rects = <PdfRect>[
        _c(10, 14, 90, 85), // H
        _c(14, 18, 90, 85), // o
        _c(18, 22, 90, 85), // l
        _c(22, 26, 90, 85), // a
        PdfRect.empty, // \n
        _c(10, 16, 70, 65), // M
        _c(16, 20, 70, 65), // u
        _c(20, 24, 70, 65), // n
        _c(24, 28, 70, 65), // d
        _c(28, 32, 70, 65), // o
        PdfRect.empty, // espacio
        _c(38, 42, 70, 65), // a
        _c(42, 46, 70, 65), // q
        _c(46, 50, 70, 65), // u
        _c(50, 54, 70, 65), // i
      ];

      final lines = linesFromCharRects(
        fullText: full,
        charRects: rects,
        pageWidth: 100,
        pageHeight: 100,
      );

      expect(lines.length, 2);
      expect(lines[0].text, 'Hola');
      expect(lines[0].words.length, 1);
      expect(lines[1].text, 'Mundo aqui');
      expect(lines[1].words.map((w) => w.text).toList(), ['Mundo', 'aqui']);

      // Coords normalizadas 0–1, origen arriba-izquierda.
      expect(lines[0].rect.y, closeTo(0.10, 1e-9));
      expect(lines[0].rect.height, closeTo(0.05, 1e-9));
      expect(lines[0].rect.x, closeTo(0.10, 1e-9));
      // La primera línea queda por encima de la segunda.
      expect(lines[0].rect.y, lessThan(lines[1].rect.y));
    });

    test('detecta salto de línea implícito por salto vertical', () {
      // "AB" sin salto ni espacio, pero en bandas verticales distintas.
      final lines = linesFromCharRects(
        fullText: 'AB',
        charRects: <PdfRect>[
          _c(10, 14, 90, 85), // A (arriba)
          _c(10, 14, 50, 45), // B (abajo)
        ],
        pageWidth: 100,
        pageHeight: 100,
      );
      expect(lines.length, 2);
      expect(lines[0].text, 'A');
      expect(lines[1].text, 'B');
    });

    test('página vacía o dimensiones inválidas devuelve vacío', () {
      expect(
        linesFromCharRects(
          fullText: '',
          charRects: const [],
          pageWidth: 100,
          pageHeight: 100,
        ),
        isEmpty,
      );
      expect(
        linesFromCharRects(
          fullText: 'Hola',
          charRects: [_c(10, 14, 90, 85)],
          pageWidth: 0,
          pageHeight: 100,
        ),
        isEmpty,
      );
    });
  });

  group('extracción real con pdfrx (PDFium)', () {
    setUpAll(() async {
      await pdfrxInitialize();
    });

    test('extrae texto y bounds de un PDF generado', () async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Hola Mundo'),
                pw.SizedBox(height: 20),
                pw.Text('Segunda linea de texto'),
              ],
            ),
          ),
        ),
      );
      final bytes = await doc.save();

      final service = PdfTextService(() async => bytes);
      final lines = await service.linesForPage(0);
      await service.dispose();

      expect(lines, isNotEmpty);
      final allText = lines.map((l) => l.text).join(' ');
      expect(allText, contains('Hola'));
      expect(allText, contains('Mundo'));
      expect(allText, contains('Segunda'));

      for (final line in lines) {
        expect(line.rect.x, inInclusiveRange(0.0, 1.0));
        expect(line.rect.y, inInclusiveRange(0.0, 1.0));
        expect(line.rect.width, greaterThan(0.0));
        expect(line.rect.height, greaterThan(0.0));
        expect(line.words, isNotEmpty);
      }

      // La primera línea debe quedar por encima de la última.
      expect(lines.first.rect.y, lessThan(lines.last.rect.y));
    });
  });
}
