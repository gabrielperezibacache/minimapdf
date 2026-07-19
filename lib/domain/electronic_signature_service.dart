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
  static const int maxStrokes = 40;
  static const int maxPointsPerStroke = 400;
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
    final offsetX = _finiteClamp(
      draft.offsetX ?? suggested.$1,
      fallback: defaultOffsetX,
    );
    final offsetY = _finiteClamp(
      draft.offsetY ?? suggested.$2,
      fallback: defaultOffsetY,
    );

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
  ///
  /// Si no hay hueco con [minOffsetDistance], elige el candidato que
  /// maximiza la distancia al vecino más cercano (maximin).
  (double, double) suggestOffset(List<DocumentSignature> existingOnPage) {
    if (existingOnPage.isEmpty) {
      return (defaultOffsetX, defaultOffsetY);
    }

    final candidates = _offsetCandidates();
    for (final candidate in candidates) {
      if (_isFarFromAll(candidate.$1, candidate.$2, existingOnPage)) {
        return candidate;
      }
    }

    return _bestAvailableOffset(candidates, existingOnPage);
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
  ///
  /// Aplica techos [maxStrokes] / [maxPointsPerStroke] (submuestreo uniforme).
  List<List<List<double>>> normalizeStrokes(
    List<List<List<double>>> strokes,
  ) {
    final normalized = <List<List<double>>>[];
    for (final stroke in strokes) {
      if (normalized.length >= maxStrokes) break;
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
        normalized.add(_downsample(points, maxPointsPerStroke));
      }
    }
    return normalized;
  }

  List<List<double>> _downsample(List<List<double>> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    if (maxPoints < 2) return points.sublist(0, points.length.clamp(0, 2));

    final sampled = <List<double>>[points.first];
    final lastIndex = points.length - 1;
    for (var i = 1; i < maxPoints - 1; i++) {
      final index = ((i * lastIndex) / (maxPoints - 1)).round();
      sampled.add(points[index]);
    }
    sampled.add(points.last);
    return sampled;
  }

  List<(double, double)> _offsetCandidates() {
    final candidates = <(double, double)>[];
    final seen = <String>{};

    void add(double x, double y) {
      final cx = x.clamp(0.05, 0.85).toDouble();
      final cy = y.clamp(0.08, 0.85).toDouble();
      final key = '${cx.toStringAsFixed(3)}:${cy.toStringAsFixed(3)}';
      if (seen.add(key)) {
        candidates.add((cx, cy));
      }
    }

    add(defaultOffsetX, defaultOffsetY);
    for (var i = 1; i < 24; i++) {
      add(defaultOffsetX - i * _offsetStepX, defaultOffsetY - i * _offsetStepY);
    }
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        add(0.08 + col * 0.11, 0.08 + row * 0.11);
      }
    }
    return candidates;
  }

  (double, double) _bestAvailableOffset(
    List<(double, double)> candidates,
    List<DocumentSignature> existingOnPage,
  ) {
    var best = candidates.first;
    var bestScore = -1.0;

    for (final candidate in candidates) {
      var nearest = double.infinity;
      for (final item in existingOnPage) {
        final dx = item.offsetX - candidate.$1;
        final dy = item.offsetY - candidate.$2;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < nearest) nearest = distance;
      }
      if (nearest > bestScore) {
        bestScore = nearest;
        best = candidate;
      }
    }
    return best;
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

  double _finiteClamp(double value, {required double fallback}) {
    if (!value.isFinite) return fallback;
    return value.clamp(0.0, 1.0).toDouble();
  }
}
