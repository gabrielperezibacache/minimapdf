import 'package:flutter/material.dart';

/// Radios de la app: técnico, de bajo radio (sin pastillas).
abstract final class AppRadii {
  static const double none = 0;
  static const double sm = 4;
  static const double md = 8;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sm),
  );
}
