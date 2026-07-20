import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/presentation/widgets/sheet_safe_body.dart';

void main() {
  testWidgets('SheetSafeBody envuelve en SafeArea inferior', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SheetSafeBody(
            child: Text('contenido'),
          ),
        ),
      ),
    );

    expect(find.text('contenido'), findsOneWidget);
    final safe = tester.widget<SafeArea>(find.byType(SafeArea));
    expect(safe.bottom, isTrue);
    expect(safe.top, isTrue);
  });
}
