# Minimal PDF

Lector de PDF y gestor de biblioteca ultraligero, rápido y 100% offline para Android e iOS.

Estética **Ébano** · Pago único · Sin IA · Sin analíticas · Privacidad absoluta.

## Documentación

- [Especificaciones técnicas](docs/Especificaciones_para_Cursor.md) — PRD, arquitectura y plan paso a paso.

## Stack

- **Flutter** (Dart)
- **Estado:** Provider + ChangeNotifier
- **Base de datos local:** Sqflite (+ path / path_provider)
- **Importación:** file_picker → copia a documentos de la app
- **Lector:** pdfx (carga diferida de páginas)
- **Descargas:** flutter_downloader + HTTP fallback; mini-navegador flutter_inappwebview
- **Temas:** Claro (Pergamino), Sepia, Oscuro Ébano

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

1. ✅ Base + temas Ébano + dependencias
2. ✅ Base de datos y modelos locales (Book, Collection, Bookmark + CRUD Sqflite)
3. ✅ Interfaz de biblioteca (grid/lista, importación file_picker, metadatos)
4. ✅ Lector PDF (pdfx, scroll vertical/horizontal, filtro Ébano, progreso)
5. ✅ Anotaciones y marcadores (bronce, notas flotantes, sidebar TOC)
6. ✅ Descargas por URL + mini-navegador con Capturar PDF
