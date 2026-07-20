import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:minimal_pdf/l10n/app_localizations.dart';

/// MaterialApp con [AppLocalizations] (español por defecto) para widget tests.
Widget l10nTestApp({
  required Widget home,
  ThemeData? theme,
  Locale locale = const Locale('es'),
}) {
  return MaterialApp(
    theme: theme,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}
