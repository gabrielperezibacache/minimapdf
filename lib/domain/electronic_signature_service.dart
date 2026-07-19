import 'dart:convert';

import '../data/models/document_signature.dart';
import '../data/models/signature_type.dart';

/// Resultado de validar o construir una firma electrónica.
class SignatureDraft {
  const SignatureDraft({
    required this.type,
    required this.signerName,
    this.typedText,
    this.inkStrokes = const [],
    this.reason,
    this.offsetX = 0.55,
    this.offsetY = 0.72,
  });

  final SignatureType type;
  final String signerName;
  final String? typedText;
  final List<List<List<double>>> inkStrokes;
  final String? reason;
  final double offsetX;
  final double offsetY;
}

/// Errores de validación al firmar un documento.
class SignatureValidationException implements Exception {
  SignatureValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Función de dominio para firmar documentos electrónicos de forma local.
///
/// Soporta:
/// - **Firma electrónica simple** dibujada (trazo manuscrito).
/// - **Firma mecanografiada** (nombre / rúbrica con teclado).
///
/// No emite certificados PKI ni firmas cualificadas: es una SES offline
/// con identidad declarada, método y marca temporal.
class ElectronicSignatureService {
  const ElectronicSignatureService();

  /// Construye una [DocumentSignature] lista para persistir.
  ///
  /// Lanza [SignatureValidationException] si faltan datos del firmante
  /// o el trazo/texto de la firma.
  DocumentSignature signDocument({
    required int bookId,
    required int pageNumber,
    required SignatureDraft draft,
    DateTime? signedAt,
  }) {
    if (bookId < 1) {
      throw SignatureValidationException('Documento no válido para firmar.');
    }
    if (pageNumber < 1) {
      throw SignatureValidationException('Página no válida para firmar.');
    }

    final signerName = draft.signerName.trim();
    if (signerName.isEmpty) {
      throw SignatureValidationException(
        'Indica el nombre del firmante.',
      );
    }

    final reason = draft.reason?.trim();
    final clampedX = draft.offsetX.clamp(0.0, 1.0).toDouble();
    final clampedY = draft.offsetY.clamp(0.0, 1.0).toDouble();
    final when = signedAt ?? DateTime.now();

    switch (draft.type) {
      case SignatureType.typed:
        final typed = (draft.typedText ?? signerName).trim();
        if (typed.isEmpty) {
          throw SignatureValidationException(
            'Escribe el texto de la firma mecanografiada.',
          );
        }
        return DocumentSignature(
          bookId: bookId,
          pageNumber: pageNumber,
          type: SignatureType.typed,
          signerName: signerName,
          typedText: typed,
          reason: (reason == null || reason.isEmpty) ? null : reason,
          offsetX: clampedX,
          offsetY: clampedY,
          signedAt: when,
        );

      case SignatureType.drawn:
        final strokes = _normalizeStrokes(draft.inkStrokes);
        if (strokes.isEmpty) {
          throw SignatureValidationException(
            'Dibuja tu firma antes de guardar.',
          );
        }
        return DocumentSignature(
          bookId: bookId,
          pageNumber: pageNumber,
          type: SignatureType.drawn,
          signerName: signerName,
          inkJson: jsonEncode(strokes),
          reason: (reason == null || reason.isEmpty) ? null : reason,
          offsetX: clampedX,
          offsetY: clampedY,
          signedAt: when,
        );
    }
  }

  /// Serializa trazos dibujados a JSON (útil para previsualización / tests).
  String encodeInk(List<List<List<double>>> strokes) {
    return jsonEncode(_normalizeStrokes(strokes));
  }

  List<List<List<double>>> _normalizeStrokes(
    List<List<List<double>>> strokes,
  ) {
    final normalized = <List<List<double>>>[];
    for (final stroke in strokes) {
      final points = <List<double>>[];
      for (final point in stroke) {
        if (point.length < 2) continue;
        points.add([
          point[0].clamp(0.0, 1.0).toDouble(),
          point[1].clamp(0.0, 1.0).toDouble(),
        ]);
      }
      if (points.length >= 2) {
        normalized.add(points);
      }
    }
    return normalized;
  }
}
