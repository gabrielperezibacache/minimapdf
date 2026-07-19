import 'package:flutter/material.dart';

/// Idiomas soportados por Minimal PDF.
enum AppLocale {
  es,
  en,
  pt,
  fr,
}

extension AppLocaleX on AppLocale {
  Locale get locale => Locale(code);

  String get code => switch (this) {
        AppLocale.es => 'es',
        AppLocale.en => 'en',
        AppLocale.pt => 'pt',
        AppLocale.fr => 'fr',
      };

  /// Nombre del idioma en su propia lengua (para el selector).
  String get nativeLabel => switch (this) {
        AppLocale.es => 'Español',
        AppLocale.en => 'English',
        AppLocale.pt => 'Português',
        AppLocale.fr => 'Français',
      };

  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (value) => value.code == code,
      orElse: () => AppLocale.es,
    );
  }

  static AppLocale fromLocale(Locale locale) => fromCode(locale.languageCode);
}
