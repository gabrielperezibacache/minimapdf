import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pdf;
import 'package:pdfx/pdfx.dart';

import '../core/utils/app_paths.dart';
import '../core/utils/file_name_sanitizer.dart';
import '../data/models/book.dart';
import '../data/models/document_signature.dart';
import '../data/models/signature_role.dart';
import '../data/models/signature_type.dart';
import 'document_hash_service.dart';
import 'signature_manifest.dart';
import 'signature_stamp_geometry.dart';

/// Resultado de exportar un PDF con sellos de firma incrustados.
class SignedPdfExportResult {
  const SignedPdfExportResult({
    required this.pdfPath,
    required this.manifestPath,
    required this.manifest,
  });

  final String pdfPath;
  final String manifestPath;
  final SignatureManifest manifest;
}

/// Exporta una copia del PDF con firmas aplanadas + manifiesto SHA-256.
///
/// Flujo offline: renderiza cada página (pdfx), dibuja los sellos y
/// reconstruye un PDF nuevo (paquete `pdf`). No usa PKI.
class SignedPdfExportService {
  SignedPdfExportService({
    this._hashService = const DocumentHashService(),
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? AppPaths.documentsDirectory;

  final DocumentHashService _hashService;
  final Future<Directory> Function() _documentsDirectory;

  static const double _renderScale = 1.6;

  Future<SignedPdfExportResult> exportSignedPdf({
    required Book book,
    required List<DocumentSignature> signatures,
    Set<String> reservedBasenames = const {},
  }) async {
    if (signatures.isEmpty) {
      throw StateError('No hay firmas para exportar.');
    }
    final source = File(book.filePath);
    if (!await source.exists()) {
      throw StateError('El PDF original no existe.');
    }

    final sourceSha = await _hashService.sha256File(book.filePath);
    final docs = await _documentsDirectory();
    final libraryDir = Directory(p.join(docs.path, 'library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    final existing = await _existingNames(libraryDir);
    for (final name in reservedBasenames) {
      existing.add(name.toLowerCase());
    }
    final sanitized = FileNameSanitizer.sanitize('${book.title}_firmado');
    final pdfName = FileNameSanitizer.uniqueName(sanitized, existing);
    final pdfPath = p.join(libraryDir.path, pdfName);
    final manifestPath = '${p.withoutExtension(pdfPath)}.firmas.json';
    var wrotePdf = false;
    var wroteManifest = false;

    final document = await PdfDocument.openFile(book.filePath);
    try {
      if (document.pagesCount < 1) {
        throw StateError('El PDF no tiene páginas.');
      }

      final outOfRange = signatures
          .where(
            (signature) =>
                signature.pageNumber < 1 ||
                signature.pageNumber > document.pagesCount,
          )
          .toList(growable: false);
      if (outOfRange.isNotEmpty) {
        throw StateError(
          'Hay firmas fuera del rango de páginas del documento.',
        );
      }

      final output = pdf.Document();
      final byPage = <int, List<DocumentSignature>>{};
      for (final signature in signatures) {
        byPage.putIfAbsent(signature.pageNumber, () => []).add(signature);
      }

      for (var pageNumber = 1; pageNumber <= document.pagesCount; pageNumber++) {
        final page = await document.getPage(pageNumber);
        try {
          if (page.width <= 0 || page.height <= 0) {
            throw StateError('Página $pageNumber con tamaño inválido.');
          }

          final rendered = await page.render(
            width: page.width * _renderScale,
            height: page.height * _renderScale,
            format: PdfPageImageFormat.png,
          );
          if (rendered == null) {
            throw StateError('No se pudo renderizar la página $pageNumber.');
          }

          final width =
              rendered.width ?? (page.width * _renderScale).round();
          final height =
              rendered.height ?? (page.height * _renderScale).round();
          if (width < 1 || height < 1) {
            throw StateError('Render vacío en la página $pageNumber.');
          }

          final stampedBytes = await _stampPageImage(
            pageBytes: rendered.bytes,
            width: width,
            height: height,
            signatures: byPage[pageNumber] ?? const [],
          );

          final pageFormat = pw.PdfPageFormat(
            page.width,
            page.height,
            marginAll: 0,
          );
          output.addPage(
            pdf.Page(
              pageFormat: pageFormat,
              build: (_) => pdf.Image(
                pdf.MemoryImage(stampedBytes),
                fit: pdf.BoxFit.fill,
              ),
            ),
          );
        } finally {
          await page.close();
        }
      }

      final pdfBytes = await output.save();
      await File(pdfPath).writeAsBytes(pdfBytes, flush: true);
      wrotePdf = true;
      final signedSha = _hashService.sha256Bytes(pdfBytes);

      final manifest = SignatureManifest(
        version: 1,
        exportedAt: DateTime.now().toUtc(),
        sourceFileName: p.basename(book.filePath),
        sourceSha256: sourceSha,
        signedFileName: pdfName,
        signedSha256: signedSha,
        signatures: List<DocumentSignature>.from(signatures),
      );
      await File(manifestPath).writeAsString(manifest.encodePretty());
      wroteManifest = true;

      return SignedPdfExportResult(
        pdfPath: pdfPath,
        manifestPath: manifestPath,
        manifest: manifest,
      );
    } catch (_) {
      await _deleteQuietly(wrotePdf ? pdfPath : null);
      await _deleteQuietly(wroteManifest ? manifestPath : null);
      rethrow;
    } finally {
      await document.close();
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
    required List<DocumentSignature> signatures,
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

        final stamp = SignatureStampGeometry.stampSizeFor(size);
        final maxLeft = SignatureStampGeometry.maxLeft(size);
        final maxTop = SignatureStampGeometry.maxTop(size);

        for (final signature in signatures) {
          final left = signature.offsetX.clamp(0.0, 1.0) * maxLeft;
          final top = signature.offsetY.clamp(0.0, 1.0) * maxTop;
          _paintStamp(
            canvas,
            Rect.fromLTWH(left, top, stamp.width, stamp.height),
            signature,
          );
        }

        final picture = recorder.endRecording();
        try {
          final stamped = await picture.toImage(width, height);
          try {
            final byteData =
                await stamped.toByteData(format: ui.ImageByteFormat.png);
            if (byteData == null) {
              throw StateError('No se pudo codificar la página firmada.');
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

  void _paintStamp(Canvas canvas, Rect rect, DocumentSignature signature) {
    final bg = Paint()..color = const Color(0xF5F3ECDD);
    final border = Paint()
      ..color = const Color(0xFFC89A5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, bg);
    canvas.drawRect(rect, border);

    final padding = rect.width * 0.06;
    final content = Rect.fromLTRB(
      rect.left + padding,
      rect.top + padding,
      rect.right - padding,
      rect.bottom - padding,
    );
    final scale = rect.width / SignatureStampGeometry.referenceStampWidth;

    final header = TextPainter(
      text: TextSpan(
        text: '${signature.role.labelEs} · #${signature.signingOrder}',
        style: TextStyle(
          color: const Color(0xFFC89A5A),
          fontSize: 11 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    TextPainter? rubrica;
    TextPainter? meta;
    try {
      header.layout(maxWidth: content.width);
      header.paint(canvas, content.topLeft);

      var cursorY = content.top + header.height + 4 * scale;
      if (signature.type == SignatureType.typed) {
        rubrica = TextPainter(
          text: TextSpan(
            text: signature.displayText,
            style: TextStyle(
              color: const Color(0xFF121D18),
              fontSize: 20 * scale,
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: content.width);
        rubrica.paint(canvas, Offset(content.left, cursorY));
        cursorY += rubrica.height + 4 * scale;
      } else {
        final inkRect = Rect.fromLTWH(
          content.left,
          cursorY,
          content.width,
          content.height * 0.38,
        );
        _paintInk(canvas, inkRect, signature.inkStrokes);
        cursorY = inkRect.bottom + 4 * scale;
      }

      meta = TextPainter(
        text: TextSpan(
          text: [
            signature.signerName,
            _formatDate(signature.signedAt),
            if (signature.reason != null && signature.reason!.isNotEmpty)
              signature.reason!,
          ].join('\n'),
          style: TextStyle(
            color: const Color(0xFF3D4A44),
            fontSize: 10 * scale,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: content.width);
      meta.paint(canvas, Offset(content.left, cursorY));
    } finally {
      header.dispose();
      rubrica?.dispose();
      meta?.dispose();
    }
  }

  void _paintInk(
    Canvas canvas,
    Rect rect,
    List<List<List<double>>> strokes,
  ) {
    final paint = Paint()
      ..color = const Color(0xFF121D18)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(
          rect.left + stroke.first[0] * rect.width,
          rect.top + stroke.first[1] * rect.height,
        );
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(
          rect.left + stroke[i][0] * rect.width,
          rect.top + stroke[i][1] * rect.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }
}
