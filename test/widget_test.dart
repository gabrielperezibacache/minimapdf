import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/constants/app_constants.dart';
import 'package:minimal_pdf/main.dart';

void main() {
  testWidgets('Minimal PDF muestra la pantalla base de biblioteca',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MinimalPdfApp());

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text(AppConstants.appTagline), findsOneWidget);
    expect(find.text('Hermes Obsidian'), findsOneWidget);
  });
}
