import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Tipo de anotación sobre una página del PDF.
enum AnnotationType {
  highlight,
  underline,
  note,
  comment,
  annotation;

  String get label => switch (this) {
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

  factory PageAnnotation.fromMap(Map<String, Object?> map) {
    return PageAnnotation(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      pageNumber: map['page_number'] as int,
      type: AnnotationType.fromStorage(map['type'] as String),
      text: map['text'] as String?,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      colorValue: map['color_value'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
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
