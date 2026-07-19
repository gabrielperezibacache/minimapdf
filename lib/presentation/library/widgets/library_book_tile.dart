import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/book.dart';

/// Celda técnica de libro con borde 1px (paleta Hermes).
class LibraryBookTile extends StatelessWidget {
  const LibraryBookTile({
    super.key,
    required this.book,
    required this.compact,
    this.onTap,
    this.onEditMetadata,
    this.onDelete,
  });

  final Book book;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onEditMetadata;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final subtitle = [
      if (book.author != null && book.author!.isNotEmpty) book.author!,
      _formatSize(book.fileSize),
      if (book.lastPageRead > 0) 'p. ${book.lastPageRead}',
    ].join(' · ');

    return Material(
      color: colors.panel,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEditMetadata,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border, width: 1),
          ),
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: compact ? _gridContent(context, colors, subtitle) : _listContent(context, colors, subtitle),
        ),
      ),
    );
  }

  Widget _gridContent(BuildContext context, HermesColors colors, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.picture_as_pdf_outlined, color: colors.accent, size: 28),
        const Spacer(),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (book.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            book.tags.take(3).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.accent,
                ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: _menuButton(colors),
        ),
      ],
    );
  }

  Widget _listContent(BuildContext context, HermesColors colors, String subtitle) {
    return Row(
      children: [
        Icon(Icons.picture_as_pdf_outlined, color: colors.accent, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _menuButton(colors),
      ],
    );
  }

  Widget _menuButton(HermesColors colors) {
    return PopupMenuButton<_BookAction>(
      tooltip: 'Opciones',
      icon: Icon(Icons.more_vert, color: colors.textMuted, size: 20),
      onSelected: (action) {
        switch (action) {
          case _BookAction.edit:
            onEditMetadata?.call();
          case _BookAction.delete:
            onDelete?.call();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _BookAction.edit,
          child: Text('Editar metadatos'),
        ),
        PopupMenuItem(
          value: _BookAction.delete,
          child: Text('Eliminar'),
        ),
      ],
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

enum _BookAction { edit, delete }
