/// Utilidades para URLs de PDF (validación y detección).
abstract final class PdfUrlUtils {
  static final RegExp _pdfExtension =
      RegExp(r'\.pdf([?#]|$)', caseSensitive: false);

  /// Rutas tipo arXiv/CDN: `/pdf/1234.5678` o `/pdf/id/download`.
  static final RegExp _pdfPathSegment =
      RegExp(r'(^|/)pdf(/|$)', caseSensitive: false);

  static bool isValidHttpUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return uri.host.isNotEmpty;
  }

  static bool looksLikePdfUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    final path = uri.path;
    if (_pdfExtension.hasMatch(path)) return true;
    if (uri.query.toLowerCase().contains('application/pdf')) return true;
    // /pdf/... (arXiv y similares) sin extensión .pdf
    if (_pdfPathSegment.hasMatch(path) && path.toLowerCase() != '/pdf') {
      return true;
    }
    return false;
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
