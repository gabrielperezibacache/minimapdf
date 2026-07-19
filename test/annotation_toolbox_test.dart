import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/widgets/annotation_toolbox.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.ebony,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  testWidgets('muestra herramientas de anotación con acento bronce', (tester) async {
    AnnotationTool? selected;

    await tester.pumpWidget(
      wrap(
        AnnotationToolbox(
          visible: true,
          activeTool: AnnotationTool.none,
          pageNumber: 3,
          annotationCount: 2,
          onSelectTool: (tool) => selected = tool,
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Herramientas · p. 3'), findsOneWidget);
    expect(find.text('2 en página'), findsOneWidget);
    expect(find.text('Marcado'), findsOneWidget);
    expect(find.text('Subrayado'), findsOneWidget);
    expect(find.text('Nota'), findsOneWidget);
    expect(find.text('Comentario'), findsOneWidget);
    expect(find.text('Anotación'), findsOneWidget);
    expect(
      find.text('Elige una herramienta de acento bronce para anotar el PDF.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Subrayado'));
    await tester.pump();
    expect(selected, AnnotationTool.underline);
  });

  testWidgets('muestra hint y Soltar cuando hay herramienta activa', (tester) async {
    var cleared = false;

    await tester.pumpWidget(
      wrap(
        AnnotationToolbox(
          visible: true,
          activeTool: AnnotationTool.note,
          pageNumber: 1,
          onSelectTool: (_) {},
          onClearTool: () => cleared = true,
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Toca la página para colocar una nota.'), findsOneWidget);
    expect(find.text('Soltar'), findsOneWidget);

    await tester.tap(find.text('Soltar'));
    await tester.pump();
    expect(cleared, isTrue);
  });

  testWidgets('oculta interacción cuando visible es false', (tester) async {
    var selected = false;

    await tester.pumpWidget(
      wrap(
        AnnotationToolbox(
          visible: false,
          activeTool: AnnotationTool.highlight,
          onSelectTool: (_) => selected = true,
          onClose: () {},
        ),
      ),
    );

    await tester.tap(find.text('Marcado'), warnIfMissed: false);
    await tester.pump();
    expect(selected, isFalse);
  });
}
