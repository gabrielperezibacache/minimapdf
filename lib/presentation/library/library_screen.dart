import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_option.dart';
import '../../data/models/book.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import 'widgets/library_book_tile.dart';
import 'widgets/metadata_edit_sheet.dart';

/// Biblioteca: recientes, colecciones, importación y metadatos locales.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LibraryProvider>().load();
    });
  }

  Future<void> _importPdf() async {
    final provider = context.read<LibraryProvider>();
    final book = await provider.importPdf();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (book != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Importado: ${book.title}')),
      );
    } else if (provider.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  Future<void> _editMetadata(Book book) async {
    final draft = await showMetadataEditSheet(context, book: book);
    if (draft == null || !mounted) return;

    await context.read<LibraryProvider>().updateBookMetadata(
          book: book,
          title: draft.title,
          author: draft.author,
          tags: draft.tags,
        );
  }

  Future<void> _confirmDelete(Book book) async {
    final colors = HermesColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: const Text('Eliminar PDF'),
        content: Text('¿Eliminar “${book.title}” de la biblioteca?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<LibraryProvider>().deleteBook(book);
    }
  }

  Future<void> _createCollection() async {
    final colors = HermesColors.of(context);
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: const Text('Nueva colección'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Crear', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || !mounted) return;

    await context.read<LibraryProvider>().createCollection(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: library.gridMode ? 'Vista lista' : 'Vista cuadrícula',
            onPressed: () => library.setGridMode(!library.gridMode),
            icon: Icon(
              library.gridMode
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              color: colors.accent,
            ),
          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: library.importing ? null : _importPdf,
        tooltip: 'Importar PDF',
        child: library.importing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: colors.accent,
        onRefresh: library.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biblioteca',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colors.accent,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDFs recientes y colecciones · 100% offline',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CollectionsRow(
                library: library,
                onCreate: _createCollection,
              ),
            ),
            if (library.loading && library.books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (library.visibleBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyLibrary(
                  onImport: _importPdf,
                  filtered: library.selectedCollectionId != null,
                ),
              )
            else if (library.gridMode)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = library.visibleBooks[index];
                      return LibraryBookTile(
                        book: book,
                        compact: true,
                        onEditMetadata: () => _editMetadata(book),
                        onDelete: () => _confirmDelete(book),
                      );
                    },
                    childCount: library.visibleBooks.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                sliver: SliverList.separated(
                  itemCount: library.visibleBooks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final book = library.visibleBooks[index];
                    return LibraryBookTile(
                      book: book,
                      compact: false,
                      onEditMetadata: () => _editMetadata(book),
                      onDelete: () => _confirmDelete(book),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CollectionsRow extends StatelessWidget {
  const _CollectionsRow({
    required this.library,
    required this.onCreate,
  });

  final LibraryProvider library;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CollectionChip(
            label: 'Todos',
            selected: library.selectedCollectionId == null,
            onTap: () => library.selectCollection(null),
          ),
          const SizedBox(width: 8),
          ...library.collections.map(
            (collection) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CollectionChip(
                label: collection.name,
                selected: library.selectedCollectionId == collection.id,
                onTap: () => library.selectCollection(collection.id),
              ),
            ),
          ),
          InkWell(
            onTap: onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.create_new_folder_outlined,
                      size: 18, color: colors.accent),
                  const SizedBox(width: 6),
                  Text(
                    'Nueva',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.accent,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surface : colors.panel,
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? colors.accent : colors.text,
              ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.onImport,
    required this.filtered,
  });

  final VoidCallback onImport;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 42, color: colors.accent),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'No hay PDFs en esta colección'
                  : 'Tu biblioteca está vacía',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Importa un PDF o elige otra carpeta.'
                  : 'Pulsa + para importar un PDF del dispositivo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!filtered) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onImport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.border),
                ),
                child: const Text('Importar PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
