import 'dart:io';
import 'dart:typed_data';

/// Validación ligera de cabecera PDF (`%PDF`).
abstract final class PdfHeader {
  static const List<int> magic = [0x25, 0x50, 0x44, 0x46]; // %PDF

  static bool matchesBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == magic[0] &&
        bytes[1] == magic[1] &&
        bytes[2] == magic[2] &&
        bytes[3] == magic[3];
  }

  static Future<void> assertFile(
    File file, {
    String contentType = '',
    String invalidMessage = 'El archivo no es un PDF válido',
  }) async {
    if (!await file.exists()) {
      throw FormatException(invalidMessage);
    }
    final size = await file.length();
    if (size == 0) {
      throw const FormatException('PDF vacío');
    }

    final raf = await file.open();
    try {
      final header = await raf.read(4);
      if (matchesBytes(header)) return;
    } finally {
      await raf.close();
    }

    if (contentType.toLowerCase().contains('pdf')) return;
    throw FormatException(invalidMessage);
  }

  static void assertBytes(
    Uint8List bytes, {
    String contentType = '',
    String invalidMessage = 'El archivo no es un PDF válido',
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('PDF vacío');
    }
    if (matchesBytes(bytes)) return;
    if (contentType.toLowerCase().contains('pdf')) return;
    throw FormatException(invalidMessage);
  }
}
