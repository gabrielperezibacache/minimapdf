import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';

/// Resultado de la edición local de metadatos.
class BookMetadataDraft {
  const BookMetadataDraft({
    required this.title,
    this.author,
    required this.tags,
  });

  final String title;
  final String? author;
  final List<String> tags;
}

/// Formulario para editar Título, Autor y Tags de un PDF.
Future<BookMetadataDraft?> showMetadataEditSheet(
  BuildContext context, {
  required Book book,
}) {
  return showModalBottomSheet<BookMetadataDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) => _MetadataEditForm(book: book),
  );
}

class _MetadataEditForm extends StatefulWidget {
  const _MetadataEditForm({required this.book});

  final Book book;

  @override
  State<_MetadataEditForm> createState() => _MetadataEditFormState();
}

class _MetadataEditFormState extends State<_MetadataEditForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author ?? '');
    _tagsController = TextEditingController(text: widget.book.tags.join(', '));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);

    Navigator.of(context).pop(
      BookMetadataDraft(
        title: title,
        author: _authorController.text.trim(),
        tags: tags,
      ),
    );
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
            child: Container(
              width: 36,
              height: 3,
              color: colors.border,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Editar metadatos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.accent,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Título',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Autor',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagsController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'separados por coma',
            ),
          ),
          const SizedBox(height: 20),
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
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.background,
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
