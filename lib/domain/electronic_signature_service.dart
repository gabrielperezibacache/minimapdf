import 'dart:convert';
import 'dart:math' as math;

import '../data/models/document_signature.dart';
import '../data/models/signature_type.dart';

/// Borrador de firma electrónica antes de persistir.
class SignatureDraft {
  const SignatureDraft({
    required this.type,
    required this.signerName,
    this.typedText,
    this.inkStrokes = const [],
    this.reason,
    this.offsetX,
    this.offsetY,
  });

  final SignatureType type;
  final String signerName;
  final String? typedText;
  final List<List<List<double>>> inkStrokes;
  final String? reason;
  final double? offsetX;
  final double? offsetY;
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

  static const int maxSignerNameLength = 80;
  static const int maxTypedTextLength = 80;
  static const int maxReasonLength = 120;
  static const double defaultOffsetX = 0.58;
  static const double defaultOffsetY = 0.70;
  static const double _offsetStepX = 0.04;
  static const double _offsetStepY = 0.08;

  /// Valida un borrador sin construir la firma (útil en UI).
  void validateDraft(SignatureDraft draft, {required int pageNumber}) {
    if (pageNumber < 1) {
      throw SignatureValidationException('Página no válida para firmar.');
    }

    final signerName = draft.signerName.trim();
    if (signerName.isEmpty) {
      throw SignatureValidationException('Indica el nombre del firmante.');
    }
    if (signerName.length > maxSignerNameLength) {
      throw SignatureValidationException(
        'El nombre del firmante es demasiado largo.',
      );
    }

    final reason = draft.reason?.trim();
    if (reason != null && reason.length > maxReasonLength) {
      throw SignatureValidationException('El motivo es demasiado largo.');
    }

    switch (draft.type) {
      case SignatureType.typed:
        final typed = (draft.typedText ?? signerName).trim();
        if (typed.isEmpty) {
          throw SignatureValidationException(
            'Escribe el texto de la firma mecanografiada.',
          );
        }
        if (typed.length > maxTypedTextLength) {
          throw SignatureValidationException(
            'El texto de la firma es demasiado largo.',
          );
        }
      case SignatureType.drawn:
        if (_normalizeStrokes(draft.inkStrokes).isEmpty) {
          throw SignatureValidationException(
            'Dibuja tu firma antes de guardar.',
          );
        }
    }
  }

  /// Construye una [DocumentSignature] lista para persistir.
  ///
  /// Lanza [SignatureValidationException] si faltan datos del firmante
  /// o el trazo/texto de la firma.
  DocumentSignature signDocument({
    required int bookId,
    required int pageNumber,
    required SignatureDraft draft,
    DateTime? signedAt,
    List<DocumentSignature> existingOnPage = const [],
  }) {
    if (bookId < 1) {
      throw SignatureValidationException('Documento no válido para firmar.');
    }
    validateDraft(draft, pageNumber: pageNumber);

    final signerName = draft.signerName.trim();
    final reason = draft.reason?.trim();
    final when = signedAt ?? DateTime.now();
    final suggested = suggestOffset(existingOnPage);
    final offsetX =
        (draft.offsetX ?? suggested.$1).clamp(0.0, 1.0).toDouble();
    final offsetY =
        (draft.offsetY ?? suggested.$2).clamp(0.0, 1.0).toDouble();
    final cleanReason =
        (reason == null || reason.isEmpty) ? null : reason;

    switch (draft.type) {
      case SignatureType.typed:
        final typed = (draft.typedText ?? signerName).trim();
        return DocumentSignature(
          bookId: bookId,
          pageNumber: pageNumber,
          type: SignatureType.typed,
          signerName: signerName,
          typedText: typed,
          reason: cleanReason,
          offsetX: offsetX,
          offsetY: offsetY,
          signedAt: when,
        );

      case SignatureType.drawn:
        final strokes = _normalizeStrokes(draft.inkStrokes);
        return DocumentSignature(
          bookId: bookId,
          pageNumber: pageNumber,
          type: SignatureType.drawn,
          signerName: signerName,
          inkJson: jsonEncode(strokes),
          reason: cleanReason,
          offsetX: offsetX,
          offsetY: offsetY,
          signedAt: when,
        );
    }
  }

  /// Sugiere una posición libre en la página para no solapar firmas.
  (double, double) suggestOffset(List<DocumentSignature> existingOnPage) {
    if (existingOnPage.isEmpty) {
      return (defaultOffsetX, defaultOffsetY);
    }

    var x = defaultOffsetX;
    var y = defaultOffsetY;
    for (var i = 0; i < existingOnPage.length; i++) {
      x = (defaultOffsetX - (i + 1) * _offsetStepX).clamp(0.05, 0.85);
      y = (defaultOffsetY - (i + 1) * _offsetStepY).clamp(0.08, 0.85);
    }
    return (x.toDouble(), y.toDouble());
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
        final next = [
          point[0].clamp(0.0, 1.0).toDouble(),
          point[1].clamp(0.0, 1.0).toDouble(),
        ];
        if (points.isNotEmpty) {
          final prev = points.last;
          final dx = next[0] - prev[0];
          final dy = next[1] - prev[1];
          // Descarta puntos casi idénticos para reducir ruido/JSON.
          if (math.sqrt(dx * dx + dy * dy) < 0.002) continue;
        }
        points.add(next);
      }
      if (points.length >= 2) {
        normalized.add(points);
      }
    }
    return normalized;
  }
}
