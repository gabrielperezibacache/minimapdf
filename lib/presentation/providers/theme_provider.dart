import 'package:flutter/foundation.dart';

import '../../core/theme/app_theme_option.dart';

/// Gestiona el tema activo (Claro / Sepia / Ébano).
class ThemeProvider extends ChangeNotifier {
  AppThemeOption _option = AppThemeOption.ebony;

  AppThemeOption get option => _option;

  void setTheme(AppThemeOption option) {
    if (_option == option) return;
    _option = option;
    notifyListeners();
  }

  void cycleTheme() {
    final values = AppThemeOption.values;
    final next = (values.indexOf(_option) + 1) % values.length;
    setTheme(values[next]);
  }
}
