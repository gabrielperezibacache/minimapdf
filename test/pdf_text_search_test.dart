import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/domain/pdf_text_service.dart';
import 'package:minimal_pdf/presentation/reader/annotation_ink.dart';
import 'package:minimal_pdf/presentation/reader/pdf_text_search.dart';

PdfWordBox _w(String t, double x, double y, double w, double h) =>
    PdfWordBox(text: t, rect: MarkupRect(x: x, y: y, width: w, height: h));

void main() {
  final lines = <PdfLineBox>[
    PdfLineBox(
      text: 'Hola Mundo Minimal',
      rect: const MarkupRect(x: 0.1, y: 0.10, width: 0.7, height: 0.04),
      words: [
        _w('Hola', 0.10, 0.10, 0.15, 0.04),
        _w('Mundo', 0.28, 0.10, 0.20, 0.04),
        _w('Minimal', 0.50, 0.10, 0.25, 0.04),
      ],
    ),
    PdfLineBox(
      text: 'Segunda linea',
      rect: const MarkupRect(x: 0.1, y: 0.20, width: 0.5, height: 0.04),
      words: [
        _w('Segunda', 0.10, 0.20, 0.25, 0.04),
        _w('linea', 0.40, 0.20, 0.18, 0.04),
      ],
    ),
  ];

  test('encuentra coincidencias sin distinguir mayúsculas', () {
    final matches = findMatchesInLines(
      lines: lines,
      query: 'mundo',
      pageNumber: 1,
    );
    expect(matches, hasLength(1));
    expect(matches.first.text.toLowerCase(), 'mundo');
    expect(matches.first.pageNumber, 1);
    expect(matches.first.rect.x, closeTo(0.28, 1e-9));
  });

  test('consulta vacía no produce resultados', () {
    expect(
      findMatchesInLines(lines: lines, query: '  ', pageNumber: 1),
      isEmpty,
    );
  });

  test('varias coincidencias en la misma línea', () {
    final multi = <PdfLineBox>[
      PdfLineBox(
        text: 'a a a',
        rect: const MarkupRect(x: 0, y: 0, width: 1, height: 0.1),
        words: [
          _w('a', 0.0, 0.0, 0.1, 0.1),
          _w('a', 0.2, 0.0, 0.1, 0.1),
          _w('a', 0.4, 0.0, 0.1, 0.1),
        ],
      ),
    ];
    final matches = findMatchesInLines(
      lines: multi,
      query: 'a',
      pageNumber: 3,
    );
    expect(matches, hasLength(3));
    expect(matches.every((m) => m.pageNumber == 3), isTrue);
  });

  test('rectCoveringCharRange une palabras de una frase', () {
    final rect = rectCoveringCharRange(lines.first, 0, 10); // "Hola Mundo"
    expect(rect, isNotNull);
    expect(rect!.x, closeTo(0.10, 1e-9));
    expect(rect.width, greaterThan(0.3));
  });
}
