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
  static const double minOffsetDistance = 0.12;
  static const double _offsetStepX = 0.05;
  static const double _offsetStepY = 0.10;
  static final RegExp _multiSpace = RegExp(r'\s+');

  /// Valida un borrador sin construir la firma (útil en UI).
  void validateDraft(SignatureDraft draft, {required int pageNumber}) {
    if (pageNumber < 1) {
      throw SignatureValidationException('Página no válida para firmar.');
    }

    final signerName = normalizePersonText(draft.signerName);
    if (signerName.isEmpty) {
      throw SignatureValidationException('Indica el nombre del firmante.');
    }
    if (signerName.length > maxSignerNameLength) {
      throw SignatureValidationException(
        'El nombre del firmante es demasiado largo.',
      );
    }

    final reason = normalizeOptionalText(draft.reason);
    if (reason != null && reason.length > maxReasonLength) {
      throw SignatureValidationException('El motivo es demasiado largo.');
    }

    switch (draft.type) {
      case SignatureType.typed:
        final typed = normalizePersonText(draft.typedText ?? signerName);
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
        if (normalizeStrokes(draft.inkStrokes).isEmpty) {
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

    final signerName = normalizePersonText(draft.signerName);
    final reason = normalizeOptionalText(draft.reason);
    final when = signedAt ?? DateTime.now();
    final suggested = suggestOffset(existingOnPage);
    final offsetX =
        (draft.offsetX ?? suggested.$1).clamp(0.0, 1.0).toDouble();
    final offsetY =
        (draft.offsetY ?? suggested.$2).clamp(0.0, 1.0).toDouble();

    switch (draft.type) {
      case SignatureType.typed:
        final typed = normalizePersonText(draft.typedText ?? signerName);
        return DocumentSignature(
          bookId: bookId,
          pageNumber: pageNumber,
          type: SignatureType.typed,
          signerName: signerName,
          typedText: typed,
          reason: reason,
          offsetX: offsetX,
          offsetY: offsetY,
          signedAt: when,
        );

      case SignatureType.drawn:
        final strokes = normalizeStrokes(draft.inkStrokes);
        return DocumentSignature(
          bookId: bookId,
          pageNumber: pageNumber,
          type: SignatureType.drawn,
          signerName: signerName,
          inkJson: jsonEncode(strokes),
          reason: reason,
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

    for (var i = 0; i < 24; i++) {
      final x = (defaultOffsetX - i * _offsetStepX).clamp(0.05, 0.85).toDouble();
      final y = (defaultOffsetY - i * _offsetStepY).clamp(0.08, 0.85).toDouble();
      if (_isFarFromAll(x, y, existingOnPage)) {
        return (x, y);
      }
    }

    // Barrido secundario (rejilla) si la escalera está ocupada.
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 5; col++) {
        final x = (0.15 + col * 0.15).clamp(0.05, 0.85).toDouble();
        final y = (0.20 + row * 0.15).clamp(0.08, 0.85).toDouble();
        if (_isFarFromAll(x, y, existingOnPage)) {
          return (x, y);
        }
      }
    }

    return (0.10, 0.12);
  }

  /// Serializa trazos dibujados a JSON (útil para previsualización / tests).
  String encodeInk(List<List<List<double>>> strokes) {
    return jsonEncode(normalizeStrokes(strokes));
  }

  /// Normaliza nombre/rúbrica: trim + colapsa espacios internos.
  String normalizePersonText(String raw) {
    return raw.trim().replaceAll(_multiSpace, ' ');
  }

  String? normalizeOptionalText(String? raw) {
    if (raw == null) return null;
    final normalized = normalizePersonText(raw);
    return normalized.isEmpty ? null : normalized;
  }

  /// Normaliza trazos: clamp 0–1, descarta NaN/Inf y puntos casi duplicados.
  List<List<List<double>>> normalizeStrokes(
    List<List<List<double>>> strokes,
  ) {
    final normalized = <List<List<double>>>[];
    for (final stroke in strokes) {
      final points = <List<double>>[];
      for (final point in stroke) {
        if (point.length < 2) continue;
        final x = point[0];
        final y = point[1];
        if (!x.isFinite || !y.isFinite) continue;
        final next = [
          x.clamp(0.0, 1.0).toDouble(),
          y.clamp(0.0, 1.0).toDouble(),
        ];
        if (points.isNotEmpty) {
          final prev = points.last;
          final dx = next[0] - prev[0];
          final dy = next[1] - prev[1];
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

  bool _isFarFromAll(
    double x,
    double y,
    List<DocumentSignature> existingOnPage,
  ) {
    final minDist2 = minOffsetDistance * minOffsetDistance;
    for (final item in existingOnPage) {
      final dx = item.offsetX - x;
      final dy = item.offsetY - y;
      if (dx * dx + dy * dy < minDist2) return false;
    }
    return true;
  }
}
