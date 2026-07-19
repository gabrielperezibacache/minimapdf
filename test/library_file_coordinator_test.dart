import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/utils/library_file_coordinator.dart';

void main() {
  tearDown(LibraryFileCoordinator.debugReset);

  test('runExclusive serializa acciones concurrentes', () async {
    final order = <int>[];
    final startedSecond = Completer<void>();

    final first = LibraryFileCoordinator.runExclusive(() async {
      order.add(1);
      // Da tiempo a que la segunda se encole antes de terminar.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      order.add(2);
    });

    // Espera a que la primera haya entrado.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final second = LibraryFileCoordinator.runExclusive(() async {
      startedSecond.complete();
      order.add(3);
    });

    await Future.wait([first, second]);
    expect(startedSecond.isCompleted, isTrue);
    expect(order, [1, 2, 3]);
  });
}
