import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

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

class _ExtractRequest {
  const _ExtractRequest(this.bytes, this.pageIndex);
  final Uint8List bytes;
  final int pageIndex;
}

/// Extrae texto embebido del PDF (líneas y palabras con posición).
///
/// Funciona con PDFs que tienen capa de texto; los escaneados (solo imagen)
/// devuelven listas vacías (ahí se usa el respaldo por proyección de tinta).
class PdfTextService {
  PdfTextService(this._bytesLoader);

  /// Carga perezosa de los bytes del PDF (una sola vez).
  final Future<Uint8List> Function() _bytesLoader;

  Uint8List? _bytes;
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

  Future<List<PdfLineBox>> _extract(int pageIndex) async {
    try {
      _bytes ??= await _bytesLoader();
      final bytes = _bytes!;
      final lines = await compute(
        _extractLinesIsolate,
        _ExtractRequest(bytes, pageIndex),
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

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}

/// Ejecutado en un isolate: abre el PDF y extrae líneas de una página.
List<PdfLineBox> _extractLinesIsolate(_ExtractRequest req) {
  sf.PdfDocument? doc;
  try {
    doc = sf.PdfDocument(inputBytes: req.bytes);
    if (req.pageIndex < 0 || req.pageIndex >= doc.pages.count) {
      return const [];
    }
    final size = doc.pages[req.pageIndex].size;
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return const [];

    final extractor = sf.PdfTextExtractor(doc);
    final lines = extractor.extractTextLines(
      startPageIndex: req.pageIndex,
      endPageIndex: req.pageIndex,
    );

    MarkupRect norm(double left, double top, double width, double height) {
      final x = (left / w).clamp(0.0, 1.0);
      final y = (top / h).clamp(0.0, 1.0);
      final nw = (width / w).clamp(0.0, 1.0);
      final nh = (height / h).clamp(0.0, 1.0);
      return MarkupRect(x: x.toDouble(), y: y.toDouble(), width: nw.toDouble(), height: nh.toDouble());
    }

    final result = <PdfLineBox>[];
    for (final line in lines) {
      final text = line.text.trimRight();
      if (text.isEmpty) continue;
      final b = line.bounds;
      final words = <PdfWordBox>[];
      for (final word in line.wordCollection) {
        final wt = word.text.trim();
        if (wt.isEmpty) continue;
        final wb = word.bounds;
        words.add(
          PdfWordBox(
            text: wt,
            rect: norm(wb.left, wb.top, wb.width, wb.height),
          ),
        );
      }
      result.add(
        PdfLineBox(
          text: text,
          rect: norm(b.left, b.top, b.width, b.height),
          words: words,
        ),
      );
    }
    return result;
  } catch (_) {
    return const [];
  } finally {
    doc?.dispose();
  }
}
