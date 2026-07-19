import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_theme_option.dart';

/// Construye [ThemeData] para cada opción de la paleta Minimal PDF.
abstract final class AppTheme {
  static ThemeData of(AppThemeOption option) => switch (option) {
        AppThemeOption.light => light,
        AppThemeOption.sepia => sepia,
        AppThemeOption.ebony => ebony,
      };

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        panel: AppColors.lightPanel,
        text: AppColors.lightText,
        textMuted: AppColors.lightTextMuted,
        border: AppColors.lightBorder,
        accent: AppColors.lightAccent,
      );

  static ThemeData get sepia => _build(
        brightness: Brightness.light,
        background: AppColors.sepiaBackground,
        surface: AppColors.sepiaSurface,
        panel: AppColors.sepiaPanel,
        text: AppColors.sepiaText,
        textMuted: AppColors.sepiaTextMuted,
        border: AppColors.sepiaBorder,
        accent: AppColors.sepiaAccent,
      );

  static ThemeData get ebony => _build(
        brightness: Brightness.dark,
        background: AppColors.ebonyBackground,
        surface: AppColors.ebonySurface,
        panel: AppColors.ebonyPanel,
        text: AppColors.ebonyText,
        textMuted: AppColors.ebonyTextMuted,
        border: AppColors.ebonyBorder,
        accent: AppColors.ebonyAccent,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color panel,
    required Color text,
    required Color textMuted,
    required Color border,
    required Color accent,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.dark
          ? AppColors.ebonyBackground
          : Colors.white,
      secondary: accent,
      onSecondary: brightness == Brightness.dark
          ? AppColors.ebonyBackground
          : Colors.white,
      surface: surface,
      onSurface: text,
      error: const Color(0xFFCF6679),
      onError: Colors.white,
      outline: border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      cardColor: panel,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: panel,
        foregroundColor: text,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: brightness == Brightness.dark
            ? AppColors.ebonyBackground
            : Colors.white,
        elevation: 2,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: textMuted),
      textTheme: _textTheme(text, textMuted),
      primaryTextTheme: _textTheme(text, textMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: TextStyle(color: text),
        actionTextColor: accent,
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppPalette(
          background: background,
          panel: panel,
          surface: surface,
          text: text,
          textMuted: textMuted,
          border: border,
          accent: accent,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color text, Color muted) {
    return TextTheme(
      displayLarge: TextStyle(color: text, fontWeight: FontWeight.w600),
      displayMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
      displaySmall: TextStyle(color: text, fontWeight: FontWeight.w600),
      headlineLarge: TextStyle(color: text, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: text, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: text, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: text, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: text, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: text, height: 1.45),
      bodyMedium: TextStyle(color: text, height: 1.45),
      bodySmall: TextStyle(color: muted, height: 1.4),
      labelLarge: TextStyle(color: text, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: muted),
      labelSmall: TextStyle(color: muted),
    );
  }
}

/// Colores semánticos accesibles vía `Theme.of(context).extension`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.panel,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.accent,
  });

  final Color background;
  final Color panel;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color accent;

  static AppPalette of(BuildContext context) {
    final ext = Theme.of(context).extension<AppPalette>();
    assert(ext != null, 'AppPalette no está registrado en el ThemeData');
    return ext!;
  }

  @override
  AppPalette copyWith({
    Color? background,
    Color? panel,
    Color? surface,
    Color? text,
    Color? textMuted,
    Color? border,
    Color? accent,
  }) {
    return AppPalette(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
