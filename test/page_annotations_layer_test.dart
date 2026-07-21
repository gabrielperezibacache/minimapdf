import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart' show PhotoViewController;
import 'support/l10n_test_app.dart';
import 'package:minimal_pdf/core/theme/app_colors.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/data/models/page_annotation.dart';
import 'package:minimal_pdf/presentation/providers/reader_annotations_provider.dart';
import 'package:minimal_pdf/presentation/reader/widgets/page_annotations_layer.dart';

void main() {
  testWidgets('tap con Nota invoca onCreateRect', (tester) async {
    var created = false;
    var gotX = -1.0;
    var gotY = -1.0;
    AnnotationTool? gotTool;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.note,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                  gotTool = tool;
                  gotX = x;
                  gotY = y;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byType(PageAnnotationsLayer)));
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(gotTool, AnnotationTool.note);
    expect(gotX, closeTo(0.5 - 0.05, 0.08));
    expect(gotY, closeTo(0.5 - 0.0275, 0.08));
  });

  testWidgets('arrastre con Marcado guarda trazo libre', (tester) async {
    var created = false;
    var gotWidth = 0.0;
    List<List<List<double>>>? gotStrokes;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.highlight,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                  gotWidth = width;
                  gotStrokes = strokes;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PageAnnotationsLayer));
    await tester.timedDragFrom(
      center,
      const Offset(160, 8),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(gotWidth, greaterThan(0.25));
    expect(gotStrokes, isNotNull);
    expect(gotStrokes!, hasLength(1));
    expect(gotStrokes!.first.length, greaterThanOrEqualTo(2));
  });

  testWidgets('arrastre con Subrayado guarda trazo fino', (tester) async {
    var created = false;
    var gotWidth = 0.0;
    List<List<List<double>>>? gotStrokes;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.underline,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                  gotWidth = width;
                  gotStrokes = strokes;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PageAnnotationsLayer));
    await tester.timedDragFrom(
      center,
      const Offset(140, 6),
      const Duration(milliseconds: 280),
    );
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(gotWidth, greaterThan(0.2));
    expect(gotStrokes, isNotNull);
    expect(gotStrokes!.first.length, greaterThanOrEqualTo(2));
  });

  testWidgets('toque con Marcado no crea marca accidental', (tester) async {
    var created = false;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.highlight,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.byType(PageAnnotationsLayer)));
    await tester.pumpAndSettle();

    expect(created, isFalse);
  });

  testWidgets('stylus crea marcado al arrastrar', (tester) async {
    var created = false;
    var gotWidth = 0.0;
    AnnotationTool? gotTool;
    List<List<List<double>>>? gotStrokes;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.highlight,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                  gotTool = tool;
                  gotWidth = width;
                  gotStrokes = strokes;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final layer = find.byType(PageAnnotationsLayer);
    final start = tester.getCenter(layer) - const Offset(80, 0);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.stylus,
    );
    await gesture.moveBy(const Offset(180, 4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(gotTool, AnnotationTool.highlight);
    expect(gotWidth, greaterThan(0.3));
    expect(gotStrokes, isNotNull);
  });

  testWidgets('S-Pen gana frente a un toque de palma previo', (tester) async {
    var created = false;
    AnnotationTool? gotTool;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.underline,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                  gotTool = tool;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PageAnnotationsLayer));
    // Palma/dedo empieza un trazo corto.
    final palm = await tester.startGesture(
      center - const Offset(40, 0),
      kind: PointerDeviceKind.touch,
    );
    await palm.moveBy(const Offset(10, 0));
    // S-Pen toma el control.
    final stylus = await tester.startGesture(
      center - const Offset(60, 2),
      kind: PointerDeviceKind.stylus,
    );
    await stylus.moveBy(const Offset(160, 3));
    await stylus.up();
    await palm.up();
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(gotTool, AnnotationTool.underline);
  });

  testWidgets('un solo dedo crea marcado (sin necesitar dos dedos)',
      (tester) async {
    var created = false;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.highlight,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final start =
        tester.getCenter(find.byType(PageAnnotationsLayer)) - const Offset(90, 0);
    final finger = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 12; i++) {
      await finger.moveBy(const Offset(12, 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();

    expect(created, isTrue);
  });

  testWidgets(
      'candado abierto: un dedo dibuja (el scroll de página no se come el trazo)',
      (tester) async {
    var created = false;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: PageView(
              scrollDirection: Axis.vertical,
              // En la app real el scroll se bloquea con markup; aquí
              // comprobamos que el recognizer gana igual con candado abierto.
              children: [
                PageAnnotationsLayer(
                  annotations: const [],
                  activeTool: AnnotationTool.highlight,
                  enabled: true,
                  navigationLocked: false,
                  onCreateRect: ({
                    required tool,
                    required x,
                    required y,
                    required width,
                    required height,
                    strokes,
                  }) async {
                    created = true;
                  },
                  onOpenAnnotation: (_) {},
                  onDeleteAnnotation: (_) {},
                ),
                const SizedBox.expand(),
              ],
            ),
          ),
        ),
      ),
    );

    final start =
        tester.getCenter(find.byType(PageAnnotationsLayer)) - const Offset(90, 0);
    final finger = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    // Primer contacto: movimiento inmediato (sin esperar un 2º dedo).
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(const Offset(14, 1));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();

    expect(created, isTrue);
  });

  testWidgets(
      'candado abierto: dos dedos hacen zoom (cambia la escala del controller)',
      (tester) async {
    var created = false;
    final zoom = PhotoViewController(initialScale: 1.0);
    addTearDown(zoom.dispose);

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.highlight,
                enabled: true,
                navigationLocked: false,
                zoomController: zoom,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  created = true;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PageAnnotationsLayer));
    // Dos dedos separándose = zoom in.
    final f1 = await tester.startGesture(
      center - const Offset(20, 0),
      kind: PointerDeviceKind.touch,
    );
    final f2 = await tester.startGesture(
      center + const Offset(20, 0),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 8; i++) {
      await f1.moveBy(const Offset(-10, 0));
      await f2.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await f1.up();
    await f2.up();
    await tester.pumpAndSettle();

    expect(zoom.scale, greaterThan(1.0));
    // El zoom con dos dedos no debe crear una marca.
    expect(created, isFalse);
  });

  testWidgets(
      'varios movimientos con un dedo siguen creando marcado (no intermitente)',
      (tester) async {
    var createdCount = 0;

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: const [],
                activeTool: AnnotationTool.underline,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {
                  createdCount++;
                },
                onOpenAnnotation: (_) {},
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PageAnnotationsLayer));
    for (var stroke = 0; stroke < 4; stroke++) {
      final start = center + Offset(-100.0, -40.0 + stroke * 24.0);
      final finger = await tester.startGesture(
        start,
        kind: PointerDeviceKind.touch,
      );
      for (var i = 0; i < 10; i++) {
        await finger.moveBy(const Offset(14, 0));
        await tester.pump(const Duration(milliseconds: 12));
      }
      await finger.up();
      await tester.pumpAndSettle();
    }

    expect(createdCount, 4);
  });

  testWidgets('muestra anotación existente y permite abrirla', (tester) async {
    var opened = false;
    final annotation = PageAnnotation(
      id: 1,
      bookId: 1,
      pageNumber: 1,
      type: AnnotationType.comment,
      text: 'Hola',
      x: 0.4,
      y: 0.4,
      width: 0.2,
      height: 0.1,
      colorValue: AppColors.ebonyAccent.toARGB32(),
      createdAt: DateTime(2026, 7, 19),
    );

    await tester.pumpWidget(
      l10nTestApp(
        theme: AppTheme.ebony,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: PageAnnotationsLayer(
                annotations: [annotation],
                activeTool: AnnotationTool.none,
                enabled: true,
                onCreateRect: ({
                  required tool,
                  required x,
                  required y,
                  required width,
                  required height,
                  strokes,
                }) async {},
                onOpenAnnotation: (_) => opened = true,
                onDeleteAnnotation: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });
}
