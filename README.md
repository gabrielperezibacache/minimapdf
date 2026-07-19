# Minimal PDF

Lector de PDF y gestor de biblioteca ultraligero, rápido y 100% offline para Android e iOS.

Estética **Hermes Obsidian** · Pago único · Sin IA · Sin analíticas · Privacidad absoluta.

## Documentación

- [Especificaciones técnicas](docs/Especificaciones_para_Cursor.md) — PRD, arquitectura y plan paso a paso.

## Stack

- **Flutter** (Dart)
- **Estado:** Provider + ChangeNotifier
- **Base de datos local:** Sqflite (+ path / path_provider)
- **Temas:** Claro (Pergamino), Sepia, Oscuro Hermes Obsidian

## Estructura

```
lib/
├── core/           # Temas, DB config, constantes
├── data/           # Modelos y datasources (Paso 2+)
├── domain/         # Lógica de negocio
└── presentation/   # UI, providers, library / reader / downloader
```

## Desarrollo

```bash
flutter pub get
flutter test
flutter run
```

## Plan de implementación

1. ✅ Base + temas Hermes Obsidian + dependencias
2. ✅ Base de datos y modelos locales (Book, Collection, Bookmark + CRUD Sqflite)
3. Interfaz de biblioteca
4. Lector PDF de alto rendimiento
5. Anotaciones y marcadores
6. Gestor de descargas y mini-navegador
