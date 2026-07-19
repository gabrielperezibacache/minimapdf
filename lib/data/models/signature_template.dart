import 'dart:convert';

import 'signature_role.dart';
import 'signature_type.dart';

/// Plantilla reutilizable de firma (mecanografiada o dibujada).
class SignatureTemplate {
  const SignatureTemplate({
    this.id,
    required this.name,
    required this.type,
    required this.signerName,
    this.typedText,
    this.inkJson,
    this.role = SignatureRole.signer,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final SignatureType type;
  final String signerName;
  final String? typedText;
  final String? inkJson;
  final SignatureRole role;
  final DateTime createdAt;

  String get displayText {
    final typed = typedText?.trim();
    if (typed != null && typed.isNotEmpty) return typed;
    return signerName;
  }

  List<List<List<double>>> get inkStrokes {
    final raw = inkJson;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map<List<List<double>>>((stroke) {
            if (stroke is! List) return <List<double>>[];
            final points = <List<double>>[];
            for (final point in stroke) {
              if (point is! List || point.length < 2) continue;
              if (point[0] is! num || point[1] is! num) continue;
              final x = (point[0] as num).toDouble();
              final y = (point[1] as num).toDouble();
              if (!x.isFinite || !y.isFinite) continue;
              points.add([x, y]);
            }
            return points;
          })
          .where((stroke) => stroke.length >= 2)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  SignatureTemplate copyWith({
    int? id,
    String? name,
    SignatureType? type,
    String? signerName,
    String? typedText,
    String? inkJson,
    SignatureRole? role,
    DateTime? createdAt,
  }) {
    return SignatureTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      signerName: signerName ?? this.signerName,
      typedText: typedText ?? this.typedText,
      inkJson: inkJson ?? this.inkJson,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.storageValue,
      'signer_name': signerName,
      'typed_text': typedText,
      'ink_json': inkJson,
      'role': role.storageValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SignatureTemplate.fromMap(Map<String, Object?> map) {
    return SignatureTemplate(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: SignatureTypeX.fromStorage(map['type'] as String),
      signerName: map['signer_name'] as String,
      typedText: map['typed_text'] as String?,
      inkJson: map['ink_json'] as String?,
      role: SignatureRoleX.fromStorage(map['role'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
