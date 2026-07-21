import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/l10n/app_localizations.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/widgets/annotation_toolbox.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.ebony,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
    expect(find.text('Chincheta'), findsOneWidget);
    expect(find.text('Comentario'), findsNothing);
    expect(find.text('Anotación'), findsNothing);
    expect(
      find.text(
        'Elige Marcado o Subrayado y dibuja; o Chincheta y toca la página.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Subrayado'));
    await tester.pump();
    expect(selected, AnnotationTool.underline);
  });

  testWidgets('muestra hint y Deseleccionar cuando hay herramienta activa',
      (tester) async {
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

    expect(
      find.text('Toca la página para anclar una chincheta.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Herramienta activa: deselecciona para desplazarte o editar marcas.',
      ),
      findsOneWidget,
    );
    expect(find.text('Deseleccionar'), findsOneWidget);

    await tester.tap(find.text('Deseleccionar'));
    await tester.pump();
    expect(cleared, isTrue);
  });

  testWidgets('muestra color, grosor y deshacer/rehacer con Marcado',
      (tester) async {
    Color? picked;
    var size = -1;
    var undone = false;
    var redone = false;

    await tester.pumpWidget(
      wrap(
        AnnotationToolbox(
          visible: true,
          activeTool: AnnotationTool.highlight,
          inkColor: const Color(0xFFC89A5A),
          strokeSizeIndex: 2,
          canUndo: true,
          canRedo: true,
          onSelectTool: (_) {},
          onInkColorChanged: (c) => picked = c,
          onStrokeSizeChanged: (i) => size = i,
          onUndo: () => undone = true,
          onRedo: () => redone = true,
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Grosor'), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(undone, isTrue);

    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
    expect(redone, isTrue);

    await tester.tap(find.bySemanticsLabel('size 1'));
    await tester.pump();
    expect(size, 1);

    await tester.tap(find.bySemanticsLabel('color').first);
    await tester.pump();
    expect(picked, isNotNull);
  });

  testWidgets('muestra Guardar en PDF cuando hay anotaciones', (tester) async {
    var saved = false;

    await tester.pumpWidget(
      wrap(
        AnnotationToolbox(
          visible: true,
          activeTool: AnnotationTool.none,
          annotationCount: 2,
          canSave: true,
          onSelectTool: (_) {},
          onSave: () => saved = true,
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Guardar en PDF'), findsOneWidget);
    await tester.tap(find.text('Guardar en PDF'));
    await tester.pump();
    expect(saved, isTrue);
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
