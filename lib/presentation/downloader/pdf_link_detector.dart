/// Script JS (privacidad: solo lee enlaces del DOM, sin telemetría).
abstract final class PdfLinkDetector {
  static const String scanScript = r'''
(function() {
  const urls = new Set();
  const pdfExt = /\.pdf([?#]|$)/i;
  const pdfPath = /(^|\/)pdf(\/|$)/i;
  function looksPdf(u) {
    try {
      const url = new URL(u);
      if (pdfExt.test(url.pathname)) return true;
      if (/application\/pdf/i.test(url.href)) return true;
      if (pdfPath.test(url.pathname) && url.pathname.toLowerCase() !== '/pdf') {
        return true;
      }
    } catch (e) {}
    return false;
  }
  function add(raw) {
    if (!raw) return;
    try {
      const u = new URL(raw, location.href).href;
      if (looksPdf(u)) urls.add(u);
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
