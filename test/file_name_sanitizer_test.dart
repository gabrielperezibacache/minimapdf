import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/utils/file_name_sanitizer.dart';

void main() {
  group('FileNameSanitizer', () {
    test('limpia caracteres inválidos y fuerza .pdf', () {
      expect(
        FileNameSanitizer.sanitize('Mi Libro: Final?.PDF'),
        'Mi_Libro_Final.pdf',
      );
    });

    test('usa fallback si el nombre queda vacío', () {
      expect(FileNameSanitizer.sanitize('???'), 'documento.pdf');
      expect(FileNameSanitizer.sanitize('CON.pdf'), 'documento_CON.pdf');
      expect(FileNameSanitizer.sanitize('nul'), 'documento_nul.pdf');
    });

    test('uniqueName añade sufijo ante colisión', () {
      final existing = {'informe.pdf', 'informe_2.pdf'};
      expect(
        FileNameSanitizer.uniqueName('informe.pdf', existing),
        'informe_3.pdf',
      );
    });

    test('elimina puntos/guiones bajos finales y nombres solo-puntos', () {
      expect(FileNameSanitizer.sanitize('informe.'), 'informe.pdf');
      expect(FileNameSanitizer.sanitize('...'), 'documento.pdf');
      expect(FileNameSanitizer.sanitize('test._'), 'test.pdf');
    });
  });
}
