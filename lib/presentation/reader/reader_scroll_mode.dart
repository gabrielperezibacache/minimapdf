/// Modos de navegación del lector PDF.
enum ReaderScrollMode {
  /// Scroll continuo vertical (páginas encadenadas).
  verticalContinuous,

  /// Página a página horizontal.
  horizontalPaged,
}

extension ReaderScrollModeX on ReaderScrollMode {
  String get label => switch (this) {
        ReaderScrollMode.verticalContinuous => 'Vertical',
        ReaderScrollMode.horizontalPaged => 'Páginas',
      };

  bool get isVertical => this == ReaderScrollMode.verticalContinuous;
}
