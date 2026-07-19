import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_option.dart';
import '../../l10n/app_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../services/external_pdf_open_service.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

/// Configuración: idioma, tema y lector PDF por defecto del sistema.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openDefaultPdfSettings(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened =
        await context.read<ExternalPdfOpenService>().openDefaultAppsSettings();
    if (!context.mounted) return;
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.defaultPdfReaderOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            l10n.settings,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _SectionLabel(label: l10n.defaultPdfReader),
          const SizedBox(height: 4),
          Text(
            l10n.defaultPdfReaderSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Material(
            color: colors.panel,
            child: InkWell(
              onTap: () => _openDefaultPdfSettings(context),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.defaultPdfReaderOpenSettings,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.accent,
                            ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new,
                      size: 18,
                      color: colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.defaultPdfReaderHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
          ),
          const SizedBox(height: 28),
          _SectionLabel(label: l10n.language),
          const SizedBox(height: 4),
          Text(
            l10n.languageSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...AppLocale.values.map(
            (option) => _SettingsOptionTile(
              selected: localeProvider.appLocale == option,
              title: option.nativeLabel,
              onTap: () => localeProvider.setLocale(option),
            ),
          ),
          const SizedBox(height: 28),
          _SectionLabel(label: l10n.appearance),
          const SizedBox(height: 12),
          ...AppThemeOption.values.map(
            (option) => _SettingsOptionTile(
              selected: themeProvider.option == option,
              title: option.localizedLabel(l10n),
              onTap: () => themeProvider.setTheme(option),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.accent,
          ),
    );
  }
}

class _SettingsOptionTile extends StatelessWidget {
  const _SettingsOptionTile({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? colors.surface : colors.panel,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? colors.accent : colors.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: selected ? colors.accent : colors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: selected ? colors.accent : colors.text,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
