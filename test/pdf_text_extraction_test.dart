import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  test('Syncfusion extrae texto y bounds de un PDF generado', () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Hola Mundo'),
              pw.SizedBox(height: 20),
              pw.Text('Segunda linea de texto'),
            ],
          ),
        ),
      ),
    );
    final bytes = await doc.save();

    final pdf = sf.PdfDocument(inputBytes: bytes);
    final size = pdf.pages[0].size;
    final extractor = sf.PdfTextExtractor(pdf);
    final lines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    pdf.dispose();

    expect(size.width, greaterThan(0));
    expect(lines, isNotEmpty);
    final allText = lines.map((l) => l.text).join(' ');
    expect(allText, contains('Hola Mundo'));
    expect(allText, contains('Segunda'));

    // Los bounds están dentro de la página (coords en puntos, origen arriba-izq).
    for (final line in lines) {
      expect(line.bounds.left, greaterThanOrEqualTo(-1));
      expect(line.bounds.top, greaterThanOrEqualTo(-1));
      expect(line.bounds.right, lessThanOrEqualTo(size.width + 1));
      expect(line.bounds.bottom, lessThanOrEqualTo(size.height + 1));
      expect(line.wordCollection, isNotEmpty);
    }

    // La primera línea debe estar por encima de la segunda.
    expect(lines.first.bounds.top, lessThan(lines.last.bounds.top));
  });
}
