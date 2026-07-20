import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Nota flotante sobre la página actual (acento del tema activo).
class FloatingPageNote extends StatelessWidget {
  const FloatingPageNote({
    super.key,
    required this.noteText,
    required this.pageNumber,
    this.onEdit,
    this.onDismiss,
  });

  final String noteText;
  final int pageNumber;
  final VoidCallback? onEdit;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Material(
      color: colors.panel.withValues(alpha: 0.96),
      child: InkWell(
        onTap: onEdit,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            border: Border.all(color: colors.accent, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: colors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.notePageAbbrev(pageNumber),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.accent,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noteText,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  tooltip: l10n.close,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 16, color: colors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
