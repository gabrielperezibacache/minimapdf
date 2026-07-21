import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/presentation/reader/widgets/text_selection_layer.dart';

void main() {
  testWidgets('handlePointerCancel limpia la selección', (tester) async {
    var selected = 'prev';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: TextSelectionLayer(
              lines: const [],
              externalPointerRouting: true,
              onSelectionChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );

    final state = tester.state<TextSelectionLayerState>(
      find.byType(TextSelectionLayer),
    );

    final pointer = TestPointer(1, PointerDeviceKind.touch);
    state.handlePointerDown(
      pointer.down(const Offset(40, 40)),
    );
    await tester.pump();

    state.handlePointerCancel(
      pointer.cancel(),
    );
    await tester.pump();

    expect(selected, '');
  });
}
