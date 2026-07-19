import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_colors.dart';
import 'package:minimal_pdf/core/theme/app_radii.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/core/theme/app_theme_option.dart';
import 'package:minimal_pdf/presentation/providers/theme_provider.dart';

void main() {
  group('AppTheme', () {
    test('Claro usa fondo #F4EEE7 y texto #121D18', () {
      final theme = AppTheme.light;
      final colors = theme.extension<HermesColors>()!;

      expect(colors.background, AppColors.lightBackground);
      expect(colors.text, AppColors.lightText);
      expect(colors.onAccent, Colors.white);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF4EEE7));
    });

    test('Sepia define paleta cálida distinta del claro', () {
      final theme = AppTheme.sepia;
      final colors = theme.extension<HermesColors>()!;

      expect(colors.background, AppColors.sepiaBackground);
      expect(colors.accent, AppColors.sepiaAccent);
      expect(colors.background, isNot(AppColors.lightBackground));
    });

    test('Obsidian usa fondo #0F1714, paneles y acento bronce', () {
      final theme = AppTheme.obsidian;
      final colors = theme.extension<HermesColors>()!;

      expect(colors.background, const Color(0xFF0F1714));
      expect(colors.panel, const Color(0xFF121D18));
      expect(colors.surface, const Color(0xFF16211C));
      expect(colors.text, const Color(0xFFF3ECDD));
      expect(colors.accent, const Color(0xFFC89A5A));
      expect(colors.border, const Color(0xFF22342C));
      expect(colors.onAccent, AppColors.obsidianBackground);
    });

    test('componentes Hermes usan radio sm y acento del tema', () {
      final theme = AppTheme.obsidian;
      final colors = theme.extension<HermesColors>()!;

      expect(theme.floatingActionButtonTheme.backgroundColor, colors.accent);
      expect(theme.floatingActionButtonTheme.foregroundColor, colors.onAccent);
      expect(
        theme.progressIndicatorTheme.color,
        colors.accent,
      );
      expect(theme.tabBarTheme.labelColor, colors.accent);
      expect(theme.bottomSheetTheme.backgroundColor, colors.panel);

      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(cardShape.borderRadius, AppRadii.smAll);
    });

    test('systemUiFor alinea status bar con cada tema', () {
      final dark = AppTheme.systemUiFor(AppThemeOption.obsidian);
      final light = AppTheme.systemUiFor(AppThemeOption.light);

      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarColor, AppColors.obsidianBackground);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(light.systemNavigationBarColor, AppColors.lightBackground);
    });

    testWidgets('HermesColors.of resuelve tokens en MaterialApp',
        (tester) async {
      late HermesColors resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.sepia,
          home: Builder(
            builder: (context) {
              resolved = HermesColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.accent, AppColors.sepiaAccent);
      expect(resolved.onAccent, Colors.white);
    });
  });

  group('AppRadii', () {
    test('define radio técnico sm = 4', () {
      expect(AppRadii.sm, 4);
      expect(AppRadii.sheetTop.topLeft.x, 4);
    });
  });

  group('ThemeProvider', () {
    test('ciclo Claro → Sepia → Obsidian → Claro', () {
      final provider = ThemeProvider();
      expect(provider.option, AppThemeOption.obsidian);

      provider.setTheme(AppThemeOption.light);
      expect(provider.option, AppThemeOption.light);

      provider.cycleTheme();
      expect(provider.option, AppThemeOption.sepia);

      provider.cycleTheme();
      expect(provider.option, AppThemeOption.obsidian);

      provider.cycleTheme();
      expect(provider.option, AppThemeOption.light);
    });
  });
}
