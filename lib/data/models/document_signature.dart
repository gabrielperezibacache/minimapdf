import 'dart:convert';

import 'signature_role.dart';
import 'signature_type.dart';

/// Firma electrónica asociada a una página de un PDF local.
///
/// Representa una firma electrónica simple (SES): identidad declarada,
/// método (dibujada o mecanografiada), marca temporal y posición en página.
class DocumentSignature {
  const DocumentSignature({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.type,
    required this.signerName,
    this.typedText,
    this.inkJson,
    this.reason,
    this.role = SignatureRole.signer,
    this.signingOrder = 1,
    this.offsetX = 0.58,
    this.offsetY = 0.70,
    required this.signedAt,
  });

  final int? id;
  final int bookId;
  final int pageNumber;
  final SignatureType type;
  final String signerName;

  /// Texto mostrado en firma mecanografiada (por defecto [signerName]).
  final String? typedText;

  /// Trazos normalizados (0–1) serializados como JSON para firma dibujada.
  /// Formato: `[[[x,y], ...], ...]` por trazo.
  final String? inkJson;

  final String? reason;
  final SignatureRole role;

  /// Orden relativo entre firmas del documento (1 = primera).
  final int signingOrder;

  /// Posición relativa del sello en la página (0–1).
  final double offsetX;
  final double offsetY;

  final DateTime signedAt;

  String get displayText {
    final typed = typedText?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (typed != null && typed.isNotEmpty) return typed;
    return signerName.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<List<List<double>>> get inkStrokes {
    final raw = inkJson;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map<List<List<double>>>((stroke) {
            if (stroke is! List) return <List<double>>[];
            final points = <List<double>>[];
            for (final point in stroke) {
              if (point is! List || point.length < 2) continue;
              if (point[0] is! num || point[1] is! num) continue;
              final x = (point[0] as num).toDouble();
              final y = (point[1] as num).toDouble();
              if (!x.isFinite || !y.isFinite) continue;
              points.add([x, y]);
            }
            return points;
          })
          .where((stroke) => stroke.length >= 2)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  DocumentSignature copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    SignatureType? type,
    String? signerName,
    String? typedText,
    String? inkJson,
    String? reason,
    SignatureRole? role,
    int? signingOrder,
    double? offsetX,
    double? offsetY,
    DateTime? signedAt,
    bool clearTypedText = false,
    bool clearInkJson = false,
    bool clearReason = false,
  }) {
    return DocumentSignature(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      type: type ?? this.type,
      signerName: signerName ?? this.signerName,
      typedText: clearTypedText ? null : (typedText ?? this.typedText),
      inkJson: clearInkJson ? null : (inkJson ?? this.inkJson),
      reason: clearReason ? null : (reason ?? this.reason),
      role: role ?? this.role,
      signingOrder: signingOrder ?? this.signingOrder,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      signedAt: signedAt ?? this.signedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'page_number': pageNumber,
      'type': type.storageValue,
      'signer_name': signerName,
      'typed_text': typedText,
      'ink_json': inkJson,
      'reason': reason,
      'role': role.storageValue,
      'signing_order': signingOrder,
      'offset_x': offsetX,
      'offset_y': offsetY,
      'signed_at': signedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toManifestMap() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'type': type.storageValue,
      'signerName': signerName,
      'typedText': typedText,
      'reason': reason,
      'role': role.storageValue,
      'signingOrder': signingOrder,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'signedAt': signedAt.toIso8601String(),
      'hasInk': inkStrokes.isNotEmpty,
    };
  }

  factory DocumentSignature.fromMap(Map<String, Object?> map) {
    return DocumentSignature(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      pageNumber: map['page_number'] as int,
      type: SignatureTypeX.fromStorage(map['type'] as String),
      signerName: map['signer_name'] as String,
      typedText: map['typed_text'] as String?,
      inkJson: map['ink_json'] as String?,
      reason: map['reason'] as String?,
      role: SignatureRoleX.fromStorage(map['role'] as String?),
      signingOrder: (map['signing_order'] as num?)?.toInt() ?? 1,
      offsetX: (map['offset_x'] as num?)?.toDouble() ?? 0.58,
      offsetY: (map['offset_y'] as num?)?.toDouble() ?? 0.70,
      signedAt: DateTime.parse(map['signed_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentSignature &&
        other.id == id &&
        other.bookId == bookId &&
        other.pageNumber == pageNumber &&
        other.type == type &&
        other.signerName == signerName &&
        other.typedText == typedText &&
        other.inkJson == inkJson &&
        other.reason == reason &&
        other.role == role &&
        other.signingOrder == signingOrder &&
        other.offsetX == offsetX &&
        other.offsetY == offsetY &&
        other.signedAt == signedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        bookId,
        pageNumber,
        type,
        signerName,
        typedText,
        inkJson,
        reason,
        role,
        signingOrder,
        offsetX,
        offsetY,
        signedAt,
      );
}
