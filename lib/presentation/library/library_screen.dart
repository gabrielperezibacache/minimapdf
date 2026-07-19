import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_option.dart';
import '../providers/theme_provider.dart';

/// Pantalla base de la biblioteca (UI completa en Paso 3).
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          PopupMenuButton<AppThemeOption>(
            tooltip: 'Tema',
            icon: Icon(Icons.palette_outlined, color: colors.accent),
            onSelected: themeProvider.setTheme,
            itemBuilder: (context) => AppThemeOption.values
                .map(
                  (option) => CheckedPopupMenuItem<AppThemeOption>(
                    value: option,
                    checked: option == themeProvider.option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: colors.accent,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppConstants.appTagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.panel,
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema activo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      themeProvider.option.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.accent,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'La biblioteca, el lector y las descargas se '
                      'implementan en los pasos siguientes.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
