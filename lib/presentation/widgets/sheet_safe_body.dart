import 'package:flutter/material.dart';

/// Cuerpo de un [showModalBottomSheet] que evita la barra de navegación
/// del sistema y deja hueco para el teclado.
///
/// Flutter aplica `SafeArea(bottom: false)` en los sheets aunque
/// `useSafeArea: true`, así que el padding inferior hay que hacerlo aquí.
class SheetSafeBody extends StatelessWidget {
  const SheetSafeBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          padding.left,
          padding.top,
          padding.right,
          padding.bottom + keyboard,
        ),
        child: child,
      ),
    );
  }
}
