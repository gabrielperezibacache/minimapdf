import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Tipo de anotación sobre una página del PDF.
enum AnnotationType {
  highlight,
  underline,
  note,
  comment,
  annotation;

  String label(AppLocalizations l10n) => switch (this) {
        AnnotationType.highlight => l10n.annotationHighlight,
        AnnotationType.underline => l10n.annotationUnderline,
        AnnotationType.note => l10n.annotationNote,
        AnnotationType.comment => l10n.annotationComment,
        AnnotationType.annotation => l10n.annotationGeneric,
      };

  /// Español por defecto (semántica / capas sin BuildContext).
  String get labelEs => switch (this) {
        AnnotationType.highlight => 'Marcado',
        AnnotationType.underline => 'Subrayado',
        AnnotationType.note => 'Nota',
        AnnotationType.comment => 'Comentario',
        AnnotationType.annotation => 'Anotación',
      };

  String get storageValue => name;

  static AnnotationType fromStorage(String value) {
    return AnnotationType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AnnotationType.annotation,
    );
  }

  IconData get icon => switch (this) {
        AnnotationType.highlight => Icons.highlight,
        AnnotationType.underline => Icons.format_underline,
        AnnotationType.note => Icons.sticky_note_2_outlined,
        AnnotationType.comment => Icons.chat_bubble_outline,
        AnnotationType.annotation => Icons.edit_note,
      };

  bool get isMarkup =>
      this == AnnotationType.highlight || this == AnnotationType.underline;

  bool get needsText =>
      this == AnnotationType.note ||
      this == AnnotationType.comment ||
      this == AnnotationType.annotation;

  /// Color de acento bronce Ébano para cada herramienta.
  Color get defaultColor => switch (this) {
        AnnotationType.highlight => const Color(0x99C89A5A),
        AnnotationType.underline => AppColors.ebonyAccent,
        AnnotationType.note => AppColors.ebonyAccent,
        AnnotationType.comment => const Color(0xFFD4B483),
        AnnotationType.annotation => AppColors.ebonyAccent,
      };
}

/// Anotación espacial (marcado, subrayado, nota, comentario) en una página.
class PageAnnotation {
  const PageAnnotation({
    this.id,
    required this.bookId,
    required this.pageNumber,
    required this.type,
    this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.colorValue,
    required this.createdAt,
  });

  final int? id;
  final int bookId;
  final int pageNumber;
  final AnnotationType type;
  final String? text;

  /// Coordenadas normalizadas (0–1) respecto al área visible de la página.
  final double x;
  final double y;
  final double width;
  final double height;
  final int colorValue;
  final DateTime createdAt;

  Color get color => Color(colorValue);

  bool get hasText => text != null && text!.trim().isNotEmpty;

  PageAnnotation copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    AnnotationType? type,
    String? text,
    double? x,
    double? y,
    double? width,
    double? height,
    int? colorValue,
    DateTime? createdAt,
    bool clearText = false,
  }) {
    return PageAnnotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      type: type ?? this.type,
      text: clearText ? null : (text ?? this.text),
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'page_number': pageNumber,
      'type': type.storageValue,
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color_value': colorValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Parseo estricto; lanza si faltan campos obligatorios.
  factory PageAnnotation.fromMap(Map<String, Object?> map) {
    final annotation = PageAnnotation.tryFromMap(map);
    if (annotation == null) {
      throw FormatException('Fila de anotación inválida o corrupta');
    }
    return annotation;
  }

  /// Parseo tolerante: filas corruptas → null (no tumba la carga del lector).
  static PageAnnotation? tryFromMap(Map<String, Object?> map) {
    try {
      final bookId = _asInt(map['book_id']);
      final pageNumber = _asInt(map['page_number']);
      final typeRaw = map['type'];
      final createdAt = _asDateTime(map['created_at']);
      final x = _asDouble(map['x']);
      final y = _asDouble(map['y']);
      final width = _asDouble(map['width']);
      final height = _asDouble(map['height']);
      final colorValue = _asInt(map['color_value']);

      if (bookId == null ||
          pageNumber == null ||
          pageNumber < 1 ||
          typeRaw is! String ||
          typeRaw.isEmpty ||
          createdAt == null ||
          x == null ||
          y == null ||
          width == null ||
          height == null ||
          colorValue == null) {
        return null;
      }

      return PageAnnotation(
        id: _asInt(map['id']),
        bookId: bookId,
        pageNumber: pageNumber,
        type: AnnotationType.fromStorage(typeRaw),
        text: _asNullableString(map['text']),
        x: x,
        y: y,
        width: width,
        height: height,
        colorValue: colorValue,
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    final parsed = value is double
        ? value
        : value is num
            ? value.toDouble()
            : double.tryParse(value.toString());
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  static String? _asNullableString(Object? value) {
    if (value == null) return null;
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  @override
  bool operator ==(Object other) {
    return other is PageAnnotation &&
        other.id == id &&
        other.bookId == bookId &&
        other.pageNumber == pageNumber &&
        other.type == type &&
        other.text == text &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.colorValue == colorValue &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        bookId,
        pageNumber,
        type,
        text,
        x,
        y,
        width,
        height,
        colorValue,
        createdAt,
      );
}
