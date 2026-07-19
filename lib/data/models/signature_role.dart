/// Rol del participante en una firma electrónica local.
enum SignatureRole {
  signer,
  reviewer,
  witness,
}

extension SignatureRoleX on SignatureRole {
  String get storageValue => name;

  String get labelEs {
    switch (this) {
      case SignatureRole.signer:
        return 'Firmante';
      case SignatureRole.reviewer:
        return 'Revisor';
      case SignatureRole.witness:
        return 'Testigo';
    }
  }

  static SignatureRole fromStorage(String? value) {
    return SignatureRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => SignatureRole.signer,
    );
  }
}
