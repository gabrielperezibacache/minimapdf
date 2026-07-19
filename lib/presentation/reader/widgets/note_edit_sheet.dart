import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Formulario sencillo para nota / comentario / anotación de texto.
Future<String?> showNoteEditSheet(
  BuildContext context, {
  required int pageNumber,
  String? initialText,
  String title = 'Nota',
  String hintText = 'Escribe una nota…',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).panel,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    builder: (context) => _NoteEditForm(
      pageNumber: pageNumber,
      initialText: initialText,
      title: title,
      hintText: hintText,
    ),
  );
}

class _NoteEditForm extends StatefulWidget {
  const _NoteEditForm({
    required this.pageNumber,
    this.initialText,
    this.title = 'Nota',
    this.hintText = 'Escribe una nota…',
  });

  final int pageNumber;
  final String? initialText;
  final String title;
  final String hintText;

  @override
  State<_NoteEditForm> createState() => _NoteEditFormState();
}

class _NoteEditFormState extends State<_NoteEditForm> {
  late final TextEditingController _controller;

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

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
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
            '${widget.title} · página ${widget.pageNumber}',
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.text),
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
