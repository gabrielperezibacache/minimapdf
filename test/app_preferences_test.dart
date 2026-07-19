import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/preferences/app_preferences.dart';
import 'package:path/path.dart' as p;

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

  test('markWelcomeSeen es idempotente', () async {
    final prefs = await AppPreferences.open(directory: tempDir);
    prefs.markWelcomeSeen();
    prefs.markWelcomeSeen();
    expect(prefs.hasSeenWelcome, isTrue);

    final file = File(p.join(tempDir.path, AppPreferences.fileName));
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('"has_seen_welcome":true'));
  });

  test('archivo corrupto no rompe la apertura', () async {
    final file = File(p.join(tempDir.path, AppPreferences.fileName));
    await file.writeAsString('{no-json');

    final prefs = await AppPreferences.open(directory: tempDir);
    expect(prefs.hasSeenWelcome, isFalse);
    prefs.markWelcomeSeen();
    expect(prefs.hasSeenWelcome, isTrue);

    final again = await AppPreferences.open(directory: tempDir);
    expect(again.hasSeenWelcome, isTrue);
  });
}
