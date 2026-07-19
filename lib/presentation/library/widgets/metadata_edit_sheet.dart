import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';
import '../../../data/models/collection.dart';

/// Resultado de la edición local de metadatos.
class BookMetadataDraft {
  const BookMetadataDraft({
    required this.title,
    this.author,
    required this.tags,
    this.collectionId,
    this.clearCollectionId = false,
  });

  final String title;
  final String? author;
  final List<String> tags;
  final int? collectionId;
  final bool clearCollectionId;
}

/// Formulario para editar Título, Autor, Tags y colección de un PDF.
Future<BookMetadataDraft?> showMetadataEditSheet(
  BuildContext context, {
  required Book book,
  List<Collection> collections = const [],
}) {
  return showModalBottomSheet<BookMetadataDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).panel,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    builder: (context) => _MetadataEditForm(
      book: book,
      collections: collections,
    ),
  );
}

class _MetadataEditForm extends StatefulWidget {
  const _MetadataEditForm({
    required this.book,
    required this.collections,
  });

  final Book book;
  final List<Collection> collections;

  @override
  State<_MetadataEditForm> createState() => _MetadataEditFormState();
}

class _MetadataEditFormState extends State<_MetadataEditForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _tagsController;
  int? _collectionId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author ?? '');
    _tagsController = TextEditingController(text: widget.book.tags.join(', '));
    _collectionId = widget.book.collectionId;
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
        collectionId: _collectionId,
        clearCollectionId: _collectionId == null,
      ),
    );
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
            child: Container(
              width: 36,
              height: 3,
              color: colors.border,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Editar metadatos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.accent,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Título',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _authorController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Autor',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _tagsController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'separados por coma',
            ),
          ),
          if (widget.collections.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Colección',
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _collectionId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sin colección'),
                    ),
                    ...widget.collections.map(
                      (collection) => DropdownMenuItem<int?>(
                        value: collection.id,
                        child: Text(collection.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _collectionId = value),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
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
                  onPressed: _submit,
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
