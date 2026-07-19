import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme_option.dart';

/// Preferencias locales persistentes (tema, biblioteca, lector, onboarding).
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_option';
  static const _gridModeKey = 'library_grid_mode';
  static const _obsidianFilterKey = 'reader_obsidian_filter';
  static const _scrollModeKey = 'reader_scroll_mode';
  static const _hasSeenWelcomeKey = 'has_seen_welcome';

  static Future<AppPreferences> open() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences(prefs);
  }

  AppThemeOption get themeOption {
    final raw = _prefs.getString(_themeKey);
    if (raw == null) return AppThemeOption.obsidian;
    return AppThemeOption.values.firstWhere(
      (option) => option.name == raw,
      orElse: () => AppThemeOption.obsidian,
    );
  }

  Future<void> setThemeOption(AppThemeOption option) async {
    await _prefs.setString(_themeKey, option.name);
  }

  bool get gridMode => _prefs.getBool(_gridModeKey) ?? true;

  Future<void> setGridMode(bool value) async {
    await _prefs.setBool(_gridModeKey, value);
  }

  bool get obsidianFilter => _prefs.getBool(_obsidianFilterKey) ?? true;

  Future<void> setObsidianFilter(bool value) async {
    await _prefs.setBool(_obsidianFilterKey, value);
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
}
