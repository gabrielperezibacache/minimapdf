import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/l10n/app_localizations.dart';

void main() {
  for (final code in ['es', 'en', 'pt', 'fr', 'de', 'zh', 'ru']) {
    test('l10n $code no expone claves crudas del lector', () {
      final l10n = AppLocalizations(Locale(code));
      expect(l10n.minimizeAnnotationTools, isNot(equals('minimizeAnnotationTools')));
      expect(l10n.expandAnnotationTools, isNot(equals('expandAnnotationTools')));
      expect(l10n.drawingLocksScrollHint, isNot(equals('drawingLocksScrollHint')));
      expect(l10n.readerFirstTip, isNot(equals('readerFirstTip')));
      expect(l10n.previousPage, isNot(equals('previousPage')));
      expect(l10n.nextPage, isNot(equals('nextPage')));
      expect(l10n.strokeTooShortHint, isNot(equals('strokeTooShortHint')));
      expect(l10n.annotationNote, isNotEmpty);
    });
  }
}
