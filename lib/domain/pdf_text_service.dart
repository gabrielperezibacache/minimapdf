import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import '../presentation/reader/annotation_ink.dart' show MarkupRect;

/// Palabra de texto del PDF con su caja normalizada (0–1) en la página.
class PdfWordBox {
  const PdfWordBox({required this.text, required this.rect});
  final String text;
  final MarkupRect rect;
}

/// Línea de texto del PDF con caja normalizada y sus palabras.
class PdfLineBox {
  const PdfLineBox({
    required this.text,
    required this.rect,
    required this.words,
  });
  final String text;
  final MarkupRect rect;
  final List<PdfWordBox> words;
}

/// Extrae texto embebido del PDF (líneas y palabras con posición) vía PDFium.
///
/// Funciona con PDFs que tienen capa de texto; los escaneados (solo imagen)
/// devuelven listas vacías (ahí se usa el respaldo por proyección de tinta).
class PdfTextService {
  PdfTextService(this._bytesLoader);

  /// Carga perezosa de los bytes del PDF (una sola vez).
  final Future<Uint8List> Function() _bytesLoader;

  Uint8List? _bytes;
  PdfDocument? _doc;
  Future<PdfDocument?>? _docFuture;
  final Map<int, List<PdfLineBox>> _cache = {};
  final Map<int, Future<List<PdfLineBox>>> _inFlight = {};

  Future<List<PdfLineBox>> linesForPage(int pageIndex) {
    final cached = _cache[pageIndex];
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[pageIndex];
    if (pending != null) return pending;

    final future = _extract(pageIndex);
    _inFlight[pageIndex] = future;
    return future;
  }

  Future<PdfDocument?> _document() {
    final doc = _doc;
    if (doc != null) return Future.value(doc);
    return _docFuture ??= () async {
      _bytes ??= await _bytesLoader();
      final opened = await PdfDocument.openData(
        _bytes!,
        sourceName: 'minimal_pdf_text_service',
      );
      _doc = opened;
      return opened;
    }();
  }

  Future<List<PdfLineBox>> _extract(int pageIndex) async {
    try {
      final doc = await _document();
      if (doc == null || pageIndex < 0 || pageIndex >= doc.pages.length) {
        _cache[pageIndex] = const [];
        return const [];
      }
      final page = doc.pages[pageIndex];
      final w = page.width;
      final h = page.height;
      if (w <= 0 || h <= 0) {
        _cache[pageIndex] = const [];
        return const [];
      }
      final pageText = await page.loadStructuredText();
      final lines = linesFromCharRects(
        fullText: pageText.fullText,
        charRects: pageText.charRects,
        pageWidth: w,
        pageHeight: h,
      );
      _cache[pageIndex] = lines;
      return lines;
    } catch (e) {
      if (kDebugMode) debugPrint('PdfTextService.linesForPage($pageIndex): $e');
      _cache[pageIndex] = const [];
      return const [];
    } finally {
      _inFlight.remove(pageIndex);
    }
  }

  Future<void> dispose() async {
    _cache.clear();
    _inFlight.clear();
    final doc = _doc;
    _doc = null;
    _docFuture = null;
    _bytes = null;
    if (doc != null) {
      try {
        await doc.dispose();
      } catch (_) {
        // Best-effort al cerrar el documento nativo.
      }
    }
  }
}

/// Reconstruye líneas y palabras a partir de los arrays paralelos
/// `fullText` / `charRects` (una caja por carácter en coords PDF).
///
/// Función pura para poder probar la agrupación sin depender de PDFium.
/// Las coordenadas PDF tienen origen abajo-izquierda (Y hacia arriba); aquí se
/// convierten a coordenadas normalizadas 0–1 con origen arriba-izquierda.
List<PdfLineBox> linesFromCharRects({
  required String fullText,
  required List<PdfRect> charRects,
  required double pageWidth,
  required double pageHeight,
}) {
  if (pageWidth <= 0 || pageHeight <= 0) return const [];
  final count = math.min(fullText.length, charRects.length);
  if (count == 0) return const [];

  final lines = <PdfLineBox>[];

  // Acumuladores de la línea en curso (coords normalizadas arriba-izquierda).
  final lineWords = <PdfWordBox>[];
  var lineMinX = double.infinity;
  var lineMinY = double.infinity;
  var lineMaxX = double.negativeInfinity;
  var lineMaxY = double.negativeInfinity;

  // Acumuladores de la palabra en curso.
  final wordBuf = StringBuffer();
  var wordMinX = double.infinity;
  var wordMinY = double.infinity;
  var wordMaxX = double.negativeInfinity;
  var wordMaxY = double.negativeInfinity;
  var wordPrevRight = double.nan;
  var wordCharH = 0.0;

  bool wordEmpty() => wordBuf.isEmpty;
  bool lineEmpty() => lineWords.isEmpty && wordEmpty();

  void flushWord() {
    if (wordBuf.isEmpty) return;
    final rect = MarkupRect(
      x: wordMinX.clamp(0.0, 1.0),
      y: wordMinY.clamp(0.0, 1.0),
      width: (wordMaxX - wordMinX).clamp(0.0, 1.0),
      height: (wordMaxY - wordMinY).clamp(0.0, 1.0),
    );
    lineWords.add(PdfWordBox(text: wordBuf.toString(), rect: rect));
    lineMinX = math.min(lineMinX, wordMinX);
    lineMinY = math.min(lineMinY, wordMinY);
    lineMaxX = math.max(lineMaxX, wordMaxX);
    lineMaxY = math.max(lineMaxY, wordMaxY);
    wordBuf.clear();
    wordMinX = double.infinity;
    wordMinY = double.infinity;
    wordMaxX = double.negativeInfinity;
    wordMaxY = double.negativeInfinity;
    wordPrevRight = double.nan;
    wordCharH = 0.0;
  }

  void flushLine() {
    flushWord();
    if (lineWords.isNotEmpty) {
      final rect = MarkupRect(
        x: lineMinX.clamp(0.0, 1.0),
        y: lineMinY.clamp(0.0, 1.0),
        width: (lineMaxX - lineMinX).clamp(0.0, 1.0),
        height: (lineMaxY - lineMinY).clamp(0.0, 1.0),
      );
      lines.add(
        PdfLineBox(
          text: lineWords.map((w) => w.text).join(' '),
          rect: rect,
          words: List<PdfWordBox>.of(lineWords),
        ),
      );
    }
    lineWords.clear();
    lineMinX = double.infinity;
    lineMinY = double.infinity;
    lineMaxX = double.negativeInfinity;
    lineMaxY = double.negativeInfinity;
  }

  for (var i = 0; i < count; i++) {
    final ch = fullText[i];
    if (ch == '\n' || ch == '\r' || ch == '\f') {
      flushLine();
      continue;
    }
    final isSpace = ch.trim().isEmpty;

    final r = charRects[i];
    final l = r.left / pageWidth;
    final rr = r.right / pageWidth;
    final t = (pageHeight - r.top) / pageHeight;
    final b = (pageHeight - r.bottom) / pageHeight;
    final top = math.min(t, b);
    final bottom = math.max(t, b);
    final charH = bottom - top;
    final centerY = (top + bottom) / 2;

    if (isSpace) {
      flushWord();
      continue;
    }

    // Salto de línea implícito: el carácter cae fuera de la banda vertical
    // de la línea en curso (PDFs sin '\n' explícito entre líneas).
    // La banda incluye la palabra en construcción (aún no volcada a la línea).
    if (!lineEmpty()) {
      final effMinY = math.min(lineMinY, wordMinY);
      final effMaxY = math.max(lineMaxY, wordMaxY);
      if (effMinY.isFinite && effMaxY.isFinite) {
        final refH = effMaxY - effMinY;
        final margin = 0.5 * (refH > 0 ? refH : charH);
        if (centerY < effMinY - margin || centerY > effMaxY + margin) {
          flushLine();
        }
      }
    }

    // Separación de palabra por hueco horizontal (PDFs sin espacios reales).
    if (!wordEmpty() && !wordPrevRight.isNaN) {
      final gap = l - wordPrevRight;
      final ref = wordCharH > 0 ? wordCharH : charH;
      if (gap > 0.6 * ref) {
        flushWord();
      }
    }

    wordBuf.write(ch);
    wordMinX = math.min(wordMinX, l);
    wordMinY = math.min(wordMinY, top);
    wordMaxX = math.max(wordMaxX, rr);
    wordMaxY = math.max(wordMaxY, bottom);
    wordPrevRight = rr;
    wordCharH = math.max(wordCharH, charH);
  }
  flushLine();

  return lines;
}
