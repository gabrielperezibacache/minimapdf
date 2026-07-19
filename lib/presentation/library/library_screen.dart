import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/book.dart';
import '../../l10n/app_localizations.dart';
import '../downloader/downloader_screen.dart';
import '../providers/library_provider.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
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
    final l10n = AppLocalizations.of(context);
    final book = await provider.importPdf();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (book != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.imported(book.title))),
      );
    } else if (provider.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.message(provider.error!))),
      );
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: Text(l10n.deletePdf),
        content: Text(l10n.deletePdfConfirm(book.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<LibraryProvider>().deleteBook(book);
    }
  }

  Future<void> _openReader(Book book) async {
    await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ReaderScreen(book: book),
      ),
    );
    if (!mounted) return;
    await context.read<LibraryProvider>().load();
  }

  Future<void> _createCollection() async {
    final colors = HermesColors.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: Text(l10n.newCollection),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.collectionName),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.create, style: TextStyle(color: colors.accent)),
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
    final l10n = AppLocalizations.of(context);
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: l10n.downloadsBrowser,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloaderScreen(),
                ),
              );
              if (!context.mounted) return;
              await context.read<LibraryProvider>().load();
            },
            icon: Icon(Icons.download_outlined, color: colors.accent),
          ),
          IconButton(
            tooltip: library.gridMode ? l10n.viewList : l10n.viewGrid,
            onPressed: () => library.setGridMode(!library.gridMode),
            icon: Icon(
              library.gridMode
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
              color: colors.accent,
            ),
          ),
          IconButton(
            tooltip: l10n.settings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            icon: Icon(Icons.settings_outlined, color: colors.accent),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: library.importing ? null : _importPdf,
        tooltip: l10n.importPdf,
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
                      l10n.library,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colors.accent,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.librarySubtitle,
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
                        onTap: () => _openReader(book),
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
                      onTap: () => _openReader(book),
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
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CollectionChip(
            label: l10n.allCollections,
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
                    l10n.newCollectionShort,
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
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 42, color: colors.accent),
            const SizedBox(height: 16),
            Text(
              filtered ? l10n.emptyCollection : l10n.emptyLibrary,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              filtered ? l10n.emptyCollectionHint : l10n.emptyLibraryHint,
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
                child: Text(l10n.importPdf),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
