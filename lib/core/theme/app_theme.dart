import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_theme_option.dart';

/// Construye [ThemeData] para cada opción de la paleta Hermes Obsidian.
///
/// Misma apariencia en Android e iOS: Material 3 + tokens Hermes
/// (colores, radios, tipografía y componentes).
abstract final class AppTheme {
  static ThemeData of(AppThemeOption option) => switch (option) {
        AppThemeOption.light => light,
        AppThemeOption.sepia => sepia,
        AppThemeOption.obsidian => obsidian,
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
        onAccent: Colors.white,
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
        onAccent: Colors.white,
      );

  static ThemeData get obsidian => _build(
        brightness: Brightness.dark,
        background: AppColors.obsidianBackground,
        surface: AppColors.obsidianSurface,
        panel: AppColors.obsidianPanel,
        text: AppColors.obsidianText,
        textMuted: AppColors.obsidianTextMuted,
        border: AppColors.obsidianBorder,
        accent: AppColors.obsidianAccent,
        onAccent: AppColors.obsidianBackground,
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
    required Color onAccent,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      surface: surface,
      onSurface: text,
      error: const Color(0xFFCF6679),
      onError: Colors.white,
      outline: border,
    );

    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: background,
      systemNavigationBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      cardColor: panel,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: panel,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textMuted),
        actionsIconTheme: IconThemeData(color: textMuted),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.smAll,
          side: BorderSide(color: border, width: 1),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: panel,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.smAll,
          side: BorderSide(color: border, width: 1),
        ),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: text, height: 1.45),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textMuted,
        indicatorColor: accent,
        dividerColor: border,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: accent,
        textColor: text,
        selectedColor: accent,
        selectedTileColor: surface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.smAll,
          side: BorderSide(color: border),
        ),
        textStyle: TextStyle(color: text),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: textMuted),
      textTheme: _textTheme(text, textMuted),
      primaryTextTheme: _textTheme(text, textMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.smAll,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: TextStyle(color: text),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.smAll,
          side: BorderSide(color: border),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        HermesColors(
          background: background,
          panel: panel,
          surface: surface,
          text: text,
          textMuted: textMuted,
          border: border,
          accent: accent,
          onAccent: onAccent,
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

  /// Estilo de barra de estado/navegación alineado con el tema activo.
  static SystemUiOverlayStyle systemUiFor(AppThemeOption option) {
    final theme = of(option);
    return theme.appBarTheme.systemOverlayStyle ?? SystemUiOverlayStyle.dark;
  }
}

/// Colores semánticos Hermes accesibles vía `Theme.of(context).extension`.
@immutable
class HermesColors extends ThemeExtension<HermesColors> {
  const HermesColors({
    required this.background,
    required this.panel,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.onAccent,
  });

  final Color background;
  final Color panel;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color onAccent;

  static HermesColors of(BuildContext context) {
    final ext = Theme.of(context).extension<HermesColors>();
    assert(ext != null, 'HermesColors no está registrado en el ThemeData');
    return ext!;
  }

  @override
  HermesColors copyWith({
    Color? background,
    Color? panel,
    Color? surface,
    Color? text,
    Color? textMuted,
    Color? border,
    Color? accent,
    Color? onAccent,
  }) {
    return HermesColors(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  HermesColors lerp(ThemeExtension<HermesColors>? other, double t) {
    if (other is! HermesColors) return this;
    return HermesColors(
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}
