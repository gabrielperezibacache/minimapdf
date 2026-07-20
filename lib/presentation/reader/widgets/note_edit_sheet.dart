import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Formulario sencillo para nota / comentario / anotación de texto.
Future<String?> showNoteEditSheet(
  BuildContext context, {
  required int pageNumber,
  String? initialText,
  String? title,
  String? hintText,
}) {
  final l10n = AppLocalizations.of(context);
  final resolvedTitle = title ?? l10n.notePage(pageNumber).split(' · ').first;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).panel,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    builder: (context) => _NoteEditForm(
      pageNumber: pageNumber,
      initialText: initialText,
      heading: '$resolvedTitle · ${l10n.pageNumber(pageNumber)}',
      hintText: hintText ?? l10n.noteHint,
    ),
  );
}

class _NoteEditForm extends StatefulWidget {
  const _NoteEditForm({
    required this.pageNumber,
    required this.heading,
    required this.hintText,
    this.initialText,
  });

  final int pageNumber;
  final String? initialText;
  final String heading;
  final String hintText;

  @override
  State<_NoteEditForm> createState() => _NoteEditFormState();
}

class _NoteEditFormState extends State<_NoteEditForm> {
  late final TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    _submitting = true;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 36, height: 3, color: colors.border),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.heading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.accent,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: widget.hintText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
