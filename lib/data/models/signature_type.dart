/// Modo de firma electrónica local (SES simple, sin PKI).
enum SignatureType {
  /// Trazo manuscrito / dibujado (firma electrónica simple).
  drawn,

  /// Nombre o rúbrica escrita con teclado (firma mecanografiada).
  typed,
}

extension SignatureTypeX on SignatureType {
  String get storageValue => name;

  String get labelEs {
    switch (this) {
      case SignatureType.drawn:
        return 'Firma dibujada';
      case SignatureType.typed:
        return 'Firma mecanografiada';
    }
  }

  static SignatureType fromStorage(String value) {
    return SignatureType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => SignatureType.typed,
    );
  }
}
