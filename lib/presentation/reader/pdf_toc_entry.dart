/// Entrada del índice del PDF (outline nativo no expuesto por pdfx).
///
/// Se genera bajo demanda por página para evitar listas enormes en memoria.
class PdfTocEntry {
  const PdfTocEntry({
    required this.title,
    required this.pageNumber,
    this.level = 0,
  });

  final String title;
  final int pageNumber;
  final int level;

  /// Entrada puntual para [ListView.builder] (O(1), sin preasignar N).
  static PdfTocEntry forPage(int pageNumber) {
    return PdfTocEntry(title: 'Página $pageNumber', pageNumber: pageNumber);
  }

  /// Índice por páginas (útil en tests; la UI preferirá [forPage]).
  static List<PdfTocEntry> fromPageCount(int pagesCount) {
    if (pagesCount < 1) return const [];
    return List<PdfTocEntry>.generate(
      pagesCount,
      (index) => forPage(index + 1),
      growable: false,
    );
  }
}
