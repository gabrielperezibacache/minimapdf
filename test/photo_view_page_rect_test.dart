import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';

import 'package:minimal_pdf/presentation/reader/photo_view_page_rect.dart';

void main() {
  test('page rect centrado sin pan coincide con escala contenida', () {
    const viewport = Size(400, 800);
    const page = Size(200, 400);
    const scale = 2.0; // contained: min(400/200, 800/400)=2

    final rect = photoViewPageRectInViewport(
      viewportSize: viewport,
      pageSize: page,
      controllerValue: const PhotoViewControllerValue(
        position: Offset.zero,
        scale: scale,
        rotation: 0,
        rotationFocusPoint: null,
      ),
    );

    expect(rect.left, 0);
    expect(rect.top, 0);
    expect(rect.width, 400);
    expect(rect.height, 800);
  });

  test('viewportPointToPageLocal proyecta márgenes al borde de la página', () {
    const pageRect = Rect.fromLTWH(100, 0, 200, 400);

    expect(
      viewportPointToPageLocal(const Offset(20, 200), pageRect),
      const Offset(0, 200),
    );
    expect(
      viewportPointToPageLocal(const Offset(350, 500), pageRect),
      const Offset(200, 400),
    );
    expect(
      viewportPointToPageLocal(const Offset(150, 100), pageRect),
      const Offset(50, 100),
    );
  });
}
