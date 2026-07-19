import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_locale.dart';

/// Gestiona el idioma de la interfaz y lo persiste localmente.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({AppLocale initial = AppLocale.es}) : _appLocale = initial;

  static const _prefsKey = 'app_locale';

  AppLocale _appLocale;
  bool _loaded = false;

  AppLocale get appLocale => _appLocale;
  Locale get locale => _appLocale.locale;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    _appLocale = AppLocaleX.fromCode(stored);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(AppLocale value) async {
    if (_appLocale == value) return;
    _appLocale = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.code);
  }
}
