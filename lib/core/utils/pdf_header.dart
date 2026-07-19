import 'dart:io';
import 'dart:typed_data';

/// Validación ligera de cabecera PDF (`%PDF`).
///
/// Exige magia real al persistir en biblioteca (no confiar solo en Content-Type).
/// Busca `%PDF` en los primeros [scanWindow] bytes (BOM / junk previo permitido).
abstract final class PdfHeader {
  static const List<int> magic = [0x25, 0x50, 0x44, 0x46]; // %PDF
  static const int scanWindow = 1024;

  static bool matchesBytes(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == magic[0] &&
        bytes[1] == magic[1] &&
        bytes[2] == magic[2] &&
        bytes[3] == magic[3];
  }

  /// True si `%PDF` aparece en los primeros [scanWindow] bytes.
  static bool containsMagic(List<int> bytes) {
    if (matchesBytes(bytes)) return true;
    final limit =
        bytes.length < scanWindow ? bytes.length : scanWindow;
    if (limit < 4) return false;
    for (var i = 0; i <= limit - 4; i++) {
      if (bytes[i] == magic[0] &&
          bytes[i + 1] == magic[1] &&
          bytes[i + 2] == magic[2] &&
          bytes[i + 3] == magic[3]) {
        return true;
      }
    }
    return false;
  }

  static Future<void> assertFile(
    File file, {
    String contentType = '',
    String invalidMessage = 'El archivo no es un PDF válido',
    bool requireMagic = true,
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
      final toRead = size < scanWindow ? size : scanWindow;
      final header = await raf.read(toRead);
      if (containsMagic(header)) return;
    } finally {
      await raf.close();
    }

    if (!requireMagic && contentType.toLowerCase().contains('pdf')) return;
    throw FormatException(invalidMessage);
  }

  static void assertBytes(
    Uint8List bytes, {
    String contentType = '',
    String invalidMessage = 'El archivo no es un PDF válido',
    bool requireMagic = true,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('PDF vacío');
    }
    if (containsMagic(bytes)) return;
    if (!requireMagic && contentType.toLowerCase().contains('pdf')) return;
    throw FormatException(invalidMessage);
  }
}
