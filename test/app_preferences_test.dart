import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/l10n/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persiste idioma de la interfaz', () async {
    final prefs = await AppPreferences.open();
    expect(prefs.appLocale, AppLocale.es);

    await prefs.setAppLocale(AppLocale.zh);

    final reloaded = await AppPreferences.open();
    expect(reloaded.appLocale, AppLocale.zh);
  });

  test('persiste tema, grid y preferencias del lector', () async {
    final prefs = await AppPreferences.open();

    expect(prefs.themeOption, AppThemeOption.ebony);
    expect(prefs.gridMode, isTrue);
    expect(prefs.ebonyFilter, isTrue);
    expect(prefs.scrollModeName, 'verticalContinuous');

    await prefs.setThemeOption(AppThemeOption.light);
    await prefs.setGridMode(false);
    await prefs.setEbonyFilter(false);
    await prefs.setScrollModeName('horizontalPaged');

    final reloaded = await AppPreferences.open();
    expect(reloaded.themeOption, AppThemeOption.light);
    expect(reloaded.gridMode, isFalse);
    expect(reloaded.ebonyFilter, isFalse);
    expect(reloaded.scrollModeName, 'horizontalPaged');
  });

  test('por defecto no se ha visto la bienvenida', () async {
    final prefs = await AppPreferences.open();
    expect(prefs.hasSeenWelcome, isFalse);
  });

  test('markWelcomeSeen persiste entre aperturas', () async {
    final first = await AppPreferences.open();
    await first.markWelcomeSeen();
    expect(first.hasSeenWelcome, isTrue);

    final second = await AppPreferences.open();
    expect(second.hasSeenWelcome, isTrue);
  });

  test('markWelcomeSeen es idempotente', () async {
    final prefs = await AppPreferences.open();
    await prefs.markWelcomeSeen();
    await prefs.markWelcomeSeen();
    expect(prefs.hasSeenWelcome, isTrue);
  });
}
