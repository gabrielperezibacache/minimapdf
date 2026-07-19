import 'dart:convert';

import '../data/models/document_signature.dart';
import '../data/models/signature_role.dart';
import '../data/models/signature_type.dart';

/// Manifiesto local de integridad para un PDF firmado (SES offline).
class SignatureManifest {
  const SignatureManifest({
    required this.version,
    required this.exportedAt,
    required this.sourceFileName,
    required this.sourceSha256,
    required this.signedFileName,
    required this.signedSha256,
    required this.signatures,
  });

  final int version;
  final DateTime exportedAt;
  final String sourceFileName;
  final String sourceSha256;
  final String signedFileName;
  final String signedSha256;
  final List<DocumentSignature> signatures;

  Map<String, Object?> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'sourceFileName': sourceFileName,
      'sourceSha256': sourceSha256,
      'signedFileName': signedFileName,
      'signedSha256': signedSha256,
      'signatureCount': signatures.length,
      'signatures': [
        for (final signature in signatures) signature.toManifestMap(),
      ],
    };
  }

  String encodePretty() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  /// Comprueba si el hash actual del PDF firmado coincide con el manifiesto.
  bool matchesSignedHash(String currentSignedSha256) {
    return currentSignedSha256.toLowerCase() == signedSha256.toLowerCase();
  }

  factory SignatureManifest.fromJson(Map<String, Object?> json) {
    final rawSignatures = json['signatures'];
    final signatures = <DocumentSignature>[];
    if (rawSignatures is List) {
      for (final item in rawSignatures) {
        if (item is! Map) continue;
        final map = Map<String, Object?>.from(item);
        signatures.add(
          DocumentSignature(
            id: (map['id'] as num?)?.toInt(),
            bookId: 0,
            pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 1,
            type: SignatureTypeX.fromStorage(
              (map['type'] as String?) ?? 'typed',
            ),
            signerName: (map['signerName'] as String?) ?? '',
            typedText: map['typedText'] as String?,
            inkJson: map['inkJson'] as String?,
            reason: map['reason'] as String?,
            role: SignatureRoleX.fromStorage(map['role'] as String?),
            signingOrder: (map['signingOrder'] as num?)?.toInt() ?? 1,
            offsetX: (map['offsetX'] as num?)?.toDouble() ?? 0.58,
            offsetY: (map['offsetY'] as num?)?.toDouble() ?? 0.70,
            signedAt: DateTime.tryParse(map['signedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    }

    return SignatureManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      sourceFileName: (json['sourceFileName'] as String?) ?? '',
      sourceSha256: (json['sourceSha256'] as String?) ?? '',
      signedFileName: (json['signedFileName'] as String?) ?? '',
      signedSha256: (json['signedSha256'] as String?) ?? '',
      signatures: signatures,
    );
  }

  static SignatureManifest decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Manifiesto JSON inválido.');
    }
    return SignatureManifest.fromJson(Map<String, Object?>.from(decoded));
  }
}
