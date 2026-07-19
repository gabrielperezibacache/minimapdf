/// Script JS (privacidad: solo lee enlaces del DOM, sin telemetría).
abstract final class PdfLinkDetector {
  static const String scanScript = r'''
(function() {
  const urls = new Set();
  const pdfRe = /\.pdf([?#]|$)/i;
  function add(raw) {
    if (!raw) return;
    try {
      const u = new URL(raw, location.href).href;
      if (pdfRe.test(u) || /application\/pdf/i.test(u)) urls.add(u);
    } catch (e) {}
  }
  add(location.href);
  document.querySelectorAll('a[href]').forEach(a => add(a.href));
  document.querySelectorAll('embed[src], object[data], iframe[src]').forEach(el => {
    add(el.src || el.data);
  });
  return Array.from(urls);
})();
''';
}
