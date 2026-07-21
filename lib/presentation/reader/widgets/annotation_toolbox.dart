import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reader_annotations_provider.dart';
import '../annotation_ink.dart';

/// Caja de herramientas de anotación (estilo Samsung Notes / acento Ébano).
class AnnotationToolbox extends StatelessWidget {
  const AnnotationToolbox({
    super.key,
    required this.visible,
    required this.activeTool,
    required this.onSelectTool,
    required this.onClose,
    this.onToggleBookmark,
    this.onClearTool,
    this.onToggleNavigationLock,
    this.onToggleSnapToText,
    this.snapToText = true,
    this.navigationLocked = true,
    this.isBookmarked = false,
    this.pageNumber,
    this.annotationCount = 0,
    this.inkColor,
    this.onInkColorChanged,
    this.strokeSizeIndex = 2,
    this.onStrokeSizeChanged,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
    this.canSave = false,
    this.saving = false,
    this.onSave,
  });

  final bool visible;
  final AnnotationTool activeTool;
  final ValueChanged<AnnotationTool> onSelectTool;
  final VoidCallback onClose;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onClearTool;
  final VoidCallback? onToggleNavigationLock;
  final VoidCallback? onToggleSnapToText;
  /// Candado cerrado = sin scroll/zoom; abierto = permitir con dos dedos.
  final bool navigationLocked;
  /// Imantar marcado/subrayado a las líneas de texto detectadas.
  final bool snapToText;
  final bool isBookmarked;
  final int? pageNumber;
  final int annotationCount;
  final Color? inkColor;
  final ValueChanged<Color>? onInkColorChanged;
  final int strokeSizeIndex;
  final ValueChanged<int>? onStrokeSizeChanged;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canSave;
  final bool saving;
  final VoidCallback? onSave;

  static const tools = <AnnotationTool>[
    AnnotationTool.highlight,
    AnnotationTool.underline,
    AnnotationTool.note,
  ];

  bool get _showInkControls =>
      activeTool.isMarkup &&
      onInkColorChanged != null &&
      onStrokeSizeChanged != null;

  /// Fila de controles (deshacer/rehacer + imantado/candado) visible cuando
  /// hay herramienta activa o historial que deshacer.
  bool get _showControlsRow =>
      activeTool != AnnotationTool.none || canUndo || canRedo;

  bool get _showFooter =>
      onSave != null ||
      (activeTool != AnnotationTool.none && onClearTool != null);

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedInk = inkColor ?? MarkupInkStyle.palette[1];

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildGrabber(colors),
                    const SizedBox(height: 10),
                    _buildHeader(context, colors, l10n),
                    if (_showControlsRow) ...[
                      const SizedBox(height: 10),
                      _buildControlsRow(context, colors, l10n),
                    ],
                    const SizedBox(height: 14),
                    _buildToolChips(context, colors, l10n, selectedInk),
                    if (_showInkControls) ...[
                      const SizedBox(height: 16),
                      _buildColorRow(context, colors, l10n, selectedInk),
                      const SizedBox(height: 12),
                      _buildSizeRow(context, colors, l10n, selectedInk),
                    ],
                    const SizedBox(height: 14),
                    _buildHints(context, colors, l10n),
                    if (_showFooter) ...[
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.border.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      _buildFooter(context, colors, l10n),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber(AppPalette colors) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colors.textMuted.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        const Icon(Icons.border_color, size: 18, color: AppColors.ebonyAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            pageNumber == null
                ? l10n.annotationTools
                : l10n.toolsPage(pageNumber!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.ebonyAccent,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (annotationCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.ebonyAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.annotationsOnPage(annotationCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.ebonyAccent,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          tooltip: activeTool != AnnotationTool.none
              ? l10n.minimizeAnnotationTools
              : l10n.closeToolbox,
          onPressed: onClose,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            activeTool != AnnotationTool.none
                ? Icons.keyboard_arrow_down
                : Icons.close,
            color: colors.textMuted,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsRow(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
  ) {
    final markup = activeTool.isMarkup;
    return Row(
      children: [
        _ControlButton(
          tooltip: l10n.annotationUndo,
          icon: Icons.undo,
          enabled: canUndo && onUndo != null,
          onTap: () {
            HapticFeedback.selectionClick();
            onUndo?.call();
          },
        ),
        const SizedBox(width: 4),
        _ControlButton(
          tooltip: l10n.annotationRedo,
          icon: Icons.redo,
          enabled: canRedo && onRedo != null && !saving,
          onTap: () {
            HapticFeedback.selectionClick();
            onRedo?.call();
          },
        ),
        const Spacer(),
        if (markup && onToggleSnapToText != null)
          _ControlButton(
            tooltip: snapToText ? l10n.snapToTextOn : l10n.snapToTextOff,
            // Regla = imantado (recto al texto); trazo = libre.
            icon: snapToText ? Icons.straighten : Icons.gesture,
            active: snapToText,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleSnapToText!();
            },
          ),
        if (markup && onToggleNavigationLock != null) ...[
          const SizedBox(width: 4),
          _ControlButton(
            tooltip: navigationLocked
                ? l10n.unlockPageNavigation
                : l10n.lockPageNavigation,
            icon: navigationLocked ? Icons.lock : Icons.lock_open,
            active: true,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleNavigationLock!();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildToolChips(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
    Color selectedInk,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (onToggleBookmark != null) ...[
            _ToolChip(
              selected: isBookmarked,
              label: l10n.bookmarkTool,
              icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleBookmark!();
              },
            ),
            const SizedBox(width: 10),
          ],
          for (var i = 0; i < tools.length; i++) ...[
            _ToolChip(
              selected: activeTool == tools[i],
              label: tools[i].label(l10n),
              icon: tools[i].annotationType!.icon,
              inkPreview: tools[i].isMarkup,
              thickInk: tools[i] == AnnotationTool.highlight,
              previewColor: tools[i].isMarkup ? selectedInk : null,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectTool(tools[i]);
              },
            ),
            if (i < tools.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildColorRow(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
    Color selectedInk,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            l10n.annotationInkColor,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < MarkupInkStyle.palette.length; i++) ...[
                  _ColorDot(
                    color: MarkupInkStyle.palette[i],
                    selected: selectedInk.toARGB32() ==
                        MarkupInkStyle.palette[i].toARGB32(),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onInkColorChanged!(MarkupInkStyle.palette[i]);
                    },
                  ),
                  if (i < MarkupInkStyle.palette.length - 1)
                    const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeRow(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
    Color selectedInk,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            l10n.annotationStrokeSize,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < MarkupInkStyle.sizeCount; i++) ...[
                  _StrokeSizeDot(
                    sizeIndex: i,
                    selected: strokeSizeIndex == i,
                    tool: activeTool,
                    color: selectedInk,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onStrokeSizeChanged!(i);
                    },
                  ),
                  if (i < MarkupInkStyle.sizeCount - 1)
                    const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHints(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _hintFor(context, activeTool),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.textMuted),
        ),
        if (activeTool.isMarkup) ...[
          const SizedBox(height: 6),
          Text(
            navigationLocked
                ? l10n.drawingLocksScrollHint
                : l10n.drawingAllowsScrollHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ebonyAccent.withValues(alpha: 0.9),
                ),
          ),
          if (onToggleSnapToText != null && snapToText) ...[
            const SizedBox(height: 4),
            Text(
              l10n.snapToTextHint,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textMuted),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AppPalette colors,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        if (onSave != null)
          Flexible(
            child: TextButton.icon(
              onPressed: canSave && !saving
                  ? () {
                      HapticFeedback.selectionClick();
                      onSave!();
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ebonyAccent,
                visualDensity: VisualDensity.compact,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ebonyAccent,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.saveAnnotations, overflow: TextOverflow.ellipsis),
            ),
          ),
        const Spacer(),
        if (activeTool != AnnotationTool.none && onClearTool != null)
          Flexible(
            child: TextButton(
              onPressed: saving
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onClearTool!();
                    },
              style: TextButton.styleFrom(
                foregroundColor: colors.textMuted,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.releaseTool, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
    );
  }

  String _hintFor(BuildContext context, AnnotationTool tool) {
    final l10n = AppLocalizations.of(context);
    return switch (tool) {
      AnnotationTool.none => l10n.annotationHintNone,
      AnnotationTool.highlight => l10n.annotationHintHighlight,
      AnnotationTool.underline => l10n.annotationHintUnderline,
      AnnotationTool.note => l10n.annotationHintNote,
      // Comentario/anotación genérica ya no están en la caja; se mantienen por datos antiguos.
      AnnotationTool.comment => l10n.annotationHintComment,
      AnnotationTool.annotation => l10n.annotationHintAnnotation,
    };
  }
}

/// Botón de control compacto (deshacer/rehacer, imantado, candado).
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final Color fg;
    if (!enabled) {
      fg = colors.textMuted.withValues(alpha: 0.4);
    } else if (active) {
      fg = AppColors.ebonyAccent;
    } else {
      fg = colors.text;
    }
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active && enabled
                  ? AppColors.ebonyAccent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active && enabled
                    ? AppColors.ebonyAccent.withValues(alpha: 0.35)
                    : colors.border.withValues(alpha: 0.6),
              ),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    // Marca de selección con contraste según luminancia del color.
    final luma = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b);
    final checkColor = luma > 0.6 ? AppColors.ebonyBackground : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: 'color',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected ? AppColors.ebonyAccent : colors.border,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 16, color: checkColor)
              : null,
        ),
      ),
    );
  }
}

class _StrokeSizeDot extends StatelessWidget {
  const _StrokeSizeDot({
    required this.sizeIndex,
    required this.selected,
    required this.tool,
    required this.color,
    required this.onTap,
  });

  final int sizeIndex;
  final bool selected;
  final AnnotationTool tool;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final previewH = tool == AnnotationTool.highlight
        ? (8.0 + sizeIndex * 3.5).clamp(8.0, 20.0)
        : (2.0 + sizeIndex * 1.6).clamp(2.0, 8.0);
    final paintColor = MarkupInkStyle.resolveColor(color, tool);

    return Semantics(
      button: true,
      selected: selected,
      label: 'size $sizeIndex',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.ebonyAccent.withValues(alpha: 0.18)
                : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.ebonyAccent : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Container(
            width: 22,
            height: previewH,
            decoration: BoxDecoration(
              color: paintColor,
              borderRadius: BorderRadius.circular(
                tool == AnnotationTool.highlight ? 4 : 1,
              ),
            ),
          ),
        ),
      ),
    );
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
    this.previewColor,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool inkPreview;
  final bool thickInk;
  final Color? previewColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final fg = selected ? AppColors.ebonyBackground : colors.text;
    final bg = selected ? AppColors.ebonyAccent : colors.surface;
    final swatch = previewColor ?? AppColors.ebonyAccent;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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
                          : swatch.withValues(alpha: thickInk ? 0.55 : 0.9),
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
