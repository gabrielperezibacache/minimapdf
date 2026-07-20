import '../../l10n/app_localizations.dart';

/// Modo de firma electrónica local (SES simple, sin PKI).
enum SignatureType {
  /// Trazo manuscrito / dibujado (firma electrónica simple).
  drawn,

  /// Nombre o rúbrica escrita con teclado (firma mecanografiada).
  typed,
}

extension SignatureTypeX on SignatureType {
  String get storageValue => name;

  String label(AppLocalizations l10n) => switch (this) {
        SignatureType.drawn => l10n.signatureTypeDrawn,
        SignatureType.typed => l10n.signatureTypeTyped,
      };

  /// Compatibilidad: español por defecto.
  String get labelEs => switch (this) {
        SignatureType.drawn => 'Firma dibujada',
        SignatureType.typed => 'Firma mecanografiada',
      };

  /// Devuelve null si el valor no es un tipo conocido (fila corrupta).
  static SignatureType? tryFromStorage(String value) {
    for (final type in SignatureType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  static SignatureType fromStorage(String value) {
    return tryFromStorage(value) ?? SignatureType.typed;
  }
}
