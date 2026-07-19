/// Entrada del índice del PDF (outline nativo no expuesto por pdfx).
///
/// Se genera un índice navegable por páginas para saltos rápidos.
class PdfTocEntry {
  const PdfTocEntry({
    required this.title,
    required this.pageNumber,
    this.level = 0,
  });

  final String title;
  final int pageNumber;
  final int level;

  /// Índice por páginas (lazy-friendly; la UI usa ListView.builder).
  static List<PdfTocEntry> fromPageCount(
    int pagesCount, {
    required String Function(int page) pageTitle,
  }) {
    if (pagesCount < 1) return const [];
    return List<PdfTocEntry>.generate(
      pagesCount,
      (index) {
        final page = index + 1;
        return PdfTocEntry(title: pageTitle(page), pageNumber: page);
      },
      growable: false,
    );
  }
}
