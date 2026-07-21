import '../../domain/pdf_text_service.dart';
import 'annotation_ink.dart' show MarkupRect;

/// Una coincidencia de búsqueda en el PDF.
class PdfTextMatch {
  const PdfTextMatch({
    required this.pageNumber,
    required this.text,
    required this.rect,
    required this.lineText,
  });

  /// Página 1-based.
  final int pageNumber;

  /// Fragmento que coincide con la consulta.
  final String text;

  /// Caja normalizada 0–1 en la página.
  final MarkupRect rect;

  /// Línea completa (para contexto en UI).
  final String lineText;
}

/// Busca [query] (sin distinguir mayúsculas) en las [lines] de una página.
List<PdfTextMatch> findMatchesInLines({
  required List<PdfLineBox> lines,
  required String query,
  required int pageNumber,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty || pageNumber < 1) return const [];

  final matches = <PdfTextMatch>[];
  for (final line in lines) {
    final raw = line.text;
    if (raw.isEmpty) continue;
    final lower = raw.toLowerCase();
    var from = 0;
    while (from < lower.length) {
      final idx = lower.indexOf(q, from);
      if (idx < 0) break;
      final end = idx + q.length;
      final rect = rectCoveringCharRange(line, idx, end) ?? line.rect;
      matches.add(
        PdfTextMatch(
          pageNumber: pageNumber,
          text: raw.substring(idx, end),
          rect: rect,
          lineText: raw,
        ),
      );
      from = end;
    }
  }
  return matches;
}

/// Une las cajas de las palabras que cubren el rango de caracteres [start, end)
/// dentro de [line] (texto = palabras unidas por un espacio).
MarkupRect? rectCoveringCharRange(PdfLineBox line, int start, int end) {
  if (end <= start || line.words.isEmpty) return null;

  double? minX;
  double? minY;
  double? maxX;
  double? maxY;
  var offset = 0;

  for (var i = 0; i < line.words.length; i++) {
    if (i > 0) offset += 1; // espacio entre palabras
    final word = line.words[i];
    final wStart = offset;
    final wEnd = offset + word.text.length;
    offset = wEnd;

    if (wEnd <= start || wStart >= end) continue;

    final r = word.rect;
    minX = minX == null ? r.x : (r.x < minX ? r.x : minX);
    minY = minY == null ? r.y : (r.y < minY ? r.y : minY);
    final right = r.x + r.width;
    final bottom = r.y + r.height;
    maxX = maxX == null ? right : (right > maxX ? right : maxX);
    maxY = maxY == null ? bottom : (bottom > maxY ? bottom : maxY);
  }

  if (minX == null || minY == null || maxX == null || maxY == null) {
    return null;
  }
  return MarkupRect(
    x: minX.clamp(0.0, 1.0),
    y: minY.clamp(0.0, 1.0),
    width: (maxX - minX).clamp(0.0, 1.0),
    height: (maxY - minY).clamp(0.0, 1.0),
  );
}
