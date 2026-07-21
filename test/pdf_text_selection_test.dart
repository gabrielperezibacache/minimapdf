import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/domain/pdf_text_service.dart';
import 'package:minimal_pdf/presentation/reader/annotation_ink.dart';
import 'package:minimal_pdf/presentation/reader/pdf_text_selection.dart';

PdfWordBox _word(String t, double x, double y, double w, double h) =>
    PdfWordBox(text: t, rect: MarkupRect(x: x, y: y, width: w, height: h));

void main() {
  final lines = <PdfLineBox>[
    PdfLineBox(
      text: 'Hola Mundo',
      rect: const MarkupRect(x: 0.1, y: 0.10, width: 0.5, height: 0.04),
      words: [
        _word('Hola', 0.10, 0.10, 0.15, 0.04),
        _word('Mundo', 0.30, 0.10, 0.20, 0.04),
      ],
    ),
    PdfLineBox(
      text: 'Segunda linea',
      rect: const MarkupRect(x: 0.1, y: 0.20, width: 0.6, height: 0.04),
      words: [
        _word('Segunda', 0.10, 0.20, 0.25, 0.04),
        _word('linea', 0.40, 0.20, 0.18, 0.04),
      ],
    ),
  ];

  test('selecciona palabras dentro del rectángulo', () {
    final text = selectedTextFromRect(
      lines: lines,
      selection: const Rect.fromLTWH(0.05, 0.08, 0.30, 0.05),
    );
    // Cubre "Hola" (y parte de Mundo si solapa). El rect llega a x=0.35.
    expect(text, contains('Hola'));
    expect(text, contains('Mundo'));
    expect(text, isNot(contains('Segunda')));
  });

  test('selección multi-línea une con salto de línea', () {
    final text = selectedTextFromRect(
      lines: lines,
      selection: const Rect.fromLTWH(0.05, 0.05, 0.6, 0.25),
    );
    expect(text, 'Hola Mundo\nSegunda linea');
  });

  test('rectángulo fuera del texto no selecciona nada', () {
    final text = selectedTextFromRect(
      lines: lines,
      selection: const Rect.fromLTWH(0.8, 0.8, 0.1, 0.1),
    );
    expect(text, isEmpty);
  });

  test('bandsFromLines produce una banda por línea', () {
    final bands = bandsFromLines(lines);
    expect(bands.length, 2);
    expect(bands[0].top, closeTo(0.10, 1e-9));
    expect(bands[0].bottom, closeTo(0.14, 1e-9));
  });
}
