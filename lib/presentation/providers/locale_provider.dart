import 'package:flutter/material.dart';

import '../../core/preferences/app_preferences.dart';
import '../../l10n/app_locale.dart';

/// Gestiona el idioma de la interfaz y lo persiste en [AppPreferences].
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({AppPreferences? preferences})
      : _preferences = preferences,
        _appLocale = preferences?.appLocale ?? AppLocale.es;

  AppPreferences? _preferences;
  AppLocale _appLocale;

  AppLocale get appLocale => _appLocale;
  Locale get locale => _appLocale.locale;

  void attachPreferences(AppPreferences preferences) {
    _preferences = preferences;
    final stored = preferences.appLocale;
    if (_appLocale != stored) {
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
