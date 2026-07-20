import 'package:flutter/foundation.dart';

import '../../core/preferences/app_preferences.dart';
import '../../core/theme/app_theme_option.dart';

/// Gestiona el tema activo (Claro / Sepia / Ébano) con persistencia.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({AppPreferences? preferences})
      : _preferences = preferences,
        _option = preferences?.themeOption ?? AppThemeOption.ebony;

  AppPreferences? _preferences;
  AppThemeOption _option;

  AppThemeOption get option => _option;

  /// Enlaza preferencias ya cargadas (p. ej. tras `AppPreferences.open()`).
  void attachPreferences(AppPreferences preferences) {
    _preferences = preferences;
    final stored = preferences.themeOption;
    if (_option != stored) {
      _option = stored;
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemeOption option) async {
    if (_option == option) return;
    _option = option;
    notifyListeners();
    final prefs = _preferences;
    if (prefs == null) return;
    // Reescribe hasta estabilizar: evita que un await lento pise un valor más nuevo.
    while (true) {
      final snapshot = _option;
      await prefs.setThemeOption(snapshot);
      if (_option == snapshot) return;
    }
  }

  Future<void> cycleTheme() async {
    final values = AppThemeOption.values;
    final next = (values.indexOf(_option) + 1) % values.length;
    await setTheme(values[next]);
  }
}
