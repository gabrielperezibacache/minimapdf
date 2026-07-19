import 'package:flutter/material.dart';

/// Paletas Minimal PDF: Claro (Pergamino), Sepia y Oscuro (Ébano).
abstract final class AppColors {
  // --- Claro (Luz Pergamino) ---
  static const Color lightBackground = Color(0xFFF4EEE7);
  static const Color lightSurface = Color(0xFFEDE6DC);
  static const Color lightPanel = Color(0xFFE8E0D4);
  static const Color lightText = Color(0xFF121D18);
  static const Color lightTextMuted = Color(0xFF3D4A44);
  static const Color lightBorder = Color(0xFFC9BFAF);
  static const Color lightAccent = Color(0xFF8B6914);

  // --- Sepia ---
  static const Color sepiaBackground = Color(0xFFE8D9C0);
  static const Color sepiaSurface = Color(0xFFDFCDB0);
  static const Color sepiaPanel = Color(0xFFD4C09E);
  static const Color sepiaText = Color(0xFF3B2F22);
  static const Color sepiaTextMuted = Color(0xFF5C4A38);
  static const Color sepiaBorder = Color(0xFFB8A07A);
  static const Color sepiaAccent = Color(0xFFA67C3D);

  // --- Oscuro Ébano ---
  static const Color ebonyBackground = Color(0xFF0F1714);
  static const Color ebonyPanel = Color(0xFF121D18);
  static const Color ebonySurface = Color(0xFF16211C);
  static const Color ebonyText = Color(0xFFF3ECDD);
  static const Color ebonyTextMuted = Color(0xFFB8B09E);
  static const Color ebonyBorder = Color(0xFF22342C);
  static const Color ebonyAccent = Color(0xFFC89A5A);
}
