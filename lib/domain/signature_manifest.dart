import 'dart:convert';

import '../data/models/document_signature.dart';

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
}
