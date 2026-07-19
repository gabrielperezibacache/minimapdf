/// Utilidades para URLs de PDF (validación y detección).
abstract final class PdfUrlUtils {
  static final RegExp _pdfPath = RegExp(r'\.pdf([?#]|$)', caseSensitive: false);

  static bool isValidHttpUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  static bool looksLikePdfUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    return _pdfPath.hasMatch(uri.path) ||
        uri.query.toLowerCase().contains('application/pdf');
  }

  static String fileNameFromUrl(String raw, {String fallback = 'documento'}) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return '$fallback.pdf';

    final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (segment.toLowerCase().endsWith('.pdf') && segment.isNotEmpty) {
      return segment;
    }
    if (segment.isNotEmpty) return '$segment.pdf';
    return '$fallback.pdf';
  }

  static String normalizeUrl(String raw) => raw.trim();
}
