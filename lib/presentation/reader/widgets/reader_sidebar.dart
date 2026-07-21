import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/document_signature.dart';
import '../../../data/models/page_annotation.dart';
import '../../../data/models/signature_role.dart';
import '../../../data/models/signature_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../signing/signature_overlay.dart';
import '../pdf_toc_entry.dart';

/// Panel lateral deslizable (índice + marcadores + anotaciones + firmas).
class ReaderSidebar extends StatelessWidget {
  const ReaderSidebar({
    super.key,
    required this.visible,
    required this.pagesCount,
    required this.currentPage,
    required this.bookmarks,
    this.annotations = const [],
    this.signatures = const [],
    required this.onClose,
    required this.onOpenPage,
    required this.onDeleteBookmark,
    this.onDeleteAnnotation,
    this.onOpenAnnotation,
    this.onDeleteSignature,
    this.onOpenAnnotationTools,
    this.onStartSigning,
    this.onAddBookmark,
    this.currentPageBookmarked = false,
  });

  final bool visible;
  final int pagesCount;
  final int currentPage;
  final List<Bookmark> bookmarks;
  final List<PageAnnotation> annotations;
  final List<DocumentSignature> signatures;
  final VoidCallback onClose;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<Bookmark> onDeleteBookmark;
  final ValueChanged<PageAnnotation>? onDeleteAnnotation;
  final ValueChanged<PageAnnotation>? onOpenAnnotation;
  final ValueChanged<DocumentSignature>? onDeleteSignature;
  final VoidCallback? onOpenAnnotationTools;
  final VoidCallback? onStartSigning;
  final VoidCallback? onAddBookmark;
  final bool currentPageBookmarked;

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
                  _SidebarHeader(
                    currentPage: currentPage,
                    pagesCount: pagesCount,
                    onClose: onClose,
                  ),
                  Expanded(
                    child: DefaultTabController(
                      length: 4,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: colors.accent,
                            unselectedLabelColor: colors.textMuted,
                            indicatorColor: colors.accent,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: [
                              Tab(text: AppLocalizations.of(context).tocTab),
                              Tab(
                                text:
                                    AppLocalizations.of(context).bookmarksTab,
                              ),
                              Tab(
                                text: AppLocalizations.of(context)
                                    .annotationsTab,
                              ),
                              Tab(
                                text:
                                    AppLocalizations.of(context).signaturesTab,
                              ),
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
                                  currentPageBookmarked: currentPageBookmarked,
                                  onOpenPage: onOpenPage,
                                  onDelete: onDeleteBookmark,
                                  onAddBookmark: onAddBookmark,
                                ),
                                _AnnotationsPane(
                                  annotations: annotations,
                                  currentPage: currentPage,
                                  onOpenPage: onOpenPage,
                                  onDelete: onDeleteAnnotation,
                                  onOpen: onOpenAnnotation,
                                  onOpenTools: onOpenAnnotationTools,
                                ),
                                _SignaturesPane(
                                  signatures: signatures,
                                  currentPage: currentPage,
                                  onOpenPage: onOpenPage,
                                  onDelete: onDeleteSignature,
                                  onStartSigning: onStartSigning,
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
  const _SidebarHeader({
    required this.currentPage,
    required this.pagesCount,
    required this.onClose,
  });

  final int currentPage;
  final int pagesCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final pageLabel =
        pagesCount > 0 ? '$currentPage / $pagesCount' : '$currentPage';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.navigation,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.accent,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.pageNumber(currentPage),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
            ),
            child: Text(
              pageLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.accent,
                  ),
            ),
          ),
          IconButton(
            tooltip: l10n.close,
            onPressed: onClose,
            icon: Icon(Icons.close, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  const _SidebarEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.info_outline,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: colors.textMuted.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    height: 1.35,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction!();
                },
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.ebonyAccent,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.ebonyAccent.withValues(alpha: 0.18),
        border: Border.all(
          color: AppColors.ebonyAccent.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        l10n.currentPageBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.ebonyAccent,
              fontWeight: FontWeight.w600,
            ),
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
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(covariant _TocPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_listController.hasClients) return;
    final index = (widget.currentPage - 1).clamp(0, widget.pagesCount - 1);
    if (widget.pagesCount <= 0) return;
    const itemExtent = 48.0;
    final target = (index * itemExtent) -
        (_listController.position.viewportDimension / 2) +
        (itemExtent / 2);
    _listController.animateTo(
      target.clamp(0.0, _listController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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
    final pagesCount = widget.pagesCount < 0 ? 0 : widget.pagesCount;

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
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).goToPage,
                    hintText: pagesCount > 0 ? '1–$pagesCount' : null,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _jumpFromField(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: AppLocalizations.of(context).go,
                onPressed: _jumpFromField,
                icon: Icon(Icons.arrow_forward, color: colors.accent),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context).pageIndex,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            controller: _listController,
            itemExtent: 48,
            itemCount: pagesCount,
            itemBuilder: (context, index) {
              final l10n = AppLocalizations.of(context);
              final entry = PdfTocEntry.forPage(
                index + 1,
                title: l10n.pageNumber(index + 1),
              );
              final selected = entry.pageNumber == widget.currentPage;
              return InkWell(
                onTap: () => widget.onOpenPage(entry.pageNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected ? colors.surface : null,
                    border: Border(
                      left: BorderSide(
                        color: selected ? colors.accent : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color:
                                        selected ? colors.accent : colors.text,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                        ),
                      ),
                      if (selected) const _CurrentBadge(),
                    ],
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
    required this.currentPageBookmarked,
    required this.onOpenPage,
    required this.onDelete,
    this.onAddBookmark,
  });

  final List<Bookmark> bookmarks;
  final int currentPage;
  final bool currentPageBookmarked;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<Bookmark> onDelete;
  final VoidCallback? onAddBookmark;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    if (bookmarks.isEmpty) {
      return _SidebarEmptyState(
        message: l10n.noBookmarks,
        icon: Icons.bookmark_border,
        actionLabel: onAddBookmark == null ? null : l10n.addBookmark,
        onAction: onAddBookmark,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onAddBookmark != null && !currentPageBookmarked)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                onAddBookmark!();
              },
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(l10n.bookmarkThisPage),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ebonyAccent,
                side: BorderSide(
                  color: AppColors.ebonyAccent.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: bookmarks.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: colors.border),
            itemBuilder: (context, index) {
              final bookmark = bookmarks[index];
              final selected = bookmark.pageNumber == currentPage;
              final hasNote = bookmark.noteText != null &&
                  bookmark.noteText!.isNotEmpty;

              return ListTile(
                selected: selected,
                selectedColor: colors.accent,
                leading: Icon(
                  hasNote ? Icons.sticky_note_2 : Icons.bookmark,
                  color: colors.accent,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.pageNumber(bookmark.pageNumber)),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const _CurrentBadge(),
                    ],
                  ],
                ),
                subtitle: hasNote
                    ? Text(
                        bookmark.noteText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () => onOpenPage(bookmark.pageNumber),
                trailing: IconButton(
                  tooltip: l10n.delete,
                  onPressed: () => onDelete(bookmark),
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.textMuted,
                    size: 20,
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

class _AnnotationsPane extends StatelessWidget {
  const _AnnotationsPane({
    required this.annotations,
    required this.currentPage,
    required this.onOpenPage,
    this.onDelete,
    this.onOpen,
    this.onOpenTools,
  });

  final List<PageAnnotation> annotations;
  final int currentPage;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<PageAnnotation>? onDelete;
  final ValueChanged<PageAnnotation>? onOpen;
  final VoidCallback? onOpenTools;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    if (annotations.isEmpty) {
      return _SidebarEmptyState(
        message: l10n.noAnnotations,
        icon: Icons.border_color,
        actionLabel: onOpenTools == null ? null : l10n.emptyAnnotationsCta,
        onAction: onOpenTools,
      );
    }

    return ListView.separated(
      itemCount: annotations.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final annotation = annotations[index];
        final selected = annotation.pageNumber == currentPage;

        return ListTile(
          selected: selected,
          selectedColor: AppColors.ebonyAccent,
          leading: Icon(annotation.type.icon, color: AppColors.ebonyAccent),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${annotation.type.label(l10n)} · ${l10n.pageAbbrev(annotation.pageNumber)}',
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const _CurrentBadge(),
              ],
            ],
          ),
          subtitle: annotation.hasText
              ? Text(
                  annotation.text!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () {
            onOpenPage(annotation.pageNumber);
            onOpen?.call(annotation);
          },
          trailing: onDelete == null
              ? null
              : IconButton(
                  tooltip: l10n.delete,
                  onPressed: () => onDelete!(annotation),
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.textMuted,
                    size: 20,
                  ),
                ),
        );
      },
    );
  }
}

class _SignaturesPane extends StatelessWidget {
  const _SignaturesPane({
    required this.signatures,
    required this.currentPage,
    required this.onOpenPage,
    this.onDelete,
    this.onStartSigning,
  });

  final List<DocumentSignature> signatures;
  final int currentPage;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<DocumentSignature>? onDelete;
  final VoidCallback? onStartSigning;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    if (signatures.isEmpty) {
      return _SidebarEmptyState(
        message: l10n.noSignatures,
        icon: Icons.draw_outlined,
        actionLabel: onStartSigning == null ? null : l10n.emptySignaturesCta,
        onAction: onStartSigning,
      );
    }

    return ListView.separated(
      itemCount: signatures.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
      itemBuilder: (context, index) {
        final signature = signatures[index];
        final selected = signature.pageNumber == currentPage;

        return ListTile(
          selected: selected,
          selectedColor: AppColors.ebonyAccent,
          leading: Icon(
            signature.type == SignatureType.typed
                ? Icons.text_fields
                : Icons.gesture,
            color: AppColors.ebonyAccent,
          ),
          title: Row(
            children: [
              Expanded(child: Text(signature.signerName)),
              if (selected) ...[
                const SizedBox(width: 8),
                const _CurrentBadge(),
              ],
            ],
          ),
          subtitle: Text(
            '${l10n.pageAbbrev(signature.pageNumber)} · ${signature.role.label(l10n)} '
            '#${signature.signingOrder}\n'
            '${signature.type.label(l10n)} · ${formatSignatureDate(signature.signedAt, locale: Localizations.localeOf(context).toString())}',
          ),
          isThreeLine: true,
          onTap: () => onOpenPage(signature.pageNumber),
          trailing: onDelete == null
              ? null
              : IconButton(
                  tooltip: l10n.delete,
                  onPressed: () => onDelete!(signature),
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.textMuted,
                    size: 20,
                  ),
                ),
        );
      },
    );
  }
}
