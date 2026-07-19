import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'presentation/library/library_screen.dart';
import 'presentation/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MinimalPdfApp());
}

class MinimalPdfApp extends StatelessWidget {
  const MinimalPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const _MinimalPdfRoot(),
    );
  }
}

class _MinimalPdfRoot extends StatelessWidget {
  const _MinimalPdfRoot();

  @override
  Widget build(BuildContext context) {
    final themeOption = context.watch<ThemeProvider>().option;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(themeOption),
      home: const LibraryScreen(),
    );
  }
}
