import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Drag vertical que gana la arena de gestos al primer [PointerDown].
///
/// Evita que el [PageView]/[PhotoView] “se coma” el primer toque cuando hay
/// una herramienta de dibujo o selección de texto armada.
class EagerVerticalDragGestureRecognizer extends VerticalDragGestureRecognizer {
  EagerVerticalDragGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'eager vertical drag';
}

/// Drag horizontal equivalente (modo páginas / pan residual).
class EagerHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  EagerHorizontalDragGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'eager horizontal drag';
}

/// Mapa de recognizers eager para envolver superficies de captura.
Map<Type, GestureRecognizerFactory> eagerCaptureGestures({
  Object? debugOwner,
}) {
  return <Type, GestureRecognizerFactory>{
    EagerVerticalDragGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<EagerVerticalDragGestureRecognizer>(
      () => EagerVerticalDragGestureRecognizer(debugOwner: debugOwner),
      (instance) {
        // No-op: solo existen para ganar la arena frente al PageView.
        instance.onStart = (_) {};
        instance.onUpdate = (_) {};
        instance.onEnd = (_) {};
      },
    ),
    EagerHorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
        EagerHorizontalDragGestureRecognizer>(
      () => EagerHorizontalDragGestureRecognizer(debugOwner: debugOwner),
      (instance) {
        instance.onStart = (_) {};
        instance.onUpdate = (_) {};
        instance.onEnd = (_) {};
      },
    ),
  };
}
