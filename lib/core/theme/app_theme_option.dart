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
}
