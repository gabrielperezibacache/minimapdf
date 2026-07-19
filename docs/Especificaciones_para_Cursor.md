# **INSTRUCCIONES DE DESARROLLO: MINIMAL PDF (Hermes Obsidian)**

Este documento sirve como especificación técnica y de arquitectura (PRD/Prompt Guide) para que Cursor desarrolle la aplicación móvil **Minimal PDF** de manera incremental, limpia y optimizada.

## **1\. Visión del Producto y Filosofía**

* **Propósito:** Un lector de PDF y gestor de biblioteca ultraligero, rápido y 100% offline para Android e iOS.  
* **Modelo de Negocio:** Pago único ($1.99 USD) directo en tiendas. Sin compras in-app, sin suscripciones, sin anuncios.  
* **Filosofía Técnica:**  
  * **Cero IA:** No usar servicios de LLM ni procesamiento en la nube. Todo el procesamiento ocurre localmente.  
  * **Privacidad Absoluta:** No se recolectan datos del usuario ni documentos. Cero analíticas invasivas.  
  * **Rendimiento Extremo:** Carga instantánea de documentos grandes (\>500 páginas) con scroll suave a 60 FPS.  
  * **Estética Hermes:** Basado en el diseño técnico y de bajo cansancio visual de **Hermes Agent (Nous Skin)**.

## **2\. Stack Tecnológico Seleccionado**

Para garantizar un desarrollo ágil y multiplataforma con el máximo rendimiento local:

* **Framework:** **Flutter** (Dart) \- Permite control de UI de alto rendimiento.  
* **Motor PDF (Nativo):**  
  * Android: Pdfium (vía wrapper optimizado de Flutter).  
  * iOS: PDFKit (nativo de Apple, integrado en Flutter).  
  * Paquete recomendado: pdfx o flutter\_pdfview.  
* **Base de Datos Local:** Isar o Sqflite (Base de datos NoSQL/SQL local ultra rápida e integrada).  
* **Gestor de Descargas:** flutter\_downloader (descargas nativas en segundo plano).  
* **Navegador Interno (para descargas):** flutter\_inappwebview (ajustado para privacidad, bloqueando rastreadores).

## **3\. Arquitectura del Proyecto (Clean Architecture Simplificada)**

El proyecto debe seguir una estructura modular y limpia para facilitar su mantenimiento:

lib/  
├── core/                  \# Utilidades, constantes, temas y configuración global  
│   ├── theme/             \# Paleta de colores (Luz Pergamino, Sepia, Oscuro Hermes Obsidian)  
│   └── database/          \# Configuración de base de datos local  
├── data/                  \# Capa de datos (Modelos y Repositorios)  
│   ├── models/            \# PDFBook, Collection, Bookmark, DownloadTask  
│   └── datasources/       \# Acceso a base de datos e importación de archivos  
├── domain/                \# Lógica de negocio pura (Casos de uso opcionales o servicios directos)  
└── presentation/          \# Interfaz de usuario (Widgets, Pantallas y State Management)  
    ├── providers/         \# Control de estado ligero (Riverpod o Bloc recomendado, o ChangeNotifier sencillo)  
    ├── library/           \# Pantallas de la biblioteca (Grid, Carpetas, Edición de Metadatos)  
    ├── reader/            \# Pantallas del visor PDF (Scroll, Modos de color, Notas, Subrayados)  
    ├── signing/           \# Firma electrónica simple (dibujada) y mecanografiada  
    └── downloader/        \# Pantalla de descargas (Entrada de URL, mini-navegador, progreso)

## **4\. Esquema de Datos Local (Isar/SQLite)**

### **Objeto: Book (Libro/PDF)**

* id (int, autoincremental)  
* title (String) \- Nombre visualizable.  
* filePath (String) \- Ruta local absoluta del archivo PDF.  
* fileSize (int) \- Tamaño en bytes.  
* addedAt (DateTime) \- Fecha de importación.  
* lastReadAt (DateTime) \- Fecha de última apertura.  
* lastPageRead (int) \- Última página visitada.  
* author (String, nullable) \- Metadato editable.  
* tags (List) \- Etiquetas para filtrar.  
* collectionId (int, nullable) \- Carpeta/Colección a la que pertenece.

### **Objeto: Collection (Carpetas)**

* id (int, autoincremental)  
* name (String) \- Nombre de la colección.  
* createdAt (DateTime)

### **Objeto: Bookmark (Marcadores/Notas)**

* id (int, autoincremental)  
* bookId (int) \- Relación con el libro.  
* pageNumber (int) \- Página del marcador.  
* noteText (String, nullable) \- Nota opcional del usuario.  
* createdAt (DateTime)

## **5\. Plan de Implementación Paso a Paso (Instrucciones para el Prompt)**

*Usa estos pasos uno a uno en Cursor para guiar la generación de código:*

### **Paso 1: Configuración de Base y Tema Hermes Obsidian**

**Prompt para Cursor:** "Configura la estructura básica de un proyecto Flutter limpio. Implementa el gestor de estados (recomienda ChangeNotifier o Riverpod) y define tres temas visuales en core/theme/: Claro (Fondo cálido \#F4EEE7, texto \#121D18), Sepia, y Oscuro Hermes Obsidian (Fondo \#0F1714, paneles \#121D18/\#16211C, texto pergamino \#F3ECDD y acentos en oro bronce \#C89A5A). Agrega las dependencias de base de datos Isar o Sqflite en el pubspec.yaml."

### **Paso 2: Base de Datos y Modelos Locales**

**Prompt para Cursor:** "Crea los modelos locales de datos para Book, Collection y Bookmark basados en la especificación de metadatos. Implementa el servicio de base de datos en core/database/ con operaciones CRUD (crear, leer, actualizar, borrar) para libros y carpetas, optimizado para consultas ultra rápidas."

### **Paso 3: Interfaz de la Biblioteca (Gestor de Archivos)**

**Prompt para Cursor:** "Desarrolla la vista de Biblioteca (presentation/library/) utilizando la paleta Hermes Obsidian. Debe incluir: 1\) Una cuadrícula/lista técnica de PDFs recientes y colecciones, con bordes \#22342C de 1px. 2\) Un botón flotante para importar archivos de forma local (usando file\_picker para seleccionar PDFs del dispositivo). 3\) Una opción para editar metadatos del archivo (Título, Autor, Tags) de forma local."

### **Paso 4: El Lector de PDF de Alto Rendimiento**

**Prompt para Cursor:** "Implementa la pantalla del lector de PDF (presentation/reader/). Utiliza un paquete eficiente como pdfx para renderizado ultra rápido. Requisitos críticos:

1. Carga diferida de páginas.  
2. Implementar Scroll Continuo Vertical y modo Página a Página Horizontal.  
3. Soporte para invertir colores nativamente (Filtro Hermes Obsidian para las páginas del PDF: fondo verde oscuro \#0F1714 y letras en pergamino \#F3ECDD).  
4. Guardado automático del progreso de lectura (página actual) en la base de datos al cerrar o pausar la pantalla."

### **Paso 5: Anotaciones y Marcadores**

**Prompt para Cursor:** "Añade funciones de lectura activa al visor de PDF: 1\) Capacidad de marcar la página actual (Bookmarks) en color bronce \#C89A5A. 2\) Interfaz sencilla para añadir una nota de texto flotante en la página y guardarla en la base de datos local. 3\) Panel lateral deslizable (estilo sidebar de Hermes WebUI) para ver el índice (TOC) del PDF y el listado de marcadores guardados."

### **Paso 6: Gestor de Descargas y Mini-Navegador**

**Prompt para Cursor:** "Crea el módulo de descargas (presentation/downloader/). Implementa: 1\) Una barra de texto donde el usuario introduce una URL directa de un PDF para descargarlo en segundo plano (flutter\_downloader). 2\) Un navegador web interno y minimalista con un botón flotante 'Capturar PDF' que identifique si la página web actual tiene un enlace de descarga directa de PDF y lo descargue automáticamente a la biblioteca local."

### **Paso 7: Firma electrónica de documentos**

**Prompt para Cursor:** "Añade firma electrónica local offline en el lector: 1\) Firma electrónica simple dibujada (lienzo de trazo). 2\) Firma mecanografiada (nombre/rúbrica con teclado y vista previa). 3\) Persistencia en Sqflite asociada a libro+página, con nombre del firmante, motivo opcional y marca temporal. 4\) Overlay visual sobre la página y acción en la barra del lector. No integrar PKI ni servicios cloud."

## **6\. Directrices y Buenas Prácticas de Codificación para Cursor**

* **Nada de código "mock" o "hardcodeado" permanente:** Todo el código generado debe estar listo para integrarse con la base de datos o almacenamiento físico local del dispositivo.  
* **Manejo Estricto de Memoria:** Los controladores de los PDF, controladores de texto, WebViews y conexiones de bases de datos deben ser cerrados (dispose()) correctamente para evitar fugas de memoria (*memory leaks*), crucial para archivos grandes.  
* **Sin APIs de Terceros:** No integres llamadas a APIs externas de análisis, telemetría o servicios cloud, excepto las nativas del sistema operativo (guardado local).  
* **Tratamiento del PDF como binario local:** Al descargar o importar archivos, guárdalos en el directorio de documentos de la aplicación (getApplicationDocumentsDirectory) usando nombres de archivo sanitizados para evitar colisiones.