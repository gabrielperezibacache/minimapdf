import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_colors.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/presentation/providers/theme_provider.dart';

void main() {
  group('AppTheme', () {
    test('Claro usa fondo #F4EEE7 y texto #121D18', () {
      final theme = AppTheme.light;
      final colors = theme.extension<AppPalette>()!;

      expect(colors.background, AppColors.lightBackground);
      expect(colors.text, AppColors.lightText);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF4EEE7));
    });

    test('Sepia define paleta cálida distinta del claro', () {
      final theme = AppTheme.sepia;
      final colors = theme.extension<AppPalette>()!;

      expect(colors.background, AppColors.sepiaBackground);
      expect(colors.accent, AppColors.sepiaAccent);
      expect(colors.background, isNot(AppColors.lightBackground));
    });

    test('Ébano usa fondo #0F1714, paneles y acento bronce', () {
      final theme = AppTheme.ebony;
      final colors = theme.extension<AppPalette>()!;

      expect(colors.background, const Color(0xFF0F1714));
      expect(colors.panel, const Color(0xFF121D18));
      expect(colors.surface, const Color(0xFF16211C));
      expect(colors.text, const Color(0xFFF3ECDD));
      expect(colors.accent, const Color(0xFFC89A5A));
      expect(colors.border, const Color(0xFF22342C));
    });
  });

  group('ThemeProvider', () {
    test('ciclo Claro → Sepia → Ébano → Claro', () {
      final provider = ThemeProvider();
      expect(provider.option, AppThemeOption.ebony);

      provider.setTheme(AppThemeOption.light);
      expect(provider.option, AppThemeOption.light);

      provider.cycleTheme();
      expect(provider.option, AppThemeOption.sepia);

      provider.cycleTheme();
      expect(provider.option, AppThemeOption.ebony);

      provider.cycleTheme();
      expect(provider.option, AppThemeOption.light);
    });
  });
}
