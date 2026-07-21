import 'dart:ui' show Rect;

import '../../domain/pdf_text_service.dart';
import 'annotation_ink.dart' show MarkupRect;
import 'text_line_snap.dart';

Rect _rectOf(MarkupRect r) => Rect.fromLTWH(r.x, r.y, r.width, r.height);

/// Bandas de texto (para el imantado) a partir de las líneas reales del PDF.
List<TextBand> bandsFromLines(List<PdfLineBox> lines) {
  final bands = <TextBand>[];
  for (final line in lines) {
    final top = line.rect.y;
    final bottom = (line.rect.y + line.rect.height).clamp(0.0, 1.0);
    if (bottom - top <= 0) continue;
    bands.add(TextBand(top: top, bottom: bottom.toDouble()));
  }
  return bands;
}

/// Palabras seleccionadas por un rectángulo (normalizado 0–1), en orden lectura.
List<PdfWordBox> wordsInRect({
  required List<PdfLineBox> lines,
  required Rect selection,
}) {
  final selected = <PdfWordBox>[];
  for (final line in lines) {
    for (final word in line.words) {
      if (selection.overlaps(_rectOf(word.rect))) {
        selected.add(word);
      }
    }
  }
  return selected;
}

/// Texto seleccionado por un rectángulo: palabras por línea, líneas con salto.
String selectedTextFromRect({
  required List<PdfLineBox> lines,
  required Rect selection,
}) {
  final buffer = <String>[];
  for (final line in lines) {
    final words = <String>[];
    for (final word in line.words) {
      if (selection.overlaps(_rectOf(word.rect))) {
        words.add(word.text);
      }
    }
    if (words.isNotEmpty) {
      buffer.add(words.join(' '));
    }
  }
  return buffer.join('\n');
}
