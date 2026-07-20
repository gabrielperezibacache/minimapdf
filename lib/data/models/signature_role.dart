import '../../l10n/app_localizations.dart';

/// Rol del participante en una firma electrónica local.
enum SignatureRole {
  signer,
  reviewer,
  witness,
}

extension SignatureRoleX on SignatureRole {
  String get storageValue => name;

  /// Etiqueta localizada para UI.
  String label(AppLocalizations l10n) => switch (this) {
        SignatureRole.signer => l10n.signatureRoleSigner,
        SignatureRole.reviewer => l10n.signatureRoleReviewer,
        SignatureRole.witness => l10n.signatureRoleWitness,
      };

  /// Compatibilidad: español por defecto (manifiestos / overlays sin contexto).
  String get labelEs => switch (this) {
        SignatureRole.signer => 'Firmante',
        SignatureRole.reviewer => 'Revisor',
        SignatureRole.witness => 'Testigo',
      };

  static SignatureRole fromStorage(String? value) {
    return SignatureRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => SignatureRole.signer,
    );
  }
}
