import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('minimal_pdf_prefs_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('por defecto no se ha visto la bienvenida', () async {
    final prefs = await AppPreferences.open(directory: tempDir);
    expect(prefs.hasSeenWelcome, isFalse);
  });

  test('markWelcomeSeen persiste entre aperturas', () async {
    final first = await AppPreferences.open(directory: tempDir);
    first.markWelcomeSeen();
    expect(first.hasSeenWelcome, isTrue);

    final second = await AppPreferences.open(directory: tempDir);
    expect(second.hasSeenWelcome, isTrue);
  });
}
