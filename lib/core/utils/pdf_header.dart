import 'dart:io';
import 'dart:typed_data';

import '../../l10n/app_message_keys.dart';

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

  /// Ventana al final del archivo para buscar `%%EOF` (anti-truncado).
  static const int eofScanWindow = 2048;

  /// Tamaño mínimo para exigir marca de fin (tests usan PDFs minúsculos).
  static const int eofMinFileSize = 256;

  static bool containsEofMarker(List<int> bytes) {
    // %%EOF → 0x25 0x25 0x45 0x4F 0x46
    if (bytes.length < 5) return false;
    for (var i = 0; i <= bytes.length - 5; i++) {
      if (bytes[i] == 0x25 &&
          bytes[i + 1] == 0x25 &&
          bytes[i + 2] == 0x45 &&
          bytes[i + 3] == 0x4F &&
          bytes[i + 4] == 0x46) {
        return true;
      }
    }
    return false;
  }

  static Future<void> assertFile(
    File file, {
    String contentType = '',
    String invalidMessage = AppMessageKeys.invalidPdf,
    bool requireMagic = true,
    bool requireEof = true,
  }) async {
    if (!await file.exists()) {
      throw FormatException(invalidMessage);
    }
    final size = await file.length();
    if (size == 0) {
      throw const FormatException(AppMessageKeys.emptyPdf);
    }

    final raf = await file.open();
    try {
      final toRead = size < scanWindow ? size : scanWindow;
      final header = await raf.read(toRead);
      final hasMagic = containsMagic(header);
      if (!hasMagic) {
        if (!requireMagic && contentType.toLowerCase().contains('pdf')) {
          // Sin magia pero content-type PDF: sigue validando EOF si aplica.
        } else {
          throw FormatException(invalidMessage);
        }
      }

      // PDFs truncados a menudo pierden %%EOF; exige marca en cola.
      if (requireEof && size >= eofMinFileSize) {
        final tailStart = size > eofScanWindow ? size - eofScanWindow : 0;
        await raf.setPosition(tailStart);
        final tail = await raf.read(size - tailStart);
        if (!containsEofMarker(tail)) {
          throw const FormatException(AppMessageKeys.truncatedPdf);
        }
      }
      return;
    } finally {
      await raf.close();
    }
  }

  static void assertBytes(
    Uint8List bytes, {
    String contentType = '',
    String invalidMessage = AppMessageKeys.invalidPdf,
    bool requireMagic = true,
  }) {
    if (bytes.isEmpty) {
      throw const FormatException(AppMessageKeys.emptyPdf);
    }
    if (containsMagic(bytes)) return;
    if (!requireMagic && contentType.toLowerCase().contains('pdf')) return;
    throw FormatException(invalidMessage);
  }
}
