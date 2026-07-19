import '../../l10n/app_localizations.dart';

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

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        ReaderScrollMode.verticalContinuous => l10n.scrollVertical,
        ReaderScrollMode.horizontalPaged => l10n.scrollPaged,
      };

  bool get isVertical => this == ReaderScrollMode.verticalContinuous;
}
