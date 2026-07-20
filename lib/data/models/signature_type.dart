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
