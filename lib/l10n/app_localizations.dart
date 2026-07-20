import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_locale.dart';
import 'app_message_keys.dart';

/// Cadenas de UI localizadas (es / en / pt / fr / de / zh / ru).
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations no está registrado en el árbol');
    return value!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('es'),
    Locale('en'),
    Locale('pt'),
    Locale('fr'),
    Locale('de'),
    Locale('zh'),
    Locale('ru'),
  ];

  String get _code {
    final code = locale.languageCode;
    if (_strings.containsKey(code)) return code;
    return AppLocale.es.code;
  }

  String _t(String key) =>
      _strings[_code]![key] ?? _strings[AppLocale.es.code]![key] ?? key;

  // —— Común ——
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get create => _t('create');
  String get delete => _t('delete');
  String get close => _t('close');
  String get options => _t('options');
  String get settings => _t('settings');
  String get language => _t('language');
  String get theme => _t('theme');
  String get appearance => _t('appearance');

  // —— Temas ——
  String get themeLight => _t('themeLight');
  String get themeSepia => _t('themeSepia');
  String get themeEbony => _t('themeEbony');

  // —— Biblioteca ——
  String get library => _t('library');
  String get librarySubtitle => _t('librarySubtitle');
  String get importPdf => _t('importPdf');
  String get downloadsBrowser => _t('downloadsBrowser');
  String get viewList => _t('viewList');
  String get viewGrid => _t('viewGrid');
  String get allCollections => _t('allCollections');
  String get newCollectionShort => _t('newCollectionShort');
  String get newCollection => _t('newCollection');
  String get collectionName => _t('collectionName');
  String get emptyLibrary => _t('emptyLibrary');
  String get emptyLibraryHint => _t('emptyLibraryHint');
  String get emptyCollection => _t('emptyCollection');
  String get emptyCollectionHint => _t('emptyCollectionHint');
  String get deletePdf => _t('deletePdf');
  String deletePdfConfirm(String title) =>
      _t('deletePdfConfirm').replaceAll('{title}', title);
  String imported(String title) => _t('imported').replaceAll('{title}', title);
  String get editMetadata => _t('editMetadata');
  String get titleLabel => _t('titleLabel');
  String get authorLabel => _t('authorLabel');
  String get tagsLabel => _t('tagsLabel');
  String get tagsHint => _t('tagsHint');
  String pageAbbrev(int page) =>
      _t('pageAbbrev').replaceAll('{page}', '$page');
  String get errorLibraryLoad => _t('errorLibraryLoad');
  String get errorImportPdf => _t('errorImportPdf');
  String get searchHint => _t('searchHint');
  String get clearSearch => _t('clearSearch');
  String get fileNotFound => _t('fileNotFound');
  String fileNotFoundBody(String title) =>
      _t('fileNotFoundBody').replaceAll('{title}', title);
  String get removeFromLibrary => _t('removeFromLibrary');
  String get rename => _t('rename');
  String get renameCollection => _t('renameCollection');
  String get deleteCollection => _t('deleteCollection');
  String deleteCollectionConfirm(String name) =>
      _t('deleteCollectionConfirm').replaceAll('{name}', name);
  String get noSearchResults => _t('noSearchResults');
  String get noSearchResultsHint => _t('noSearchResultsHint');
  String get retry => _t('retry');
  String get noCollection => _t('noCollection');
  String get collectionLabel => _t('collectionLabel');
  String get importing => _t('importing');
  String get errorMetadataSave => _t('errorMetadataSave');
  String get errorCollectionCreate => _t('errorCollectionCreate');
  String get errorCollectionRename => _t('errorCollectionRename');
  String get errorCollectionDelete => _t('errorCollectionDelete');
  String get errorCollectionNameExists => _t('errorCollectionNameExists');
  String get errorDeletePdf => _t('errorDeletePdf');
  String get errorTimeout => _t('errorTimeout');
  String get errorNoNetwork => _t('errorNoNetwork');
  String get errorConnectionFailed => _t('errorConnectionFailed');
  String get errorDownloadInProgress => _t('errorDownloadInProgress');
  String get errorNativeDownloadFailed => _t('errorNativeDownloadFailed');
  String get downloadCancelled => _t('downloadCancelled');
  String multiplePdfsDetected(int count) =>
      _t('multiplePdfsDetected').replaceAll('{count}', '$count');

  // —— Lector ——
  String get showControls => _t('showControls');
  String get hideControls => _t('hideControls');
  String get menuToc => _t('menuToc');
  String get back => _t('back');
  String get addBookmark => _t('addBookmark');
  String get removeBookmark => _t('removeBookmark');
  String get addNote => _t('addNote');
  String get filterEbonyOn => _t('filterEbonyOn');
  String get filterEbonyOff => _t('filterEbonyOff');
  String scrollModeTooltip(String mode) =>
      _t('scrollModeTooltip').replaceAll('{mode}', mode);
  String get scrollVertical => _t('scrollVertical');
  String get scrollPaged => _t('scrollPaged');
  String get pageLoadError => _t('pageLoadError');
  String openPdfError(String detail) =>
      _t('openPdfError').replaceAll('{error}', detail);
  String get navigation => _t('navigation');
  String get tocTab => _t('tocTab');
  String get bookmarksTab => _t('bookmarksTab');
  String get goToPage => _t('goToPage');
  String get go => _t('go');
  String get pageIndex => _t('pageIndex');
  String pageNumber(int page) =>
      _t('pageNumber').replaceAll('{page}', '$page');
  String get noBookmarks => _t('noBookmarks');
  String notePage(int page) => _t('notePage').replaceAll('{page}', '$page');
  String notePageAbbrev(int page) =>
      _t('notePageAbbrev').replaceAll('{page}', '$page');
  String get noteHint => _t('noteHint');

  // —— Descargas ——
  String get downloads => _t('downloads');
  String get capturePdf => _t('capturePdf');
  String capturePdfCount(int count) =>
      _t('capturePdfCount').replaceAll('{count}', '$count');
  String get directPdfUrl => _t('directPdfUrl');
  String get download => _t('download');
  String get urlHint => _t('urlHint');
  String get browserUnavailable => _t('browserUnavailable');
  String get browserBack => _t('browserBack');
  String get browserForward => _t('browserForward');
  String get browserReload => _t('browserReload');
  String get browserUrlHint => _t('browserUrlHint');
  String get privateBrowser => _t('privateBrowser');
  String pdfLinksDetected(int count) =>
      _t('pdfLinksDetected').replaceAll('{count}', '$count');
  String downloaded(String title) =>
      _t('downloaded').replaceAll('{title}', title);
  String get errorInvalidUrl => _t('errorInvalidUrl');
  String get downloading => _t('downloading');
  String savedToLibrary(String title) =>
      _t('savedToLibrary').replaceAll('{title}', title);
  String get errorDownloadPdf => _t('errorDownloadPdf');
  String get errorNoPdfLink => _t('errorNoPdfLink');

  // —— Ajustes ——
  String get settingsSubtitle => _t('settingsSubtitle');
  String get languageSubtitle => _t('languageSubtitle');
  String get defaultPdfReader => _t('defaultPdfReader');
  String get defaultPdfReaderSubtitle => _t('defaultPdfReaderSubtitle');
  String get defaultPdfReaderOpenSettings => _t('defaultPdfReaderOpenSettings');
  String get defaultPdfReaderHint => _t('defaultPdfReaderHint');
  String get defaultPdfReaderOpenFailed => _t('defaultPdfReaderOpenFailed');

  /// Resuelve mensajes emitidos por providers.
  String message(String key, {String? arg}) {
    return switch (key) {
      AppMessageKeys.libraryLoadFailed => errorLibraryLoad,
      AppMessageKeys.importPdfFailed => errorImportPdf,
      AppMessageKeys.metadataSaveFailed => errorMetadataSave,
      AppMessageKeys.collectionCreateFailed => errorCollectionCreate,
      AppMessageKeys.collectionRenameFailed => errorCollectionRename,
      AppMessageKeys.collectionDeleteFailed => errorCollectionDelete,
      AppMessageKeys.collectionNameExists => errorCollectionNameExists,
      AppMessageKeys.deletePdfFailed => errorDeletePdf,
      AppMessageKeys.invalidUrl => errorInvalidUrl,
      AppMessageKeys.downloading => downloading,
      AppMessageKeys.savedToLibrary => savedToLibrary(arg ?? ''),
      AppMessageKeys.downloadFailed => errorDownloadPdf,
      AppMessageKeys.noPdfLink => errorNoPdfLink,
      AppMessageKeys.timeout => errorTimeout,
      AppMessageKeys.noNetwork => errorNoNetwork,
      AppMessageKeys.connectionFailed => errorConnectionFailed,
      AppMessageKeys.downloadInProgress => errorDownloadInProgress,
      AppMessageKeys.nativeDownloadFailed => errorNativeDownloadFailed,
      AppMessageKeys.downloadCancelled => downloadCancelled,
      AppMessageKeys.multiplePdfsDetected =>
        multiplePdfsDetected(int.tryParse(arg ?? '') ?? 0),
      _ => key,
    };
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, Map<String, String>> _strings = {
  'es': {
    'cancel': 'Cancelar',
    'save': 'Guardar',
    'create': 'Crear',
    'delete': 'Eliminar',
    'close': 'Cerrar',
    'options': 'Opciones',
    'settings': 'Configuración',
    'language': 'Idioma',
    'theme': 'Tema',
    'appearance': 'Apariencia',
    'themeLight': 'Claro',
    'themeSepia': 'Sepia',
    'themeEbony': 'Ébano',
    'library': 'Biblioteca',
    'librarySubtitle': 'PDFs recientes y colecciones · 100% offline',
    'importPdf': 'Importar PDF',
    'downloadsBrowser': 'Descargas / navegador',
    'viewList': 'Vista lista',
    'viewGrid': 'Vista cuadrícula',
    'allCollections': 'Todos',
    'newCollectionShort': 'Nueva',
    'newCollection': 'Nueva colección',
    'collectionName': 'Nombre',
    'emptyLibrary': 'Tu biblioteca está vacía',
    'emptyLibraryHint': 'Pulsa + para importar un PDF del dispositivo.',
    'emptyCollection': 'No hay PDFs en esta colección',
    'emptyCollectionHint': 'Importa un PDF o elige otra carpeta.',
    'deletePdf': 'Eliminar PDF',
    'deletePdfConfirm': '¿Eliminar “{title}” de la biblioteca?',
    'imported': 'Importado: {title}',
    'editMetadata': 'Editar metadatos',
    'titleLabel': 'Título',
    'authorLabel': 'Autor',
    'tagsLabel': 'Tags',
    'tagsHint': 'separados por coma',
    'pageAbbrev': 'p. {page}',
    'errorLibraryLoad': 'No se pudo cargar la biblioteca.',
    'errorImportPdf': 'No se pudo importar el PDF.',
    'showControls': 'Mostrar controles',
    'hideControls': 'Ocultar controles',
    'menuToc': 'Menú / índice',
    'back': 'Volver',
    'addBookmark': 'Marcar página',
    'removeBookmark': 'Quitar marcador',
    'addNote': 'Añadir nota',
    'filterEbonyOn': 'Filtro Ébano',
    'filterEbonyOff': 'Desactivar filtro Ébano',
    'scrollModeTooltip': 'Modo: {mode}',
    'scrollVertical': 'Vertical',
    'scrollPaged': 'Páginas',
    'pageLoadError': 'Error al cargar la página',
    'openPdfError': 'No se pudo abrir el PDF.\n{error}',
    'navigation': 'Navegación',
    'tocTab': 'Índice',
    'bookmarksTab': 'Marcadores',
    'goToPage': 'Ir a página',
    'go': 'Ir',
    'pageIndex': 'Índice de páginas',
    'pageNumber': 'Página {page}',
    'noBookmarks':
        'Sin marcadores.\nMarca la página actual con el icono bronce.',
    'notePage': 'Nota · página {page}',
    'notePageAbbrev': 'Nota · p. {page}',
    'noteHint': 'Escribe una nota…',
    'downloads': 'Descargas',
    'capturePdf': 'Capturar PDF',
    'capturePdfCount': 'Capturar PDF ({count})',
    'directPdfUrl': 'URL directa de PDF',
    'download': 'Descargar',
    'urlHint': 'https://ejemplo.com/archivo.pdf',
    'browserUnavailable':
        'El mini-navegador está disponible en Android e iOS.\nEn escritorio puedes usar la URL directa de arriba.',
    'browserBack': 'Atrás',
    'browserForward': 'Adelante',
    'browserReload': 'Recargar',
    'browserUrlHint': 'Buscar o abrir URL',
    'privateBrowser': 'Mini-navegador privado · sin telemetría',
    'pdfLinksDetected': '{count} enlace(s) PDF detectado(s)',
    'downloaded': 'Descargado: {title}',
    'errorInvalidUrl': 'Introduce una URL http(s) válida.',
    'downloading': 'Descargando…',
    'savedToLibrary': 'Guardado en biblioteca: {title}',
    'errorDownloadPdf': 'No se pudo descargar el PDF.',
    'errorNoPdfLink': 'No se encontró un enlace PDF en esta página.',
    'settingsSubtitle': 'Idioma, apariencia y lector PDF por defecto',
    'languageSubtitle': 'Elige el idioma de la interfaz',
    'defaultPdfReader': 'Lector PDF por defecto',
    'defaultPdfReaderSubtitle':
        'Usa Minimal PDF para abrir PDFs desde el dispositivo u otras apps. El sistema te pedirá confirmar “Siempre”.',
    'defaultPdfReaderOpenSettings': 'Abrir ajustes del sistema',
    'defaultPdfReaderHint':
        'En Android, elige Minimal PDF y toca “Siempre”. En iOS, abre un PDF y selecciona Minimal PDF.',
    'defaultPdfReaderOpenFailed':
        'No se pudieron abrir los ajustes del sistema.',
    'searchHint': 'Buscar por título, autor o etiqueta',
    'clearSearch': 'Limpiar búsqueda',
    'fileNotFound': 'Archivo no encontrado',
    'fileNotFoundBody': '“{title}” ya no está en el dispositivo. ¿Quieres quitarlo de la biblioteca?',
    'removeFromLibrary': 'Quitar de la biblioteca',
    'rename': 'Renombrar',
    'renameCollection': 'Renombrar colección',
    'deleteCollection': 'Eliminar colección',
    'deleteCollectionConfirm': '¿Eliminar “{name}”? Los PDFs no se borran; quedan sin carpeta.',
    'noSearchResults': 'Sin resultados',
    'noSearchResultsHint': 'Prueba con otro título, autor o etiqueta.',
    'retry': 'Reintentar',
    'noCollection': 'Sin colección',
    'collectionLabel': 'Colección',
    'importing': 'Importando…',
    'errorMetadataSave': 'No se pudieron guardar los metadatos.',
    'errorCollectionCreate': 'No se pudo crear la colección.',
    'errorCollectionRename': 'No se pudo renombrar la colección.',
    'errorCollectionDelete': 'No se pudo eliminar la colección.',
    'errorCollectionNameExists': 'Ya existe una colección con ese nombre.',
    'errorDeletePdf': 'No se pudo eliminar el PDF.',
    'errorTimeout': 'Tiempo de espera agotado. Inténtalo de nuevo.',
    'errorNoNetwork': 'Sin conexión de red. Comprueba tu acceso a Internet.',
    'errorConnectionFailed': 'No se pudo conectar con el servidor.',
    'errorDownloadInProgress': 'Ya hay una descarga en curso.',
    'errorNativeDownloadFailed': 'La descarga falló en el dispositivo.',
    'downloadCancelled': 'Descarga cancelada.',
    'multiplePdfsDetected': 'Hay {count} PDFs detectados. Elige uno de la lista.',
  },
  'en': {
    'cancel': 'Cancel',
    'save': 'Save',
    'create': 'Create',
    'delete': 'Delete',
    'close': 'Close',
    'options': 'Options',
    'settings': 'Settings',
    'language': 'Language',
    'theme': 'Theme',
    'appearance': 'Appearance',
    'themeLight': 'Light',
    'themeSepia': 'Sepia',
    'themeEbony': 'Ébano',
    'library': 'Library',
    'librarySubtitle': 'Recent PDFs and collections · 100% offline',
    'importPdf': 'Import PDF',
    'downloadsBrowser': 'Downloads / browser',
    'viewList': 'List view',
    'viewGrid': 'Grid view',
    'allCollections': 'All',
    'newCollectionShort': 'New',
    'newCollection': 'New collection',
    'collectionName': 'Name',
    'emptyLibrary': 'Your library is empty',
    'emptyLibraryHint': 'Tap + to import a PDF from your device.',
    'emptyCollection': 'No PDFs in this collection',
    'emptyCollectionHint': 'Import a PDF or choose another folder.',
    'deletePdf': 'Delete PDF',
    'deletePdfConfirm': 'Delete “{title}” from the library?',
    'imported': 'Imported: {title}',
    'editMetadata': 'Edit metadata',
    'titleLabel': 'Title',
    'authorLabel': 'Author',
    'tagsLabel': 'Tags',
    'tagsHint': 'comma-separated',
    'pageAbbrev': 'p. {page}',
    'errorLibraryLoad': 'Could not load the library.',
    'errorImportPdf': 'Could not import the PDF.',
    'showControls': 'Show controls',
    'hideControls': 'Hide controls',
    'menuToc': 'Menu / table of contents',
    'back': 'Back',
    'addBookmark': 'Bookmark page',
    'removeBookmark': 'Remove bookmark',
    'addNote': 'Add note',
    'filterEbonyOn': 'Ébano filter',
    'filterEbonyOff': 'Disable Ébano filter',
    'scrollModeTooltip': 'Mode: {mode}',
    'scrollVertical': 'Vertical',
    'scrollPaged': 'Pages',
    'pageLoadError': 'Error loading page',
    'openPdfError': 'Could not open the PDF.\n{error}',
    'navigation': 'Navigation',
    'tocTab': 'Contents',
    'bookmarksTab': 'Bookmarks',
    'goToPage': 'Go to page',
    'go': 'Go',
    'pageIndex': 'Page index',
    'pageNumber': 'Page {page}',
    'noBookmarks':
        'No bookmarks.\nBookmark the current page with the bronze icon.',
    'notePage': 'Note · page {page}',
    'notePageAbbrev': 'Note · p. {page}',
    'noteHint': 'Write a note…',
    'downloads': 'Downloads',
    'capturePdf': 'Capture PDF',
    'capturePdfCount': 'Capture PDF ({count})',
    'directPdfUrl': 'Direct PDF URL',
    'download': 'Download',
    'urlHint': 'https://example.com/file.pdf',
    'browserUnavailable':
        'The mini-browser is available on Android and iOS.\nOn desktop you can use the direct URL above.',
    'browserBack': 'Back',
    'browserForward': 'Forward',
    'browserReload': 'Reload',
    'browserUrlHint': 'Search or open URL',
    'privateBrowser': 'Private mini-browser · no telemetry',
    'pdfLinksDetected': '{count} PDF link(s) detected',
    'downloaded': 'Downloaded: {title}',
    'errorInvalidUrl': 'Enter a valid http(s) URL.',
    'downloading': 'Downloading…',
    'savedToLibrary': 'Saved to library: {title}',
    'errorDownloadPdf': 'Could not download the PDF.',
    'errorNoPdfLink': 'No PDF link found on this page.',
    'settingsSubtitle': 'Language, appearance, and default PDF reader',
    'languageSubtitle': 'Choose the interface language',
    'defaultPdfReader': 'Default PDF reader',
    'defaultPdfReaderSubtitle':
        'Use Minimal PDF to open PDFs from this device or other apps. The system will ask you to confirm “Always”.',
    'defaultPdfReaderOpenSettings': 'Open system settings',
    'defaultPdfReaderHint':
        'On Android, choose Minimal PDF and tap “Always”. On iOS, open a PDF and select Minimal PDF.',
    'defaultPdfReaderOpenFailed': 'Could not open system settings.',
    'searchHint': 'Search by title, author or tag',
    'clearSearch': 'Clear search',
    'fileNotFound': 'File not found',
    'fileNotFoundBody': '“{title}” is no longer on this device. Remove it from the library?',
    'removeFromLibrary': 'Remove from library',
    'rename': 'Rename',
    'renameCollection': 'Rename collection',
    'deleteCollection': 'Delete collection',
    'deleteCollectionConfirm': 'Delete “{name}”? PDFs are not deleted; they become unfiled.',
    'noSearchResults': 'No results',
    'noSearchResultsHint': 'Try another title, author or tag.',
    'retry': 'Retry',
    'noCollection': 'No collection',
    'collectionLabel': 'Collection',
    'importing': 'Importing…',
    'errorMetadataSave': 'Could not save metadata.',
    'errorCollectionCreate': 'Could not create the collection.',
    'errorCollectionRename': 'Could not rename the collection.',
    'errorCollectionDelete': 'Could not delete the collection.',
    'errorCollectionNameExists': 'A collection with that name already exists.',
    'errorDeletePdf': 'Could not delete the PDF.',
    'errorTimeout': 'Request timed out. Try again.',
    'errorNoNetwork': 'No network connection. Check your Internet access.',
    'errorConnectionFailed': 'Could not connect to the server.',
    'errorDownloadInProgress': 'A download is already in progress.',
    'errorNativeDownloadFailed': 'The download failed on the device.',
    'downloadCancelled': 'Download cancelled.',
    'multiplePdfsDetected': '{count} PDFs detected. Choose one from the list.',
  },
  'pt': {
    'cancel': 'Cancelar',
    'save': 'Guardar',
    'create': 'Criar',
    'delete': 'Eliminar',
    'close': 'Fechar',
    'options': 'Opções',
    'settings': 'Definições',
    'language': 'Idioma',
    'theme': 'Tema',
    'appearance': 'Aparência',
    'themeLight': 'Claro',
    'themeSepia': 'Sépia',
    'themeEbony': 'Ébano',
    'library': 'Biblioteca',
    'librarySubtitle': 'PDFs recentes e coleções · 100% offline',
    'importPdf': 'Importar PDF',
    'downloadsBrowser': 'Transferências / navegador',
    'viewList': 'Vista de lista',
    'viewGrid': 'Vista de grelha',
    'allCollections': 'Todos',
    'newCollectionShort': 'Nova',
    'newCollection': 'Nova coleção',
    'collectionName': 'Nome',
    'emptyLibrary': 'A sua biblioteca está vazia',
    'emptyLibraryHint': 'Toque em + para importar um PDF do dispositivo.',
    'emptyCollection': 'Não há PDFs nesta coleção',
    'emptyCollectionHint': 'Importe um PDF ou escolha outra pasta.',
    'deletePdf': 'Eliminar PDF',
    'deletePdfConfirm': 'Eliminar “{title}” da biblioteca?',
    'imported': 'Importado: {title}',
    'editMetadata': 'Editar metadados',
    'titleLabel': 'Título',
    'authorLabel': 'Autor',
    'tagsLabel': 'Tags',
    'tagsHint': 'separadas por vírgula',
    'pageAbbrev': 'p. {page}',
    'errorLibraryLoad': 'Não foi possível carregar a biblioteca.',
    'errorImportPdf': 'Não foi possível importar o PDF.',
    'showControls': 'Mostrar controlos',
    'hideControls': 'Ocultar controlos',
    'menuToc': 'Menu / índice',
    'back': 'Voltar',
    'addBookmark': 'Marcar página',
    'removeBookmark': 'Remover marcador',
    'addNote': 'Adicionar nota',
    'filterEbonyOn': 'Filtro Ébano',
    'filterEbonyOff': 'Desativar filtro Ébano',
    'scrollModeTooltip': 'Modo: {mode}',
    'scrollVertical': 'Vertical',
    'scrollPaged': 'Páginas',
    'pageLoadError': 'Erro ao carregar a página',
    'openPdfError': 'Não foi possível abrir o PDF.\n{error}',
    'navigation': 'Navegação',
    'tocTab': 'Índice',
    'bookmarksTab': 'Marcadores',
    'goToPage': 'Ir para a página',
    'go': 'Ir',
    'pageIndex': 'Índice de páginas',
    'pageNumber': 'Página {page}',
    'noBookmarks':
        'Sem marcadores.\nMarque a página atual com o ícone bronze.',
    'notePage': 'Nota · página {page}',
    'notePageAbbrev': 'Nota · p. {page}',
    'noteHint': 'Escreva uma nota…',
    'downloads': 'Transferências',
    'capturePdf': 'Capturar PDF',
    'capturePdfCount': 'Capturar PDF ({count})',
    'directPdfUrl': 'URL direta de PDF',
    'download': 'Transferir',
    'urlHint': 'https://exemplo.com/arquivo.pdf',
    'browserUnavailable':
        'O mini-navegador está disponível no Android e iOS.\nNo computador pode usar a URL direta acima.',
    'browserBack': 'Voltar',
    'browserForward': 'Avançar',
    'browserReload': 'Recarregar',
    'browserUrlHint': 'Pesquisar ou abrir URL',
    'privateBrowser': 'Mini-navegador privado · sem telemetria',
    'pdfLinksDetected': '{count} ligação(ões) PDF detetada(s)',
    'downloaded': 'Transferido: {title}',
    'errorInvalidUrl': 'Introduza um URL http(s) válido.',
    'downloading': 'A transferir…',
    'savedToLibrary': 'Guardado na biblioteca: {title}',
    'errorDownloadPdf': 'Não foi possível transferir o PDF.',
    'errorNoPdfLink': 'Não foi encontrada nenhuma ligação PDF nesta página.',
    'settingsSubtitle': 'Idioma, aparência e leitor PDF padrão',
    'languageSubtitle': 'Escolha o idioma da interface',
    'defaultPdfReader': 'Leitor PDF padrão',
    'defaultPdfReaderSubtitle':
        'Use o Minimal PDF para abrir PDFs deste dispositivo ou de outros apps. O sistema pedirá para confirmar “Sempre”.',
    'defaultPdfReaderOpenSettings': 'Abrir definições do sistema',
    'defaultPdfReaderHint':
        'No Android, escolha Minimal PDF e toque em “Sempre”. No iOS, abra um PDF e selecione Minimal PDF.',
    'defaultPdfReaderOpenFailed':
        'Não foi possível abrir as definições do sistema.',
    'searchHint': 'Pesquisar por título, autor ou etiqueta',
    'clearSearch': 'Limpar pesquisa',
    'fileNotFound': 'Ficheiro não encontrado',
    'fileNotFoundBody': '“{title}” já não está no dispositivo. Removê-lo da biblioteca?',
    'removeFromLibrary': 'Remover da biblioteca',
    'rename': 'Mudar o nome',
    'renameCollection': 'Mudar o nome da coleção',
    'deleteCollection': 'Eliminar coleção',
    'deleteCollectionConfirm': 'Eliminar “{name}”? Os PDFs não são apagados; ficam sem pasta.',
    'noSearchResults': 'Sem resultados',
    'noSearchResultsHint': 'Tente outro título, autor ou etiqueta.',
    'retry': 'Tentar novamente',
    'noCollection': 'Sem coleção',
    'collectionLabel': 'Coleção',
    'importing': 'A importar…',
    'errorMetadataSave': 'Não foi possível guardar os metadados.',
    'errorCollectionCreate': 'Não foi possível criar a coleção.',
    'errorCollectionRename': 'Não foi possível mudar o nome da coleção.',
    'errorCollectionDelete': 'Não foi possível eliminar a coleção.',
    'errorCollectionNameExists': 'Já existe uma coleção com esse nome.',
    'errorDeletePdf': 'Não foi possível eliminar o PDF.',
    'errorTimeout': 'Tempo de espera esgotado. Tente novamente.',
    'errorNoNetwork': 'Sem ligação de rede. Verifique o acesso à Internet.',
    'errorConnectionFailed': 'Não foi possível ligar ao servidor.',
    'errorDownloadInProgress': 'Já existe uma transferência em curso.',
    'errorNativeDownloadFailed': 'A transferência falhou no dispositivo.',
    'downloadCancelled': 'Transferência cancelada.',
    'multiplePdfsDetected': 'Há {count} PDFs detetados. Escolha um da lista.',
  },
  'fr': {
    'cancel': 'Annuler',
    'save': 'Enregistrer',
    'create': 'Créer',
    'delete': 'Supprimer',
    'close': 'Fermer',
    'options': 'Options',
    'settings': 'Réglages',
    'language': 'Langue',
    'theme': 'Thème',
    'appearance': 'Apparence',
    'themeLight': 'Clair',
    'themeSepia': 'Sépia',
    'themeEbony': 'Ébano',
    'library': 'Bibliothèque',
    'librarySubtitle': 'PDF récents et collections · 100 % hors ligne',
    'importPdf': 'Importer un PDF',
    'downloadsBrowser': 'Téléchargements / navigateur',
    'viewList': 'Vue liste',
    'viewGrid': 'Vue grille',
    'allCollections': 'Tous',
    'newCollectionShort': 'Nouvelle',
    'newCollection': 'Nouvelle collection',
    'collectionName': 'Nom',
    'emptyLibrary': 'Votre bibliothèque est vide',
    'emptyLibraryHint': 'Appuyez sur + pour importer un PDF depuis l’appareil.',
    'emptyCollection': 'Aucun PDF dans cette collection',
    'emptyCollectionHint': 'Importez un PDF ou choisissez un autre dossier.',
    'deletePdf': 'Supprimer le PDF',
    'deletePdfConfirm': 'Supprimer « {title} » de la bibliothèque ?',
    'imported': 'Importé : {title}',
    'editMetadata': 'Modifier les métadonnées',
    'titleLabel': 'Titre',
    'authorLabel': 'Auteur',
    'tagsLabel': 'Tags',
    'tagsHint': 'séparés par des virgules',
    'pageAbbrev': 'p. {page}',
    'errorLibraryLoad': 'Impossible de charger la bibliothèque.',
    'errorImportPdf': 'Impossible d’importer le PDF.',
    'showControls': 'Afficher les commandes',
    'hideControls': 'Masquer les commandes',
    'menuToc': 'Menu / table des matières',
    'back': 'Retour',
    'addBookmark': 'Marquer la page',
    'removeBookmark': 'Retirer le signet',
    'addNote': 'Ajouter une note',
    'filterEbonyOn': 'Filtre Ébano',
    'filterEbonyOff': 'Désactiver le filtre Ébano',
    'scrollModeTooltip': 'Mode : {mode}',
    'scrollVertical': 'Vertical',
    'scrollPaged': 'Pages',
    'pageLoadError': 'Erreur de chargement de la page',
    'openPdfError': 'Impossible d’ouvrir le PDF.\n{error}',
    'navigation': 'Navigation',
    'tocTab': 'Sommaire',
    'bookmarksTab': 'Signets',
    'goToPage': 'Aller à la page',
    'go': 'Aller',
    'pageIndex': 'Index des pages',
    'pageNumber': 'Page {page}',
    'noBookmarks':
        'Aucun signet.\nMarquez la page actuelle avec l’icône bronze.',
    'notePage': 'Note · page {page}',
    'notePageAbbrev': 'Note · p. {page}',
    'noteHint': 'Écrire une note…',
    'downloads': 'Téléchargements',
    'capturePdf': 'Capturer le PDF',
    'capturePdfCount': 'Capturer le PDF ({count})',
    'directPdfUrl': 'URL directe du PDF',
    'download': 'Télécharger',
    'urlHint': 'https://exemple.com/fichier.pdf',
    'browserUnavailable':
        'Le mini-navigateur est disponible sur Android et iOS.\nSur ordinateur, utilisez l’URL directe ci-dessus.',
    'browserBack': 'Retour',
    'browserForward': 'Avant',
    'browserReload': 'Recharger',
    'browserUrlHint': 'Rechercher ou ouvrir une URL',
    'privateBrowser': 'Mini-navigateur privé · sans télémétrie',
    'pdfLinksDetected': '{count} lien(s) PDF détecté(s)',
    'downloaded': 'Téléchargé : {title}',
    'errorInvalidUrl': 'Saisissez une URL http(s) valide.',
    'downloading': 'Téléchargement…',
    'savedToLibrary': 'Enregistré dans la bibliothèque : {title}',
    'errorDownloadPdf': 'Impossible de télécharger le PDF.',
    'errorNoPdfLink': 'Aucun lien PDF trouvé sur cette page.',
    'settingsSubtitle': 'Langue, apparence et lecteur PDF par défaut',
    'languageSubtitle': 'Choisissez la langue de l’interface',
    'defaultPdfReader': 'Lecteur PDF par défaut',
    'defaultPdfReaderSubtitle':
        'Utilisez Minimal PDF pour ouvrir des PDF depuis l’appareil ou d’autres apps. Le système demandera de confirmer « Toujours ».',
    'defaultPdfReaderOpenSettings': 'Ouvrir les réglages système',
    'defaultPdfReaderHint':
        'Sous Android, choisissez Minimal PDF et touchez « Toujours ». Sous iOS, ouvrez un PDF et sélectionnez Minimal PDF.',
    'defaultPdfReaderOpenFailed':
        'Impossible d’ouvrir les réglages système.',
    'searchHint': 'Rechercher par titre, auteur ou étiquette',
    'clearSearch': 'Effacer la recherche',
    'fileNotFound': 'Fichier introuvable',
    'fileNotFoundBody': '« {title} » n’est plus sur l’appareil. Le retirer de la bibliothèque ?',
    'removeFromLibrary': 'Retirer de la bibliothèque',
    'rename': 'Renommer',
    'renameCollection': 'Renommer la collection',
    'deleteCollection': 'Supprimer la collection',
    'deleteCollectionConfirm': 'Supprimer « {name} » ? Les PDF ne sont pas effacés ; ils restent sans dossier.',
    'noSearchResults': 'Aucun résultat',
    'noSearchResultsHint': 'Essayez un autre titre, auteur ou étiquette.',
    'retry': 'Réessayer',
    'noCollection': 'Sans collection',
    'collectionLabel': 'Collection',
    'importing': 'Importation…',
    'errorMetadataSave': 'Impossible d’enregistrer les métadonnées.',
    'errorCollectionCreate': 'Impossible de créer la collection.',
    'errorCollectionRename': 'Impossible de renommer la collection.',
    'errorCollectionDelete': 'Impossible de supprimer la collection.',
    'errorCollectionNameExists': 'Une collection porte déjà ce nom.',
    'errorDeletePdf': 'Impossible de supprimer le PDF.',
    'errorTimeout': 'Délai d’attente dépassé. Réessayez.',
    'errorNoNetwork': 'Pas de connexion réseau. Vérifiez votre accès Internet.',
    'errorConnectionFailed': 'Impossible de se connecter au serveur.',
    'errorDownloadInProgress': 'Un téléchargement est déjà en cours.',
    'errorNativeDownloadFailed': 'Le téléchargement a échoué sur l’appareil.',
    'downloadCancelled': 'Téléchargement annulé.',
    'multiplePdfsDetected': '{count} PDF détectés. Choisissez-en un dans la liste.',
  },
  'de': {
    'cancel': 'Abbrechen',
    'save': 'Speichern',
    'create': 'Erstellen',
    'delete': 'Löschen',
    'close': 'Schließen',
    'options': 'Optionen',
    'settings': 'Einstellungen',
    'language': 'Sprache',
    'theme': 'Design',
    'appearance': 'Erscheinungsbild',
    'themeLight': 'Hell',
    'themeSepia': 'Sepia',
    'themeEbony': 'Ébano',
    'library': 'Bibliothek',
    'librarySubtitle': 'Aktuelle PDFs und Sammlungen · 100 % offline',
    'importPdf': 'PDF importieren',
    'downloadsBrowser': 'Downloads / Browser',
    'viewList': 'Listenansicht',
    'viewGrid': 'Rasteransicht',
    'allCollections': 'Alle',
    'newCollectionShort': 'Neu',
    'newCollection': 'Neue Sammlung',
    'collectionName': 'Name',
    'emptyLibrary': 'Ihre Bibliothek ist leer',
    'emptyLibraryHint':
        'Tippen Sie auf +, um ein PDF vom Gerät zu importieren.',
    'emptyCollection': 'Keine PDFs in dieser Sammlung',
    'emptyCollectionHint':
        'Importieren Sie ein PDF oder wählen Sie einen anderen Ordner.',
    'deletePdf': 'PDF löschen',
    'deletePdfConfirm': '„{title}“ aus der Bibliothek löschen?',
    'imported': 'Importiert: {title}',
    'editMetadata': 'Metadaten bearbeiten',
    'titleLabel': 'Titel',
    'authorLabel': 'Autor',
    'tagsLabel': 'Tags',
    'tagsHint': 'durch Komma getrennt',
    'pageAbbrev': 'S. {page}',
    'errorLibraryLoad': 'Bibliothek konnte nicht geladen werden.',
    'errorImportPdf': 'PDF konnte nicht importiert werden.',
    'showControls': 'Steuerung anzeigen',
    'hideControls': 'Steuerung ausblenden',
    'menuToc': 'Menü / Inhaltsverzeichnis',
    'back': 'Zurück',
    'addBookmark': 'Seite markieren',
    'removeBookmark': 'Lesezeichen entfernen',
    'addNote': 'Notiz hinzufügen',
    'filterEbonyOn': 'Ébano-Filter',
    'filterEbonyOff': 'Ébano-Filter deaktivieren',
    'scrollModeTooltip': 'Modus: {mode}',
    'scrollVertical': 'Vertikal',
    'scrollPaged': 'Seiten',
    'pageLoadError': 'Fehler beim Laden der Seite',
    'openPdfError': 'PDF konnte nicht geöffnet werden.\n{error}',
    'navigation': 'Navigation',
    'tocTab': 'Inhalt',
    'bookmarksTab': 'Lesezeichen',
    'goToPage': 'Zur Seite',
    'go': 'Los',
    'pageIndex': 'Seitenindex',
    'pageNumber': 'Seite {page}',
    'noBookmarks':
        'Keine Lesezeichen.\nMarkieren Sie die aktuelle Seite mit dem Bronze-Symbol.',
    'notePage': 'Notiz · Seite {page}',
    'notePageAbbrev': 'Notiz · S. {page}',
    'noteHint': 'Notiz schreiben…',
    'downloads': 'Downloads',
    'capturePdf': 'PDF erfassen',
    'capturePdfCount': 'PDF erfassen ({count})',
    'directPdfUrl': 'Direkte PDF-URL',
    'download': 'Herunterladen',
    'urlHint': 'https://beispiel.com/datei.pdf',
    'browserUnavailable':
        'Der Mini-Browser ist unter Android und iOS verfügbar.\nAuf dem Desktop können Sie die direkte URL oben verwenden.',
    'browserBack': 'Zurück',
    'browserForward': 'Vorwärts',
    'browserReload': 'Neu laden',
    'browserUrlHint': 'Suchen oder URL öffnen',
    'privateBrowser': 'Privater Mini-Browser · ohne Telemetrie',
    'pdfLinksDetected': '{count} PDF-Link(s) erkannt',
    'downloaded': 'Heruntergeladen: {title}',
    'errorInvalidUrl': 'Geben Sie eine gültige http(s)-URL ein.',
    'downloading': 'Wird heruntergeladen…',
    'savedToLibrary': 'In Bibliothek gespeichert: {title}',
    'errorDownloadPdf': 'PDF konnte nicht heruntergeladen werden.',
    'errorNoPdfLink': 'Auf dieser Seite wurde kein PDF-Link gefunden.',
    'settingsSubtitle': 'Sprache, Erscheinungsbild und Standard-PDF-Reader',
    'languageSubtitle': 'Wählen Sie die Sprache der Oberfläche',
    'defaultPdfReader': 'Standard-PDF-Reader',
    'defaultPdfReaderSubtitle':
        'Minimal PDF zum Öffnen von PDFs vom Gerät oder aus anderen Apps verwenden. Das System fragt nach „Immer“.',
    'defaultPdfReaderOpenSettings': 'Systemeinstellungen öffnen',
    'defaultPdfReaderHint':
        'Unter Android Minimal PDF wählen und „Immer“ tippen. Unter iOS ein PDF öffnen und Minimal PDF auswählen.',
    'defaultPdfReaderOpenFailed':
        'Systemeinstellungen konnten nicht geöffnet werden.',
    'searchHint': 'Nach Titel, Autor oder Tag suchen',
    'clearSearch': 'Suche löschen',
    'fileNotFound': 'Datei nicht gefunden',
    'fileNotFoundBody': '„{title}“ ist nicht mehr auf dem Gerät. Aus der Bibliothek entfernen?',
    'removeFromLibrary': 'Aus Bibliothek entfernen',
    'rename': 'Umbenennen',
    'renameCollection': 'Sammlung umbenennen',
    'deleteCollection': 'Sammlung löschen',
    'deleteCollectionConfirm': '„{name}“ löschen? PDFs werden nicht gelöscht; sie bleiben ohne Ordner.',
    'noSearchResults': 'Keine Ergebnisse',
    'noSearchResultsHint': 'Versuchen Sie einen anderen Titel, Autor oder Tag.',
    'retry': 'Erneut versuchen',
    'noCollection': 'Keine Sammlung',
    'collectionLabel': 'Sammlung',
    'importing': 'Wird importiert…',
    'errorMetadataSave': 'Metadaten konnten nicht gespeichert werden.',
    'errorCollectionCreate': 'Sammlung konnte nicht erstellt werden.',
    'errorCollectionRename': 'Sammlung konnte nicht umbenannt werden.',
    'errorCollectionDelete': 'Sammlung konnte nicht gelöscht werden.',
    'errorCollectionNameExists': 'Eine Sammlung mit diesem Namen existiert bereits.',
    'errorDeletePdf': 'PDF konnte nicht gelöscht werden.',
    'errorTimeout': 'Zeitüberschreitung. Bitte erneut versuchen.',
    'errorNoNetwork': 'Keine Netzwerkverbindung. Prüfen Sie Ihren Internetzugang.',
    'errorConnectionFailed': 'Verbindung zum Server fehlgeschlagen.',
    'errorDownloadInProgress': 'Es läuft bereits ein Download.',
    'errorNativeDownloadFailed': 'Der Download ist auf dem Gerät fehlgeschlagen.',
    'downloadCancelled': 'Download abgebrochen.',
    'multiplePdfsDetected': '{count} PDFs erkannt. Wählen Sie eines aus der Liste.',
  },
  'zh': {
    'cancel': '取消',
    'save': '保存',
    'create': '创建',
    'delete': '删除',
    'close': '关闭',
    'options': '选项',
    'settings': '设置',
    'language': '语言',
    'theme': '主题',
    'appearance': '外观',
    'themeLight': '浅色',
    'themeSepia': '羊皮纸',
    'themeEbony': 'Ébano',
    'library': '书库',
    'librarySubtitle': '最近的 PDF 与合集 · 100% 离线',
    'importPdf': '导入 PDF',
    'downloadsBrowser': '下载 / 浏览器',
    'viewList': '列表视图',
    'viewGrid': '网格视图',
    'allCollections': '全部',
    'newCollectionShort': '新建',
    'newCollection': '新建合集',
    'collectionName': '名称',
    'emptyLibrary': '书库为空',
    'emptyLibraryHint': '点按 + 从设备导入 PDF。',
    'emptyCollection': '此合集中没有 PDF',
    'emptyCollectionHint': '导入 PDF 或选择其他文件夹。',
    'deletePdf': '删除 PDF',
    'deletePdfConfirm': '要从书库中删除“{title}”吗？',
    'imported': '已导入：{title}',
    'editMetadata': '编辑元数据',
    'titleLabel': '标题',
    'authorLabel': '作者',
    'tagsLabel': '标签',
    'tagsHint': '用逗号分隔',
    'pageAbbrev': '第 {page} 页',
    'errorLibraryLoad': '无法加载书库。',
    'errorImportPdf': '无法导入 PDF。',
    'showControls': '显示控件',
    'hideControls': '隐藏控件',
    'menuToc': '菜单 / 目录',
    'back': '返回',
    'addBookmark': '添加书签',
    'removeBookmark': '移除书签',
    'addNote': '添加笔记',
    'filterEbonyOn': 'Ébano 滤镜',
    'filterEbonyOff': '关闭 Ébano 滤镜',
    'scrollModeTooltip': '模式：{mode}',
    'scrollVertical': '纵向',
    'scrollPaged': '分页',
    'pageLoadError': '页面加载出错',
    'openPdfError': '无法打开 PDF。\n{error}',
    'navigation': '导航',
    'tocTab': '目录',
    'bookmarksTab': '书签',
    'goToPage': '跳转到页',
    'go': '前往',
    'pageIndex': '页码索引',
    'pageNumber': '第 {page} 页',
    'noBookmarks': '暂无书签。\n使用铜色图标为当前页添加书签。',
    'notePage': '笔记 · 第 {page} 页',
    'notePageAbbrev': '笔记 · 第 {page} 页',
    'noteHint': '写一条笔记…',
    'downloads': '下载',
    'capturePdf': '捕获 PDF',
    'capturePdfCount': '捕获 PDF（{count}）',
    'directPdfUrl': 'PDF 直链',
    'download': '下载',
    'urlHint': 'https://example.com/file.pdf',
    'browserUnavailable': '迷你浏览器仅在 Android 和 iOS 上可用。\n在桌面端请使用上方的直链。',
    'browserBack': '后退',
    'browserForward': '前进',
    'browserReload': '刷新',
    'browserUrlHint': '搜索或打开网址',
    'privateBrowser': '私密迷你浏览器 · 无遥测',
    'pdfLinksDetected': '检测到 {count} 个 PDF 链接',
    'downloaded': '已下载：{title}',
    'errorInvalidUrl': '请输入有效的 http(s) 网址。',
    'downloading': '正在下载…',
    'savedToLibrary': '已保存到书库：{title}',
    'errorDownloadPdf': '无法下载 PDF。',
    'errorNoPdfLink': '此页面未找到 PDF 链接。',
    'settingsSubtitle': '语言、外观与默认 PDF 阅读器',
    'languageSubtitle': '选择界面语言',
    'defaultPdfReader': '默认 PDF 阅读器',
    'defaultPdfReaderSubtitle':
        '用 Minimal PDF 打开本机或其他应用中的 PDF。系统会要求确认“始终”。',
    'defaultPdfReaderOpenSettings': '打开系统设置',
    'defaultPdfReaderHint':
        '在 Android 上选择 Minimal PDF 并点“始终”。在 iOS 上打开 PDF 并选择 Minimal PDF。',
    'defaultPdfReaderOpenFailed': '无法打开系统设置。',
    'searchHint': '按标题、作者或标签搜索',
    'clearSearch': '清除搜索',
    'fileNotFound': '未找到文件',
    'fileNotFoundBody': '“{title}”已不在此设备上。要从书库中移除吗？',
    'removeFromLibrary': '从书库移除',
    'rename': '重命名',
    'renameCollection': '重命名合集',
    'deleteCollection': '删除合集',
    'deleteCollectionConfirm': '删除“{name}”？PDF 不会被删除，只是不再属于任何合集。',
    'noSearchResults': '无结果',
    'noSearchResultsHint': '试试其他标题、作者或标签。',
    'retry': '重试',
    'noCollection': '无合集',
    'collectionLabel': '合集',
    'importing': '正在导入…',
    'errorMetadataSave': '无法保存元数据。',
    'errorCollectionCreate': '无法创建合集。',
    'errorCollectionRename': '无法重命名合集。',
    'errorCollectionDelete': '无法删除合集。',
    'errorCollectionNameExists': '已存在同名合集。',
    'errorDeletePdf': '无法删除 PDF。',
    'errorTimeout': '请求超时。请重试。',
    'errorNoNetwork': '无网络连接。请检查互联网访问。',
    'errorConnectionFailed': '无法连接到服务器。',
    'errorDownloadInProgress': '已有下载正在进行。',
    'errorNativeDownloadFailed': '设备上下载失败。',
    'downloadCancelled': '下载已取消。',
    'multiplePdfsDetected': '检测到 {count} 个 PDF。请从列表中选择一个。',
  },
  'ru': {
    'cancel': 'Отмена',
    'save': 'Сохранить',
    'create': 'Создать',
    'delete': 'Удалить',
    'close': 'Закрыть',
    'options': 'Параметры',
    'settings': 'Настройки',
    'language': 'Язык',
    'theme': 'Тема',
    'appearance': 'Оформление',
    'themeLight': 'Светлая',
    'themeSepia': 'Сепия',
    'themeEbony': 'Ébano',
    'library': 'Библиотека',
    'librarySubtitle': 'Недавние PDF и коллекции · 100% офлайн',
    'importPdf': 'Импортировать PDF',
    'downloadsBrowser': 'Загрузки / браузер',
    'viewList': 'Список',
    'viewGrid': 'Сетка',
    'allCollections': 'Все',
    'newCollectionShort': 'Новая',
    'newCollection': 'Новая коллекция',
    'collectionName': 'Название',
    'emptyLibrary': 'Ваша библиотека пуста',
    'emptyLibraryHint': 'Нажмите +, чтобы импортировать PDF с устройства.',
    'emptyCollection': 'В этой коллекции нет PDF',
    'emptyCollectionHint': 'Импортируйте PDF или выберите другую папку.',
    'deletePdf': 'Удалить PDF',
    'deletePdfConfirm': 'Удалить «{title}» из библиотеки?',
    'imported': 'Импортировано: {title}',
    'editMetadata': 'Изменить метаданные',
    'titleLabel': 'Название',
    'authorLabel': 'Автор',
    'tagsLabel': 'Теги',
    'tagsHint': 'через запятую',
    'pageAbbrev': 'с. {page}',
    'errorLibraryLoad': 'Не удалось загрузить библиотеку.',
    'errorImportPdf': 'Не удалось импортировать PDF.',
    'showControls': 'Показать элементы управления',
    'hideControls': 'Скрыть элементы управления',
    'menuToc': 'Меню / оглавление',
    'back': 'Назад',
    'addBookmark': 'Добавить закладку',
    'removeBookmark': 'Убрать закладку',
    'addNote': 'Добавить заметку',
    'filterEbonyOn': 'Фильтр Ébano',
    'filterEbonyOff': 'Отключить фильтр Ébano',
    'scrollModeTooltip': 'Режим: {mode}',
    'scrollVertical': 'Вертикально',
    'scrollPaged': 'Страницы',
    'pageLoadError': 'Ошибка загрузки страницы',
    'openPdfError': 'Не удалось открыть PDF.\n{error}',
    'navigation': 'Навигация',
    'tocTab': 'Оглавление',
    'bookmarksTab': 'Закладки',
    'goToPage': 'Перейти к странице',
    'go': 'Перейти',
    'pageIndex': 'Указатель страниц',
    'pageNumber': 'Страница {page}',
    'noBookmarks':
        'Нет закладок.\nОтметьте текущую страницу бронзовой иконкой.',
    'notePage': 'Заметка · страница {page}',
    'notePageAbbrev': 'Заметка · с. {page}',
    'noteHint': 'Напишите заметку…',
    'downloads': 'Загрузки',
    'capturePdf': 'Захватить PDF',
    'capturePdfCount': 'Захватить PDF ({count})',
    'directPdfUrl': 'Прямой URL PDF',
    'download': 'Скачать',
    'urlHint': 'https://primer.com/file.pdf',
    'browserUnavailable':
        'Мини-браузер доступен на Android и iOS.\nНа компьютере используйте прямой URL выше.',
    'browserBack': 'Назад',
    'browserForward': 'Вперёд',
    'browserReload': 'Обновить',
    'browserUrlHint': 'Поиск или открытие URL',
    'privateBrowser': 'Приватный мини-браузер · без телеметрии',
    'pdfLinksDetected': 'Обнаружено PDF-ссылок: {count}',
    'downloaded': 'Скачано: {title}',
    'errorInvalidUrl': 'Введите действительный URL http(s).',
    'downloading': 'Загрузка…',
    'savedToLibrary': 'Сохранено в библиотеку: {title}',
    'errorDownloadPdf': 'Не удалось скачать PDF.',
    'errorNoPdfLink': 'На этой странице не найдена ссылка на PDF.',
    'settingsSubtitle': 'Язык, оформление и программа PDF по умолчанию',
    'languageSubtitle': 'Выберите язык интерфейса',
    'defaultPdfReader': 'Программа PDF по умолчанию',
    'defaultPdfReaderSubtitle':
        'Открывайте PDF через Minimal PDF с устройства или из других приложений. Система попросит подтвердить «Всегда».',
    'defaultPdfReaderOpenSettings': 'Открыть системные настройки',
    'defaultPdfReaderHint':
        'В Android выберите Minimal PDF и нажмите «Всегда». В iOS откройте PDF и выберите Minimal PDF.',
    'defaultPdfReaderOpenFailed':
        'Не удалось открыть системные настройки.',
    'searchHint': 'Поиск по названию, автору или тегу',
    'clearSearch': 'Очистить поиск',
    'fileNotFound': 'Файл не найден',
    'fileNotFoundBody': '«{title}» больше нет на устройстве. Удалить из библиотеки?',
    'removeFromLibrary': 'Убрать из библиотеки',
    'rename': 'Переименовать',
    'renameCollection': 'Переименовать коллекцию',
    'deleteCollection': 'Удалить коллекцию',
    'deleteCollectionConfirm': 'Удалить «{name}»? PDF не удаляются; они остаются без папки.',
    'noSearchResults': 'Нет результатов',
    'noSearchResultsHint': 'Попробуйте другое название, автора или тег.',
    'retry': 'Повторить',
    'noCollection': 'Без коллекции',
    'collectionLabel': 'Коллекция',
    'importing': 'Импорт…',
    'errorMetadataSave': 'Не удалось сохранить метаданные.',
    'errorCollectionCreate': 'Не удалось создать коллекцию.',
    'errorCollectionRename': 'Не удалось переименовать коллекцию.',
    'errorCollectionDelete': 'Не удалось удалить коллекцию.',
    'errorCollectionNameExists': 'Коллекция с таким именем уже существует.',
    'errorDeletePdf': 'Не удалось удалить PDF.',
    'errorTimeout': 'Время ожидания истекло. Попробуйте снова.',
    'errorNoNetwork': 'Нет сетевого подключения. Проверьте доступ в Интернет.',
    'errorConnectionFailed': 'Не удалось подключиться к серверу.',
    'errorDownloadInProgress': 'Загрузка уже выполняется.',
    'errorNativeDownloadFailed': 'Загрузка на устройстве не удалась.',
    'downloadCancelled': 'Загрузка отменена.',
    'multiplePdfsDetected': 'Обнаружено PDF: {count}. Выберите один из списка.',
  },
};
