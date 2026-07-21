import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reader_annotations_provider.dart';

/// Caja de herramientas de anotación (acento bronce Ébano).
class AnnotationToolbox extends StatelessWidget {
  const AnnotationToolbox({
    super.key,
    required this.visible,
    required this.activeTool,
    required this.onSelectTool,
    required this.onClose,
    this.onToggleBookmark,
    this.onClearTool,
    this.isBookmarked = false,
    this.pageNumber,
    this.annotationCount = 0,
  });

  final bool visible;
  final AnnotationTool activeTool;
  final ValueChanged<AnnotationTool> onSelectTool;
  final VoidCallback onClose;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onClearTool;
  final bool isBookmarked;
  final int? pageNumber;
  final int annotationCount;

  static const tools = <AnnotationTool>[
    AnnotationTool.highlight,
    AnnotationTool.underline,
    AnnotationTool.note,
    AnnotationTool.comment,
    AnnotationTool.annotation,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: Material(
            color: colors.panel.withValues(alpha: 0.98),
            elevation: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.ebonyAccent.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.border_color,
                          size: 18,
                          color: AppColors.ebonyAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pageNumber == null
                                ? l10n.annotationTools
                                : l10n.toolsPage(pageNumber!),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.ebonyAccent,
                                ),
                          ),
                        ),
                        if (annotationCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              l10n.annotationsOnPage(annotationCount),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                  ),
                            ),
                          ),
                        if (activeTool != AnnotationTool.none &&
                            onClearTool != null)
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              onClearTool!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: colors.textMuted,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(l10n.releaseTool),
                          ),
                        IconButton(
                          tooltip: l10n.closeToolbox,
                          onPressed: onClose,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close,
                            color: colors.textMuted,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (onToggleBookmark != null) ...[
                            _ToolChip(
                              selected: isBookmarked,
                              label: l10n.bookmarkTool,
                              icon: isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onToggleBookmark!();
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          for (final tool in tools) ...[
                            _ToolChip(
                              selected: activeTool == tool,
                              label: tool.label(l10n),
                              icon: tool.annotationType!.icon,
                              inkPreview: tool.isMarkup,
                              thickInk: tool == AnnotationTool.highlight,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelectTool(tool);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _hintFor(context, activeTool),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _hintFor(BuildContext context, AnnotationTool tool) {
    final l10n = AppLocalizations.of(context);
    return switch (tool) {
      AnnotationTool.none => l10n.annotationHintNone,
      AnnotationTool.highlight => l10n.annotationHintHighlight,
      AnnotationTool.underline => l10n.annotationHintUnderline,
      AnnotationTool.note => l10n.annotationHintNote,
      AnnotationTool.comment => l10n.annotationHintComment,
      AnnotationTool.annotation => l10n.annotationHintAnnotation,
    };
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    this.inkPreview = false,
    this.thickInk = false,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool inkPreview;
  final bool thickInk;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final fg = selected ? AppColors.ebonyBackground : colors.text;
    final bg = selected ? AppColors.ebonyAccent : colors.surface;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? AppColors.ebonyAccent
                    : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? fg : AppColors.ebonyAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
                if (inkPreview) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 18,
                    height: thickInk ? 10 : 2.5,
                    decoration: BoxDecoration(
                      color: selected
                          ? fg.withValues(alpha: thickInk ? 0.55 : 0.9)
                          : AppColors.ebonyAccent.withValues(
                              alpha: thickInk ? 0.55 : 0.9,
                            ),
                      borderRadius: BorderRadius.circular(thickInk ? 4 : 1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
