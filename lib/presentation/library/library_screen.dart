import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_option.dart';
import '../../data/models/book.dart';
import '../../data/models/collection.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_message_keys.dart';
import '../../services/external_pdf_open_service.dart';
import '../downloader/downloader_screen.dart';
import '../providers/downloader_provider.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../reader/reader_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/sheet_safe_body.dart';
import 'widgets/library_book_tile.dart';
import 'widgets/metadata_edit_sheet.dart';

/// Biblioteca: recientes, colecciones, importación y metadatos locales.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  DownloaderProvider? _downloader;
  LibraryProvider? _library;
  ExternalPdfOpenService? _externalOpen;
  int? _lastSeenDownloadId;
  bool _handlingExternal = false;
  bool _openingReader = false;
  /// PDF externo importado mientras el lector ya está abierto / abriéndose.
  Book? _pendingExternalReader;
  /// Reintentos de import externa por path (fallos transitorios).
  final Map<String, int> _externalRetryCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _library = context.read<LibraryProvider>();
      _library!.addListener(_onLibraryChanged);
      unawaited(_library!.load());
      _downloader = context.read<DownloaderProvider>();
      _downloader!.addListener(_onDownloaderChanged);
      _externalOpen = context.read<ExternalPdfOpenService>();
      _externalOpen!.addListener(_onExternalOpenChanged);
      unawaited(_externalOpen!.start());
      unawaited(_drainExternalQueue());
    });
  }

  @override
  void dispose() {
    _externalOpen?.removeListener(_onExternalOpenChanged);
    _library?.removeListener(_onLibraryChanged);
    _downloader?.removeListener(_onDownloaderChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onExternalOpenChanged() {
    unawaited(_drainExternalQueue());
  }

  void _onLibraryChanged() {
    // Retoma PDFs externos en cola cuando termina una importación manual.
    if (_handlingExternal) return;
    final library = _library;
    final service = _externalOpen;
    if (library == null || service == null) return;
    if (!library.importing && service.hasQueued) {
      unawaited(_drainExternalQueue());
    }
  }

  Future<void> _drainExternalQueue() async {
    if (!mounted || _handlingExternal) return;

    final service = _externalOpen ?? context.read<ExternalPdfOpenService>();
    final library = _library ?? context.read<LibraryProvider>();
    if (library.importing) return;

    _handlingExternal = true;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Book? lastImported;

    try {
      // Importa toda la cola; abre solo el último para evitar carreras de navegación.
      while (mounted) {
        if (library.importing) break;
        final path = service.takeNext();
        if (path == null) break;

        final book = await library.importExternalFile(path);
        if (!mounted) return;
        if (book != null) {
          _externalRetryCounts.remove(path);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.imported(book.title))),
          );
          lastImported = book;
        } else if (library.importing) {
          service.requeue(path);
          break;
        } else {
          // Solo borra cache si el PDF es inválido de forma permanente.
          // Fallos transitorios: reencola al final (máx. 2 reintentos).
          if (_isPermanentExternalImportFailure(library.error)) {
            _externalRetryCounts.remove(path);
            _deleteExternalCacheQuietly(path);
          } else {
            final attempts = (_externalRetryCounts[path] ?? 0) + 1;
            _externalRetryCounts[path] = attempts;
            if (attempts <= 2) {
              service.queueLast(path);
            } else {
              // Agota reintentos: limpia caché externa para no dejar huérfanos.
              _externalRetryCounts.remove(path);
              _deleteExternalCacheQuietly(path);
            }
          }
          if (library.error != null) {
            messenger.showSnackBar(
              SnackBar(content: Text(_msg(library.error!))),
            );
          }
        }
      }
    } finally {
      _handlingExternal = false;
    }

    final toOpen = lastImported;
    if (toOpen != null && mounted) {
      await _openReader(toOpen);
    }
    if (mounted && service.hasQueued) {
      unawaited(_drainExternalQueue());
    }
  }

  bool _isPermanentExternalImportFailure(String? error) {
    return AppMessageKeys.isPermanentImportFailure(error);
  }

  void _deleteExternalCacheQuietly(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    if (!name.startsWith('external_')) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // Best-effort.
    }
  }

  void _onDownloaderChanged() {
    final downloader = _downloader;
    if (!mounted || downloader == null) return;
    final book = downloader.lastDownloaded;
    final id = book?.id;
    if (id == null || id == _lastSeenDownloadId) return;
    _lastSeenDownloadId = id;
    final library = _library ?? context.read<LibraryProvider>();
    unawaited(library.load());
  }

  String _msg(String key, {String? arg}) =>
      AppLocalizations.of(context).message(key, arg: arg);

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
        SnackBar(content: Text(_msg(provider.error!))),
      );
    }
  }

  Future<void> _editMetadata(Book book) async {
    final library = context.read<LibraryProvider>();
    final draft = await showMetadataEditSheet(
      context,
      book: book,
      collections: library.collections,
    );
    if (draft == null || !mounted) return;

    await library.updateBookMetadata(
      book: book,
      title: draft.title,
      author: draft.author,
      tags: draft.tags,
      collectionId: draft.collectionId,
      clearCollectionId: draft.clearCollectionId,
    );
    if (!mounted) return;
    if (library.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(library.error!))),
      );
    }
  }

  Future<void> _confirmDelete(Book book) async {
    final colors = AppPalette.of(context);
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
      final library = context.read<LibraryProvider>();
      await library.deleteBook(book);
      if (!mounted) return;
      if (library.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_msg(library.error!))),
        );
      }
    }
  }

  Future<void> _openReader(Book book) async {
    if (_openingReader) {
      // Conserva el más reciente (p. ej. cola externa) para abrirlo al volver.
      _pendingExternalReader = book;
      return;
    }
    _openingReader = true;
    try {
      await _openReaderBody(book);
    } finally {
      _openingReader = false;
      final pending = _pendingExternalReader;
      _pendingExternalReader = null;
      if (pending != null && mounted) {
        unawaited(_openReader(pending));
      }
    }
  }

  Future<void> _openReaderBody(Book book) async {
    final library = context.read<LibraryProvider>();
    final exists = await library.bookFileExists(book);
    if (!mounted) return;

    if (!exists) {
      final colors = AppPalette.of(context);
      final l10n = AppLocalizations.of(context);
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: colors.panel,
          title: Text(l10n.fileNotFound),
          content: Text(l10n.fileNotFoundBody(book.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l10n.removeFromLibrary,
                style: TextStyle(color: colors.accent),
              ),
            ),
          ],
        ),
      );
      if (remove == true && mounted) {
        await library.deleteBook(book);
        if (!mounted) return;
        if (library.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_msg(library.error!))),
          );
        }
      }
      return;
    }

    await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ReaderScreen(book: book),
      ),
    );
    if (!mounted) return;
    await library.load();
  }

  Future<void> _createCollection() async {
    final colors = AppPalette.of(context);
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

    final library = context.read<LibraryProvider>();
    await library.createCollection(name);
    if (!mounted) return;
    if (library.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(library.error!))),
      );
    }
  }

  Future<void> _manageCollection(Collection collection) async {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_CollectionAction>(
      context: context,
      backgroundColor: colors.panel,
      builder: (context) => SheetSafeBody(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colors.accent),
              title: Text(l10n.rename),
              onTap: () => Navigator.pop(context, _CollectionAction.rename),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.accent),
              title: Text(l10n.deleteCollection),
              onTap: () => Navigator.pop(context, _CollectionAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _CollectionAction.rename:
        await _renameCollection(collection);
      case _CollectionAction.delete:
        await _confirmDeleteCollection(collection);
    }
  }

  Future<void> _renameCollection(Collection collection) async {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: collection.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: Text(l10n.renameCollection),
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
            child: Text(l10n.save, style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name == null || !mounted) return;

    final library = context.read<LibraryProvider>();
    await library.renameCollection(collection, name);
    if (!mounted) return;
    if (library.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(library.error!))),
      );
    }
  }

  Future<void> _confirmDeleteCollection(Collection collection) async {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.panel,
        title: Text(l10n.deleteCollection),
        content: Text(l10n.deleteCollectionConfirm(collection.name)),
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
      final library = context.read<LibraryProvider>();
      await library.deleteCollection(collection);
      if (!mounted) return;
      if (library.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_msg(library.error!))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: l10n.downloadsBrowser,
            onPressed: () async {
              context.read<DownloaderProvider>().setTargetCollectionId(
                    library.selectedCollectionId,
                  );
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
          PopupMenuButton<AppThemeOption>(
            tooltip: l10n.theme,
            icon: Icon(Icons.palette_outlined, color: colors.accent),
            onSelected: (option) => themeProvider.setTheme(option),
            itemBuilder: (context) => AppThemeOption.values
                .map(
                  (option) => CheckedPopupMenuItem<AppThemeOption>(
                    value: option,
                    checked: option == themeProvider.option,
                    child: Text(option.localizedLabel(l10n)),
                  ),
                )
                .toList(),
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
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onAccent,
                ),
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
            if (library.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _LibraryErrorBanner(
                    message: _msg(library.error!),
                    onRetry: library.load,
                    onDismiss: library.clearError,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: library.setSearchQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    prefixIcon: Icon(
                      Icons.search,
                      color: colors.accent,
                      size: 20,
                    ),
                    suffixIcon: library.searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.clearSearch,
                            onPressed: () {
                              _searchController.clear();
                              library.clearSearch();
                            },
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CollectionsRow(
                library: library,
                onCreate: _createCollection,
                onManageCollection: _manageCollection,
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
                  onImport: library.importing ? null : _importPdf,
                  filtered: library.selectedCollectionId != null ||
                      library.searchQuery.trim().isNotEmpty,
                  searching: library.searchQuery.trim().isNotEmpty,
                  // Solo oculta empty global si no hay libros y hay error de carga.
                  hasError:
                      library.error != null && library.books.isEmpty,
                  importing: library.importing,
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

enum _CollectionAction { rename, delete }

class _CollectionsRow extends StatelessWidget {
  const _CollectionsRow({
    required this.library,
    required this.onCreate,
    required this.onManageCollection,
  });

  final LibraryProvider library;
  final VoidCallback onCreate;
  final ValueChanged<Collection> onManageCollection;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
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
                onLongPress: () => onManageCollection(collection),
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
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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

class _LibraryErrorBanner extends StatelessWidget {
  const _LibraryErrorBanner({
    required this.message,
    required this.onRetry,
    this.onDismiss,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
          if (onDismiss != null)
            IconButton(
              tooltip: l10n.close,
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: colors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.onImport,
    required this.filtered,
    this.searching = false,
    this.hasError = false,
    this.importing = false,
  });

  final VoidCallback? onImport;
  final bool filtered;
  final bool searching;
  final bool hasError;
  final bool importing;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    if (hasError) {
      return const SizedBox.shrink();
    }

    final title = searching
        ? l10n.noSearchResults
        : filtered
            ? l10n.emptyCollection
            : l10n.emptyLibrary;
    final subtitle = searching
        ? l10n.noSearchResultsHint
        : filtered
            ? l10n.emptyCollectionHint
            : l10n.emptyLibraryHint;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.menu_book_outlined,
              size: 42,
              color: colors.accent,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!filtered) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onImport,
                child: Text(importing ? l10n.importing : l10n.importPdf),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
