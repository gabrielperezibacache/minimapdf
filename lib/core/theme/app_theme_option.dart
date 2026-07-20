import '../../l10n/app_localizations.dart';

/// Temas visuales disponibles en Minimal PDF.
enum AppThemeOption {
  light,
  sepia,
  ebony,
}

extension AppThemeOptionX on AppThemeOption {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        AppThemeOption.light => l10n.themeLight,
        AppThemeOption.sepia => l10n.themeSepia,
        AppThemeOption.ebony => l10n.themeEbony,
      };
}
