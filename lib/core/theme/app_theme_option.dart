import '../../l10n/app_localizations.dart';

/// Temas visuales disponibles en Minimal PDF.
enum AppThemeOption {
  light,
  sepia,
  ebony,
}

extension AppThemeOptionX on AppThemeOption {
  String get label => switch (this) {
        AppThemeOption.light => 'Claro',
        AppThemeOption.sepia => 'Sepia',
        AppThemeOption.ebony => 'Ébano',
      };

  String localizedLabel(AppLocalizations l10n) => switch (this) {
        AppThemeOption.light => l10n.themeLight,
        AppThemeOption.sepia => l10n.themeSepia,
        AppThemeOption.ebony => l10n.themeEbony,
      };
}
