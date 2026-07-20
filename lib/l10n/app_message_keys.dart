/// Claves de mensajes emitidos por providers (se resuelven en la UI).
abstract final class AppMessageKeys {
  static const libraryLoadFailed = 'libraryLoadFailed';
  static const importPdfFailed = 'importPdfFailed';
  static const metadataSaveFailed = 'metadataSaveFailed';
  static const collectionCreateFailed = 'collectionCreateFailed';
  static const collectionRenameFailed = 'collectionRenameFailed';
  static const collectionDeleteFailed = 'collectionDeleteFailed';
  static const collectionNameExists = 'collectionNameExists';
  static const deletePdfFailed = 'deletePdfFailed';
  static const invalidUrl = 'invalidUrl';
  static const downloading = 'downloading';
  static const savedToLibrary = 'savedToLibrary';
  static const downloadFailed = 'downloadFailed';
  static const noPdfLink = 'noPdfLink';
  static const timeout = 'timeout';
  static const noNetwork = 'noNetwork';
  static const connectionFailed = 'connectionFailed';
  static const downloadInProgress = 'downloadInProgress';
  static const nativeDownloadFailed = 'nativeDownloadFailed';
  static const downloadCancelled = 'downloadCancelled';
  static const multiplePdfsDetected = 'multiplePdfsDetected';

  // Firmas / anotaciones (errores de providers).
  static const waitForExport = 'waitForExport';
  static const waitForSignaturesLoad = 'waitForSignaturesLoad';
  static const waitForSigning = 'waitForSigning';
  static const signDocumentFailed = 'signDocumentFailed';
  static const exportSignedFailed = 'exportSignedFailed';
  static const deleteSignatureFailed = 'deleteSignatureFailed';
  static const signaturesLoadFailed = 'errorSignaturesLoad';
  static const signatureSaveFailed = 'errorSignatureSave';
  static const templateDeleteFailed = 'errorTemplateDelete';
  static const signatureMoveFailed = 'errorSignatureMove';
  static const needSignature = 'errorNeedSignature';
  static const cancelPlacement = 'errorCancelPlacement';
  static const exportInProgress = 'errorExportInProgress';
  static const documentUnavailable = 'errorDocumentUnavailable';
  static const documentUnavailableSign = 'errorDocumentUnavailableSign';
  static const signatureBusy = 'errorSignatureBusy';
  static const templatePartial = 'errorTemplatePartial';
  static const templatesLoadFailed = 'errorTemplatesLoad';
  static const annotationsLoadFailed = 'errorAnnotationsLoad';
  static const bookmarkRemoveFailed = 'errorBookmarkRemove';
  static const bookmarkCreateFailed = 'errorBookmarkCreate';
  static const noteSaveFailed = 'errorNoteSave';
  static const bookmarkDeleteFailed = 'errorBookmarkDelete';
  static const annotationSaveFailed = 'errorAnnotationSave';
  static const annotationUpdateFailed = 'errorAnnotationUpdate';
  static const annotationDeleteFailed = 'errorAnnotationDelete';
  static const annotationGeometryInvalid = 'errorAnnotationGeometry';
  static const indicateTemplateName = 'indicateTemplateName';
  static const errorInvalidSignPage = 'errorInvalidSignPage';
  static const errorSignerNameRequired = 'errorSignerNameRequired';
  static const errorSignerNameTooLong = 'errorSignerNameTooLong';
  static const errorReasonTooLong = 'errorReasonTooLong';
  static const errorTypedSignatureEmpty = 'errorTypedSignatureEmpty';
  static const errorTypedSignatureTooLong = 'errorTypedSignatureTooLong';
  static const errorDrawSignatureEmpty = 'errorDrawSignatureEmpty';
  static const errorInvalidSignDocument = 'errorInvalidSignDocument';

  // Import / descarga (códigos estables; nunca texto localizado en excepciones).
  static const signatureRoleLabel = 'signatureRoleLabel';
  static const invalidPdf = 'invalidPdf';
  static const emptyPdf = 'emptyPdf';
  static const truncatedPdf = 'truncatedPdf';
  static const fileAccessFailed = 'fileAccessFailed';
  static const fileMissing = 'fileMissing';
  static const incompleteCopy = 'incompleteCopy';
  static const incompleteDownload = 'incompleteDownload';
  static const unexpectedError = 'unexpectedError';

  /// Fallos de importación externa que no merecen reintento automático.
  static bool isPermanentImportFailure(String? key) {
    return key == invalidPdf ||
        key == emptyPdf ||
        key == truncatedPdf ||
        key == fileMissing ||
        key == fileAccessFailed;
  }

  /// True si [value] es una clave conocida (no texto libre).
  static bool isKnown(String? value) {
    if (value == null || value.isEmpty) return false;
    return _known.contains(value);
  }

  static const Set<String> _known = {
    libraryLoadFailed,
    importPdfFailed,
    metadataSaveFailed,
    collectionCreateFailed,
    collectionRenameFailed,
    collectionDeleteFailed,
    collectionNameExists,
    deletePdfFailed,
    invalidUrl,
    downloading,
    savedToLibrary,
    downloadFailed,
    noPdfLink,
    timeout,
    noNetwork,
    connectionFailed,
    downloadInProgress,
    nativeDownloadFailed,
    downloadCancelled,
    multiplePdfsDetected,
    waitForExport,
    waitForSignaturesLoad,
    waitForSigning,
    signDocumentFailed,
    exportSignedFailed,
    deleteSignatureFailed,
    signaturesLoadFailed,
    signatureSaveFailed,
    templateDeleteFailed,
    signatureMoveFailed,
    needSignature,
    cancelPlacement,
    exportInProgress,
    documentUnavailable,
    documentUnavailableSign,
    signatureBusy,
    templatePartial,
    templatesLoadFailed,
    annotationsLoadFailed,
    bookmarkRemoveFailed,
    bookmarkCreateFailed,
    noteSaveFailed,
    bookmarkDeleteFailed,
    annotationSaveFailed,
    annotationUpdateFailed,
    annotationDeleteFailed,
    annotationGeometryInvalid,
    indicateTemplateName,
    errorInvalidSignPage,
    errorSignerNameRequired,
    errorSignerNameTooLong,
    errorReasonTooLong,
    errorTypedSignatureEmpty,
    errorTypedSignatureTooLong,
    errorDrawSignatureEmpty,
    errorInvalidSignDocument,
    signatureRoleLabel,
    invalidPdf,
    emptyPdf,
    truncatedPdf,
    fileAccessFailed,
    fileMissing,
    incompleteCopy,
    incompleteDownload,
    unexpectedError,
  };
}
