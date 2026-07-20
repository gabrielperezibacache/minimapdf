import 'package:flutter/foundation.dart';

import '../database/library_database.dart';
import 'app_preferences.dart';

/// Decide si mostrar la bienvenida en esta sesión.
///
/// Reglas:
/// - Si ya se vio / omitió → no mostrar.
/// - Si hay libros (upgrade de una instalación previa) → marcar vista y no mostrar.
/// - Primera apertura tras instalar → marcar vista de inmediato y mostrar **solo
///   esta sesión**, para que un cierre a medias no la repita al reabrir.
Future<bool> prepareWelcomeVisibility({
  required AppPreferences preferences,
  required LibraryDatabase libraryDatabase,
}) async {
  if (preferences.hasSeenWelcome) return false;

  try {
    if (await libraryDatabase.hasAnyBooks()) {
      await preferences.markWelcomeSeen();
      return false;
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('prepareWelcomeVisibility hasAnyBooks: $e');
    }
  }

  try {
    await preferences.markWelcomeSeen();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('prepareWelcomeVisibility markWelcomeSeen: $e');
    }
  }
  return true;
}
