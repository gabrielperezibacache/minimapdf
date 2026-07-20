import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../../core/preferences/app_preferences.dart';
import '../../l10n/app_locale.dart';

/// Gestiona el idioma de la interfaz y lo persiste en [AppPreferences].
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({
    AppPreferences? preferences,
    AppLocale? fallback,
  })  : _preferences = preferences,
        _appLocale = preferences?.storedAppLocale ??
            fallback ??
            AppLocaleX.fromLocale(PlatformDispatcher.instance.locale);

  AppPreferences? _preferences;
  AppLocale _appLocale;
  bool _disposed = false;

  AppLocale get appLocale => _appLocale;
  Locale get locale => _appLocale.locale;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void attachPreferences(AppPreferences preferences) {
    _preferences = preferences;
    final stored = preferences.storedAppLocale;
    if (stored != null && _appLocale != stored) {
      _appLocale = stored;
      _safeNotify();
    }
  }

  Future<void> setLocale(AppLocale value) async {
    if (_appLocale == value || _disposed) return;
    _appLocale = value;
    _safeNotify();
    final prefs = _preferences;
    if (prefs == null) return;
    // Reescribe hasta estabilizar: evita last-write-wins con valores obsoletos.
    while (!_disposed) {
      final snapshot = _appLocale;
      await prefs.setAppLocale(snapshot);
      if (_disposed || _appLocale == snapshot) return;
    }
  }
}
