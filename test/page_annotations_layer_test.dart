import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.obsidian,
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
                  required x,
                  required y,
                  required width,
                  required height,
                }) async {
                  created = true;
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
    expect(gotX, closeTo(0.5 - 0.05, 0.08));
    expect(gotY, closeTo(0.5 - 0.0275, 0.08));
  });

  testWidgets('arrastre con Marcado invoca onCreateRect', (tester) async {
    var created = false;
    var gotWidth = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.obsidian,
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
                  required x,
                  required y,
                  required width,
                  required height,
                }) async {
                  created = true;
                  gotWidth = width;
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
      const Offset(160, 48),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(gotWidth, greaterThan(0.25));
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
      colorValue: AppColors.obsidianAccent.toARGB32(),
      createdAt: DateTime(2026, 7, 19),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.obsidian,
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
                  required x,
                  required y,
                  required width,
                  required height,
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
