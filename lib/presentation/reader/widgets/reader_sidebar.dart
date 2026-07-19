import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/bookmark.dart';
import '../pdf_toc_entry.dart';

/// Panel lateral deslizable (índice + marcadores).
class ReaderSidebar extends StatelessWidget {
  const ReaderSidebar({
    super.key,
    required this.visible,
    required this.pagesCount,
    required this.currentPage,
    required this.bookmarks,
    required this.onClose,
    required this.onOpenPage,
    required this.onDeleteBookmark,
  });

  final bool visible;
  final int pagesCount;
  final int currentPage;
  final List<Bookmark> bookmarks;
  final VoidCallback onClose;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<Bookmark> onDeleteBookmark;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final width = MediaQuery.sizeOf(context).width * 0.82;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible ? 1 : 0,
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: visible ? 0 : -width,
          top: 0,
          bottom: 0,
          width: width,
          child: Material(
            color: colors.panel,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: colors.border, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SidebarHeader(onClose: onClose),
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: AppColors.ebonyAccent,
                            unselectedLabelColor: colors.textMuted,
                            indicatorColor: AppColors.ebonyAccent,
                            tabs: const [
                              Tab(text: 'Índice'),
                              Tab(text: 'Marcadores'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _TocPane(
                                  pagesCount: pagesCount,
                                  currentPage: currentPage,
                                  onOpenPage: onOpenPage,
                                ),
                                _BookmarksPane(
                                  bookmarks: bookmarks,
                                  currentPage: currentPage,
                                  onOpenPage: onOpenPage,
                                  onDelete: onDeleteBookmark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            'Navegación',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ebonyAccent,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onClose,
            icon: Icon(Icons.close, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TocPane extends StatefulWidget {
  const _TocPane({
    required this.pagesCount,
    required this.currentPage,
    required this.onOpenPage,
  });

  final int pagesCount;
  final int currentPage;
  final ValueChanged<int> onOpenPage;

  @override
  State<_TocPane> createState() => _TocPaneState();
}

class _TocPaneState extends State<_TocPane> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpFromField() {
    final value = int.tryParse(_pageController.text.trim());
    if (value == null) return;
    if (value < 1 || value > widget.pagesCount) return;
    widget.onOpenPage(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final entries = PdfTocEntry.fromPageCount(widget.pagesCount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ir a página',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _jumpFromField(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Ir',
                onPressed: _jumpFromField,
                icon: Icon(Icons.arrow_forward, color: AppColors.ebonyAccent),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Índice de páginas',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final selected = entry.pageNumber == widget.currentPage;
              return InkWell(
                onTap: () => widget.onOpenPage(entry.pageNumber),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? colors.surface : null,
                    border: Border(
                      left: BorderSide(
                        color: selected
                            ? AppColors.ebonyAccent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? AppColors.ebonyAccent
                              : colors.text,
                        ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookmarksPane extends StatelessWidget {
  const _BookmarksPane({
    required this.bookmarks,
    required this.currentPage,
    required this.onOpenPage,
    required this.onDelete,
  });

  final List<Bookmark> bookmarks;
  final int currentPage;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<Bookmark> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    if (bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sin marcadores.\nMarca la página actual con el icono bronce.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: bookmarks.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        final selected = bookmark.pageNumber == currentPage;
        final hasNote =
            bookmark.noteText != null && bookmark.noteText!.isNotEmpty;

        return ListTile(
          selected: selected,
          selectedColor: AppColors.ebonyAccent,
          leading: Icon(
            hasNote ? Icons.sticky_note_2 : Icons.bookmark,
            color: AppColors.ebonyAccent,
          ),
          title: Text('Página ${bookmark.pageNumber}'),
          subtitle: hasNote
              ? Text(
                  bookmark.noteText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => onOpenPage(bookmark.pageNumber),
          trailing: IconButton(
            tooltip: 'Eliminar',
            onPressed: () => onDelete(bookmark),
            icon: Icon(Icons.delete_outline, color: colors.textMuted, size: 20),
          ),
        );
      },
    );
  }
}
