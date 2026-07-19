import 'package:flutter/material.dart';

/// Idiomas soportados por Minimal PDF.
enum AppLocale {
  es,
  en,
  pt,
  fr,
  de,
  zh,
  ru,
}

extension AppLocaleX on AppLocale {
  Locale get locale => Locale(code);

  String get code => switch (this) {
        AppLocale.es => 'es',
        AppLocale.en => 'en',
        AppLocale.pt => 'pt',
        AppLocale.fr => 'fr',
        AppLocale.de => 'de',
        AppLocale.zh => 'zh',
        AppLocale.ru => 'ru',
      };

  /// Nombre del idioma en su propia lengua (para el selector).
  String get nativeLabel => switch (this) {
        AppLocale.es => 'Español',
        AppLocale.en => 'English',
        AppLocale.pt => 'Português',
        AppLocale.fr => 'Français',
        AppLocale.de => 'Deutsch',
        AppLocale.zh => '中文',
        AppLocale.ru => 'Русский',
      };

  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (value) => value.code == code,
      orElse: () => AppLocale.es,
    );
  }

  static AppLocale fromLocale(Locale locale) => fromCode(locale.languageCode);
}
