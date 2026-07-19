import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Formulario sencillo para nota de texto en la página actual.
Future<String?> showNoteEditSheet(
  BuildContext context, {
  required int pageNumber,
  String? initialText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) => _NoteEditForm(
      pageNumber: pageNumber,
      initialText: initialText,
    ),
  );
}

class _NoteEditForm extends StatefulWidget {
  const _NoteEditForm({
    required this.pageNumber,
    this.initialText,
  });

  final int pageNumber;
  final String? initialText;

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
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 36, height: 3, color: colors.border),
          ),
          const SizedBox(height: 16),
          Text(
            'Nota · página ${widget.pageNumber}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ebonyAccent,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe una nota…',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.text,
                    side: BorderSide(color: colors.border),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ebonyAccent,
                    foregroundColor: AppColors.ebonyBackground,
                  ),
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
