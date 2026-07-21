# Releases

## Android

| Archivo | Formato | Versión | applicationId |
|---------|---------|---------|---------------|
| `minimalpdf-1.0.0+7-testing.apk` | APK (testing / instalación directa) | 1.0.0 (code 7) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+6-testing.apk` | APK (testing / instalación directa) | 1.0.0 (code 6) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+5-testing.apk` | APK (testing / instalación directa) | 1.0.0 (code 5) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+4-testing.apk` | APK (testing / instalación directa) | 1.0.0 (code 4) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+2-release.aab` | App Bundle (Play) | 1.0.0 (code 2) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+2-testing.apk` | APK (testing / instalación directa) | 1.0.0 (code 2) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+1-release.aab` | App Bundle (Play) | 1.0.0 (code 1) | `apps.perezibacache.minimalpdf` |
| `minimalpdf-1.0.0+1-release.apk` | APK (instalación directa) | 1.0.0 (code 1) | `apps.perezibacache.minimalpdf` |

- **AAB:** subir a Google Play Console.
- **APK:** instalación lateral / pruebas en dispositivo.

El keystore de firma **no** está en este repositorio. Conserva `upload-keystore.jks` y sus credenciales en un lugar privado seguro.

> **Nota (1.0.0+2):** el keystore de upload se regeneró en este entorno (el anterior era efímero).
> Si ya registraste la clave anterior en Play Console, usa esa clave original para firmar;
> si aún no subiste ningún AAB firmado, usa la nueva clave guardada fuera del repo.
