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
      expect(l10n.drawingAllowsScrollHint, isNot(equals('drawingAllowsScrollHint')));
      expect(l10n.lockPageNavigation, isNot(equals('lockPageNavigation')));
      expect(l10n.unlockPageNavigation, isNot(equals('unlockPageNavigation')));
      expect(l10n.readerFirstTip, isNot(equals('readerFirstTip')));
      expect(l10n.previousPage, isNot(equals('previousPage')));
      expect(l10n.nextPage, isNot(equals('nextPage')));
      expect(l10n.snapToTextOn, isNot(equals('snapToTextOn')));
      expect(l10n.snapToTextOff, isNot(equals('snapToTextOff')));
      expect(l10n.snapToTextHint, isNot(equals('snapToTextHint')));
      expect(l10n.selectTextTool, isNot(equals('selectTextTool')));
      expect(l10n.searchTextTool, isNot(equals('searchTextTool')));
      expect(l10n.searchTextNoResults, isNot(equals('searchTextNoResults')));
      expect(l10n.selectTextHint, isNot(equals('selectTextHint')));
      expect(l10n.noSelectableText, isNot(equals('noSelectableText')));
      expect(l10n.copyText, isNot(equals('copyText')));
      expect(l10n.textCopied, isNot(equals('textCopied')));
      expect(l10n.done, isNot(equals('done')));
      expect(l10n.selectedCharacters(3), contains('3'));
      expect(l10n.toolStillArmedHint, isNot(equals('toolStillArmedHint')));
      expect(l10n.emptyNoteNotSaved, isNot(equals('emptyNoteNotSaved')));
      expect(l10n.strokeTooShortHint, isNot(equals('strokeTooShortHint')));
      expect(l10n.annotationNote, isNotEmpty);
    });
  }
}
