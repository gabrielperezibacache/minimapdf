import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_locale.dart';
import '../theme/app_theme_option.dart';

/// Preferencias locales persistentes (tema, idioma, biblioteca, lector, onboarding).
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_option';
  static const _localeKey = 'app_locale';
  static const _gridModeKey = 'library_grid_mode';
  static const _ebonyFilterKey = 'reader_ebony_filter';
  static const _legacyEbonyFilterKey = 'reader_obsidian_filter';
  static const _scrollModeKey = 'reader_scroll_mode';
  static const _hasSeenWelcomeKey = 'has_seen_welcome';
  static const _hasSeenReaderTipKey = 'has_seen_reader_tip';
  static const _snapToTextKey = 'reader_snap_markup_to_text';

  static Future<AppPreferences> open() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(prefs);
  }

  AppThemeOption get themeOption {
    final raw = _prefs.getString(_themeKey);
    if (raw == null) return AppThemeOption.ebony;
    // Migración desde el nombre antiguo del tema oscuro.
    if (raw == 'obsidian') return AppThemeOption.ebony;
    return AppThemeOption.values.firstWhere(
      (option) => option.name == raw,
      orElse: () => AppThemeOption.ebony,
    );
  }

  Future<void> setThemeOption(AppThemeOption option) async {
    await _prefs.setString(_themeKey, option.name);
  }

  /// Idioma persistido, o `null` si el usuario aún no eligió uno.
  AppLocale? get storedAppLocale {
    final raw = _prefs.getString(_localeKey);
    if (raw == null || raw.isEmpty) return null;
    return AppLocaleX.fromCode(raw);
  }

  /// Idioma efectivo: preferencia guardada, o español como fallback legacy.
  AppLocale get appLocale => storedAppLocale ?? AppLocale.es;

  Future<void> setAppLocale(AppLocale locale) async {
    await _prefs.setString(_localeKey, locale.code);
  }

  bool get gridMode => _prefs.getBool(_gridModeKey) ?? true;

  Future<void> setGridMode(bool value) async {
    await _prefs.setBool(_gridModeKey, value);
  }

  bool get ebonyFilter =>
      _prefs.getBool(_ebonyFilterKey) ??
      _prefs.getBool(_legacyEbonyFilterKey) ??
      true;

  Future<void> setEbonyFilter(bool value) async {
    await _prefs.setBool(_ebonyFilterKey, value);
  }

  /// Nombre de [ReaderScrollMode] (p. ej. `verticalContinuous`).
  String get scrollModeName =>
      _prefs.getString(_scrollModeKey) ?? 'verticalContinuous';

  Future<void> setScrollModeName(String modeName) async {
    await _prefs.setString(_scrollModeKey, modeName);
  }

  /// `true` si ya se mostró (o se omitió) la bienvenida de primera apertura.
  bool get hasSeenWelcome => _prefs.getBool(_hasSeenWelcomeKey) ?? false;

  Future<void> markWelcomeSeen() async {
    await _prefs.setBool(_hasSeenWelcomeKey, true);
  }

  /// Tip de primera apertura del lector (lápiz bronce / anotar).
  bool get hasSeenReaderTip => _prefs.getBool(_hasSeenReaderTipKey) ?? false;

  Future<void> markReaderTipSeen() async {
    await _prefs.setBool(_hasSeenReaderTipKey, true);
  }

  /// Imantar marcado/subrayado a las líneas de texto detectadas en la página.
  bool get snapMarkupToText => _prefs.getBool(_snapToTextKey) ?? true;

  Future<void> setSnapMarkupToText(bool value) async {
    await _prefs.setBool(_snapToTextKey, value);
  }
}
