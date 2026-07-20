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

  AppLocale get appLocale => _appLocale;
  Locale get locale => _appLocale.locale;

  void attachPreferences(AppPreferences preferences) {
    _preferences = preferences;
    final stored = preferences.storedAppLocale;
    if (stored != null && _appLocale != stored) {
      _appLocale = stored;
      notifyListeners();
    }
  }

  Future<void> setLocale(AppLocale value) async {
    if (_appLocale == value) return;
    _appLocale = value;
    notifyListeners();
    await _preferences?.setAppLocale(value);
  }
}
