import 'dart:io';

import 'package:crypto/crypto.dart';

/// Utilidades de integridad (SHA-256) para PDFs firmados offline.
class DocumentHashService {
  const DocumentHashService();

  Future<String> sha256File(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Archivo no encontrado: $path');
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String sha256Bytes(List<int> bytes) => sha256.convert(bytes).toString();
}
