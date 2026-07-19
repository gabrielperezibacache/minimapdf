import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persiste tema, grid y preferencias del lector', () async {
    final prefs = await AppPreferences.open();

    expect(prefs.themeOption, AppThemeOption.obsidian);
    expect(prefs.gridMode, isTrue);
    expect(prefs.obsidianFilter, isTrue);
    expect(prefs.scrollModeName, 'verticalContinuous');

    await prefs.setThemeOption(AppThemeOption.light);
    await prefs.setGridMode(false);
    await prefs.setObsidianFilter(false);
    await prefs.setScrollModeName('horizontalPaged');

    final reloaded = await AppPreferences.open();
    expect(reloaded.themeOption, AppThemeOption.light);
    expect(reloaded.gridMode, isFalse);
    expect(reloaded.obsidianFilter, isFalse);
    expect(reloaded.scrollModeName, 'horizontalPaged');
  });
}
