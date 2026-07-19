import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Filtro de color para páginas PDF en modo Hermes Obsidian.
///
/// Remapea tinta negra → pergamino `#F3ECDD` y fondo blanco → `#0F1714`.
abstract final class HermesPdfFilter {
  static const Color background = AppColors.obsidianBackground;
  static const Color text = AppColors.obsidianText;

  /// Matriz: `out = a * in + b` por canal (entrada tipográfica B/N).
  static const List<double> obsidianMatrix = <double>[
    -0.8941176470588236, 0, 0, 0, 243, // R: 0→F3, 255→0F
    0, -0.8352941176470589, 0, 0, 236, // G: 0→EC, 255→17
    0, 0, -0.788235294117647, 0, 221, // B: 0→DD, 255→14
    0, 0, 0, 1, 0,
  ];

  static const ColorFilter obsidian = ColorFilter.matrix(obsidianMatrix);

  /// Aplica el filtro Obsidian si [enabled] es true.
  static Widget wrap({required bool enabled, required Widget child}) {
    if (!enabled) return child;
    return ColorFiltered(colorFilter: obsidian, child: child);
  }
}
