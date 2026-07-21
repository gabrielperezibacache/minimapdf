/// Entrada del índice del PDF (outline nativo aún no cableado al sidebar).
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
  ///
  /// [title] debe venir localizado (p. ej. [AppLocalizations.pageNumber]).
  /// Si se omite, se usa el fallback neutro en inglés.
  static PdfTocEntry forPage(int pageNumber, {String? title}) {
    return PdfTocEntry(
      title: title ?? 'Page $pageNumber',
      pageNumber: pageNumber,
    );
  }

  /// Índice por páginas (útil en tests; la UI preferirá [forPage]).
  static List<PdfTocEntry> fromPageCount(
    int pagesCount, {
    String Function(int pageNumber)? titleForPage,
  }) {
    if (pagesCount < 1) return const [];
    return List<PdfTocEntry>.generate(
      pagesCount,
      (index) {
        final page = index + 1;
        return forPage(
          page,
          title: titleForPage?.call(page),
        );
      },
      growable: false,
    );
  }
}
