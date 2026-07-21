import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pdf;
import 'package:pdfrx/pdfrx.dart';

import '../core/utils/app_paths.dart';
import '../core/utils/file_name_sanitizer.dart';
import '../data/models/book.dart';
import '../data/models/page_annotation.dart';
import '../l10n/app_message_keys.dart';
import 'pdf_page_rasterizer.dart';

/// Destino al aplanar anotaciones de la caja de herramientas en el PDF.
enum AnnotatedPdfSaveTarget {
  /// Sobrescribe el archivo del libro actual.
  currentDocument,

  /// Crea una copia nueva en la biblioteca.
  libraryCopy,
}

/// Resultado de aplanar anotaciones en un PDF.
class AnnotatedPdfExportResult {
  const AnnotatedPdfExportResult({
    required this.pdfPath,
    required this.target,
    required this.fileName,
  });

  final String pdfPath;
  final AnnotatedPdfSaveTarget target;
  final String fileName;
}

/// Exporta un PDF con marcado/subrayado/notas aplanados (estilo Samsung Notes).
///
/// Mismo enfoque que firmas: renderiza páginas (pdfrx), pinta tinta y reconstruye
/// con el paquete `pdf`. Rasteriza las páginas.
class AnnotatedPdfExportService {
  AnnotatedPdfExportService({
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? AppPaths.documentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  static const double _renderScale = 1.6;
  static const String _defaultMarker = 'annotated';

  /// Construye los bytes del PDF anotado (sin escribir a disco).
  Future<Uint8List> buildAnnotatedPdfBytes({
    required Book book,
    required List<PageAnnotation> annotations,
  }) async {
    if (annotations.isEmpty) {
      throw StateError(AppMessageKeys.needAnnotations);
    }
    final source = File(book.filePath);
    if (!await source.exists()) {
      throw StateError(AppMessageKeys.documentUnavailable);
    }

    final document = await PdfDocument.openFile(book.filePath);
    try {
      final pageCount = document.pages.length;
      if (pageCount < 1) {
        throw StateError(AppMessageKeys.exportAnnotatedFailed);
      }

      final outOfRange = annotations.any(
        (a) => a.pageNumber < 1 || a.pageNumber > pageCount,
      );
      if (outOfRange) {
        throw StateError(AppMessageKeys.exportAnnotatedFailed);
      }

      final output = pdf.Document();
      final byPage = <int, List<PageAnnotation>>{};
      for (final annotation in annotations) {
        byPage.putIfAbsent(annotation.pageNumber, () => []).add(annotation);
      }

      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        final page = document.pages[pageNumber - 1];
        final pageW = page.width;
        final pageH = page.height;
        if (!pageW.isFinite ||
            !pageH.isFinite ||
            pageW < 1 ||
            pageH < 1) {
          throw StateError(AppMessageKeys.exportAnnotatedFailed);
        }

        final rendered = await rasterizePdfPage(page, scale: _renderScale);
        final stampedBytes = await _stampPageImage(
          pageBytes: rendered.pngBytes,
          width: rendered.width,
          height: rendered.height,
          annotations: byPage[pageNumber] ?? const [],
        );

        output.addPage(
          pdf.Page(
            pageFormat: pw.PdfPageFormat(pageW, pageH, marginAll: 0),
            build: (_) => pdf.Image(
              pdf.MemoryImage(stampedBytes),
              fit: pdf.BoxFit.fill,
            ),
          ),
        );
      }

      return Uint8List.fromList(await output.save());
    } finally {
      await document.dispose();
    }
  }

  /// Escribe una copia anotada en `library/` con nombre único.
  Future<AnnotatedPdfExportResult> exportAsLibraryCopy({
    required Book book,
    required List<PageAnnotation> annotations,
    Set<String> reservedBasenames = const {},
    String marker = _defaultMarker,
  }) async {
    final bytes = await buildAnnotatedPdfBytes(
      book: book,
      annotations: annotations,
    );

    final docs = await _documentsDirectory();
    final libraryDir = Directory(p.join(docs.path, 'library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    final existing = await _existingNames(libraryDir);
    for (final name in reservedBasenames) {
      existing.add(name.toLowerCase());
    }
    final cleanMarker = marker.trim().isEmpty ? _defaultMarker : marker.trim();
    final sanitized = FileNameSanitizer.sanitize('${book.title}_$cleanMarker');
    final pdfName = FileNameSanitizer.uniqueName(sanitized, existing);
    final pdfPath = p.join(libraryDir.path, pdfName);

    try {
      await File(pdfPath).writeAsBytes(bytes, flush: true);
      return AnnotatedPdfExportResult(
        pdfPath: pdfPath,
        target: AnnotatedPdfSaveTarget.libraryCopy,
        fileName: pdfName,
      );
    } catch (_) {
      await _deleteQuietly(pdfPath);
      rethrow;
    }
  }

  /// Sobrescribe [book.filePath] con el PDF anotado.
  ///
  /// El caller debe cerrar cualquier documento PDF abierto sobre ese archivo
  /// antes de llamar.
  Future<AnnotatedPdfExportResult> overwriteCurrentDocument({
    required Book book,
    required List<PageAnnotation> annotations,
  }) async {
    final bytes = await buildAnnotatedPdfBytes(
      book: book,
      annotations: annotations,
    );

    final target = File(book.filePath);
    final partPath = '${book.filePath}.annotated.part';
    final part = File(partPath);
    try {
      await part.writeAsBytes(bytes, flush: true);
      if (await target.exists()) {
        await target.delete();
      }
      await part.rename(target.path);
      return AnnotatedPdfExportResult(
        pdfPath: target.path,
        target: AnnotatedPdfSaveTarget.currentDocument,
        fileName: p.basename(target.path),
      );
    } catch (_) {
      await _deleteQuietly(partPath);
      rethrow;
    }
  }

  Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<Set<String>> _existingNames(Directory libraryDir) async {
    if (!await libraryDir.exists()) return <String>{};
    final names = <String>{};
    await for (final entity in libraryDir.list()) {
      if (entity is File) {
        names.add(p.basename(entity.path).toLowerCase());
      }
    }
    return names;
  }

  Future<Uint8List> _stampPageImage({
    required List<int> pageBytes,
    required int width,
    required int height,
    required List<PageAnnotation> annotations,
  }) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(pageBytes));
    try {
      final frame = await codec.getNextFrame();
      final pageImage = frame.image;
      try {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final size = Size(width.toDouble(), height.toDouble());
        canvas.drawImage(pageImage, Offset.zero, Paint());

        for (final annotation in annotations) {
          _paintAnnotation(canvas, size, annotation);
        }

        final picture = recorder.endRecording();
        try {
          final stamped = await picture.toImage(width, height);
          try {
            final byteData =
                await stamped.toByteData(format: ui.ImageByteFormat.png);
            if (byteData == null) {
              throw StateError(AppMessageKeys.exportAnnotatedFailed);
            }
            return byteData.buffer.asUint8List();
          } finally {
            stamped.dispose();
          }
        } finally {
          picture.dispose();
        }
      } finally {
        pageImage.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  void _paintAnnotation(Canvas canvas, Size size, PageAnnotation annotation) {
    switch (annotation.type) {
      case AnnotationType.highlight:
      case AnnotationType.underline:
        if (annotation.hasInk) {
          _paintInkStroke(canvas, size, annotation);
        } else {
          _paintLegacyRect(canvas, size, annotation);
        }
      case AnnotationType.note:
      case AnnotationType.comment:
      case AnnotationType.annotation:
        _paintPin(canvas, size, annotation);
    }
  }

  void _paintInkStroke(Canvas canvas, Size size, PageAnnotation annotation) {
    final paint = Paint()
      ..color = annotation.color
      ..strokeWidth =
          math.max(1.0, annotation.effectiveStrokeWidth * _renderScale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in annotation.inkStrokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(
          stroke.first[0] * size.width,
          stroke.first[1] * size.height,
        );
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(
          stroke[i][0] * size.width,
          stroke[i][1] * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintLegacyRect(Canvas canvas, Size size, PageAnnotation annotation) {
    final rect = Rect.fromLTWH(
      annotation.x * size.width,
      annotation.y * size.height,
      math.max(1.0, annotation.width * size.width),
      math.max(1.0, annotation.height * size.height),
    );
    final paint = Paint()
      ..color = annotation.color
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
  }

  void _paintPin(Canvas canvas, Size size, PageAnnotation annotation) {
    final cx = (annotation.x + annotation.width / 2) * size.width;
    final cy = (annotation.y + annotation.height / 2) * size.height;
    final box = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 28 * _renderScale,
      height: 28 * _renderScale,
    );
    final bg = Paint()..color = const Color(0xF5F3ECDD);
    final border = Paint()
      ..color = annotation.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * _renderScale;
    canvas.drawRect(box, bg);
    canvas.drawRect(box, border);

    final label = annotation.hasText
        ? annotation.text!.trim()
        : annotation.type.labelEs;
    final painter = TextPainter(
      text: TextSpan(
        text: label.length > 18 ? '${label.substring(0, 17)}…' : label,
        style: TextStyle(
          color: const Color(0xFF121D18),
          fontSize: 9 * _renderScale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    try {
      painter.layout(maxWidth: size.width * 0.4);
      painter.paint(
        canvas,
        Offset(box.right + 4 * _renderScale, box.center.dy - painter.height / 2),
      );
    } finally {
      painter.dispose();
    }
  }
}
