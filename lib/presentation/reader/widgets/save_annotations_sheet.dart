import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/annotated_pdf_export_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/sheet_safe_body.dart';

/// Sheet para elegir dónde aplanar las anotaciones de la toolbox.
Future<AnnotatedPdfSaveTarget?> showSaveAnnotationsSheet(
  BuildContext context,
) {
  final colors = AppPalette.of(context);
  return showModalBottomSheet<AnnotatedPdfSaveTarget>(
    context: context,
    backgroundColor: colors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SheetSafeBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.saveAnnotationsTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ebonyAccent,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.saveAnnotationsLead,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.save_outlined,
                color: AppColors.ebonyAccent,
              ),
              title: Text(l10n.saveAnnotationsInDocument),
              subtitle: Text(
                l10n.saveAnnotationsInDocumentHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(
                  context,
                  AnnotatedPdfSaveTarget.currentDocument,
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.copy_all_outlined,
                color: AppColors.ebonyAccent,
              ),
              title: Text(l10n.saveAnnotationsAsCopy),
              subtitle: Text(
                l10n.saveAnnotationsAsCopyHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(
                  context,
                  AnnotatedPdfSaveTarget.libraryCopy,
                );
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      );
    },
  );
}
