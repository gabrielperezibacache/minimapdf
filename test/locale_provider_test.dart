import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/l10n/app_locale.dart';
import 'package:minimal_pdf/l10n/app_localizations.dart';
import 'package:minimal_pdf/presentation/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocaleProvider', () {
    test('por defecto es español', () {
      final provider = LocaleProvider();
      expect(provider.appLocale, AppLocale.es);
      expect(provider.locale.languageCode, 'es');
    });

    test('setLocale persiste y notifica el cambio', () async {
      final prefs = await AppPreferences.open();
      final provider = LocaleProvider(preferences: prefs);
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.setLocale(AppLocale.en);

      expect(provider.appLocale, AppLocale.en);
      expect(notified, 1);

      final reloaded = await AppPreferences.open();
      expect(reloaded.appLocale, AppLocale.en);
    });

    test('constructor con preferencias restaura el idioma guardado', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
      final prefs = await AppPreferences.open();
      final provider = LocaleProvider(preferences: prefs);
      expect(provider.appLocale, AppLocale.fr);
      expect(provider.locale.languageCode, 'fr');
    });

    test('attachPreferences sincroniza el idioma almacenado', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'de'});
      final prefs = await AppPreferences.open();
      final provider = LocaleProvider();
      expect(provider.appLocale, AppLocale.es);

      provider.attachPreferences(prefs);
      expect(provider.appLocale, AppLocale.de);
    });
  });

  group('AppLocalizations', () {
    test('traduce biblioteca en inglés y español', () {
      final es = AppLocalizations(const Locale('es'));
      final en = AppLocalizations(const Locale('en'));

      expect(es.library, 'Biblioteca');
      expect(en.library, 'Library');
      expect(es.settings, 'Configuración');
      expect(en.settings, 'Settings');
    });

    test('interpola título al importar', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.imported('Demo'), 'Imported: Demo');
    });

    test('incluye alemán, chino y ruso', () {
      final de = AppLocalizations(const Locale('de'));
      final zh = AppLocalizations(const Locale('zh'));
      final ru = AppLocalizations(const Locale('ru'));

      expect(de.library, 'Bibliothek');
      expect(zh.library, '书库');
      expect(ru.library, 'Библиотека');
      expect(AppLocale.de.nativeLabel, 'Deutsch');
      expect(AppLocale.zh.nativeLabel, '中文');
      expect(AppLocale.ru.nativeLabel, 'Русский');
      expect(AppLocalizations.supportedLocales.map((l) => l.languageCode),
          containsAll(['de', 'zh', 'ru']));
    });
  });
}
