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
  String get themeObsidian => _t('themeObsidian');

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

  // —— Lector ——
  String get showControls => _t('showControls');
  String get hideControls => _t('hideControls');
  String get menuToc => _t('menuToc');
  String get back => _t('back');
  String get addBookmark => _t('addBookmark');
  String get removeBookmark => _t('removeBookmark');
  String get addNote => _t('addNote');
  String get filterObsidianOn => _t('filterObsidianOn');
  String get filterObsidianOff => _t('filterObsidianOff');
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

  /// Resuelve mensajes emitidos por providers.
  String message(String key, {String? arg}) {
    return switch (key) {
      AppMessageKeys.libraryLoadFailed => errorLibraryLoad,
      AppMessageKeys.importPdfFailed => errorImportPdf,
      AppMessageKeys.invalidUrl => errorInvalidUrl,
      AppMessageKeys.downloading => downloading,
      AppMessageKeys.savedToLibrary => savedToLibrary(arg ?? ''),
      AppMessageKeys.downloadFailed => errorDownloadPdf,
      AppMessageKeys.noPdfLink => errorNoPdfLink,
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Filtro Hermes Obsidian',
    'filterObsidianOff': 'Desactivar filtro Obsidian',
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
    'settingsSubtitle': 'Idioma y apariencia de Minimal PDF',
    'languageSubtitle': 'Elige el idioma de la interfaz',
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Hermes Obsidian filter',
    'filterObsidianOff': 'Disable Obsidian filter',
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
    'settingsSubtitle': 'Language and appearance for Minimal PDF',
    'languageSubtitle': 'Choose the interface language',
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Filtro Hermes Obsidian',
    'filterObsidianOff': 'Desativar filtro Obsidian',
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
    'settingsSubtitle': 'Idioma e aparência do Minimal PDF',
    'languageSubtitle': 'Escolha o idioma da interface',
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Filtre Hermes Obsidian',
    'filterObsidianOff': 'Désactiver le filtre Obsidian',
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
    'settingsSubtitle': 'Langue et apparence de Minimal PDF',
    'languageSubtitle': 'Choisissez la langue de l’interface',
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Hermes-Obsidian-Filter',
    'filterObsidianOff': 'Obsidian-Filter deaktivieren',
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
    'settingsSubtitle': 'Sprache und Erscheinungsbild von Minimal PDF',
    'languageSubtitle': 'Wählen Sie die Sprache der Oberfläche',
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Hermes Obsidian 滤镜',
    'filterObsidianOff': '关闭 Obsidian 滤镜',
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
    'settingsSubtitle': 'Minimal PDF 的语言与外观',
    'languageSubtitle': '选择界面语言',
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
    'themeObsidian': 'Hermes Obsidian',
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
    'filterObsidianOn': 'Фильтр Hermes Obsidian',
    'filterObsidianOff': 'Отключить фильтр Obsidian',
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
    'settingsSubtitle': 'Язык и оформление Minimal PDF',
    'languageSubtitle': 'Выберите язык интерфейса',
  },
};
