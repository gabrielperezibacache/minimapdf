import 'package:flutter/material.dart';

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
                              Tab(text: AppLocalizations.of(context).bookmarksTab),
                              Tab(text: AppLocalizations.of(context).annotationsTab),
                              Tab(text: AppLocalizations.of(context).signaturesTab),
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
                                _AnnotationsPane(
                                  annotations: annotations,
                                  currentPage: currentPage,
                                  onOpenPage: onOpenPage,
                                  onDelete: onDeleteAnnotation,
                                  onOpen: onOpenAnnotation,
                                ),
                                _SignaturesPane(
                                  signatures: signatures,
                                  currentPage: currentPage,
                                  onOpenPage: onOpenPage,
                                  onDelete: onDeleteSignature,
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
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            l10n.navigation,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.accent,
                ),
          ),
          const Spacer(),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? colors.surface : null,
                    border: Border(
                      left: BorderSide(
                        color: selected ? colors.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? colors.accent : colors.text,
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
    final l10n = AppLocalizations.of(context);

    if (bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noBookmarks,
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
          selectedColor: colors.accent,
          leading: Icon(
            hasNote ? Icons.sticky_note_2 : Icons.bookmark,
            color: colors.accent,
          ),
          title: Text(l10n.pageNumber(bookmark.pageNumber)),
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
            icon: Icon(Icons.delete_outline, color: colors.textMuted, size: 20),
          ),
        );
      },
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
  });

  final List<PageAnnotation> annotations;
  final int currentPage;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<PageAnnotation>? onDelete;
  final ValueChanged<PageAnnotation>? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    if (annotations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noAnnotations,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
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
          title: Text(
            '${annotation.type.label(l10n)} · ${l10n.pageAbbrev(annotation.pageNumber)}',
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
  });

  final List<DocumentSignature> signatures;
  final int currentPage;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<DocumentSignature>? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    if (signatures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.noSignatures,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
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
          title: Text(signature.signerName),
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
