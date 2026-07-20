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
  bool _disposed = false;

  AppThemeOption get option => _option;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Enlaza preferencias ya cargadas (p. ej. tras `AppPreferences.open()`).
  void attachPreferences(AppPreferences preferences) {
    _preferences = preferences;
    final stored = preferences.themeOption;
    if (_option != stored) {
      _option = stored;
      _safeNotify();
    }
  }

  Future<void> setTheme(AppThemeOption option) async {
    if (_option == option || _disposed) return;
    _option = option;
    _safeNotify();
    final prefs = _preferences;
    if (prefs == null) return;
    // Reescribe hasta estabilizar: evita que un await lento pise un valor más nuevo.
    while (!_disposed) {
      final snapshot = _option;
      await prefs.setThemeOption(snapshot);
      if (_disposed || _option == snapshot) return;
    }
  }

  Future<void> cycleTheme() async {
    final values = AppThemeOption.values;
    final next = (values.indexOf(_option) + 1) % values.length;
    await setTheme(values[next]);
  }
}
