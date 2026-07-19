import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/data/models/document_signature.dart';
import 'package:minimal_pdf/data/models/signature_role.dart';
import 'package:minimal_pdf/data/models/signature_type.dart';
import 'package:minimal_pdf/domain/document_hash_service.dart';
import 'package:minimal_pdf/domain/signature_manifest.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hashService = DocumentHashService();

  test('sha256Bytes es estable y hex en minúsculas', () {
    final a = hashService.sha256Bytes([1, 2, 3]);
    final b = hashService.sha256Bytes([1, 2, 3]);
    expect(a, b);
    expect(a, hasLength(64));
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('sha256File coincide con sha256Bytes del contenido', () async {
    final dir = await Directory.systemTemp.createTemp('hash_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final file = File(p.join(dir.path, 'sample.bin'));
    final bytes = List<int>.generate(64, (i) => i);
    await file.writeAsBytes(bytes);

    final fromFile = await hashService.sha256File(file.path);
    final fromBytes = hashService.sha256Bytes(bytes);
    expect(fromFile, fromBytes);
  });

  test('SignatureManifest encodePretty incluye hashes y firmas', () {
    final signature = DocumentSignature(
      id: 9,
      bookId: 1,
      pageNumber: 2,
      type: SignatureType.typed,
      signerName: 'Ana',
      typedText: 'Ana',
      role: SignatureRole.witness,
      signingOrder: 3,
      signedAt: DateTime.utc(2026, 7, 19, 15),
    );

    final manifest = SignatureManifest(
      version: 1,
      exportedAt: DateTime.utc(2026, 7, 19, 16),
      sourceFileName: 'origen.pdf',
      sourceSha256: 'a' * 64,
      signedFileName: 'origen_firmado.pdf',
      signedSha256: 'b' * 64,
      signatures: [signature],
    );

    final json = manifest.encodePretty();
    expect(json, contains('origen.pdf'));
    expect(json, contains('witness'));
    expect(json, contains('"signingOrder": 3'));
    expect(manifest.matchesSignedHash('B' * 64), isTrue);
    expect(manifest.matchesSignedHash('c' * 64), isFalse);

    final decoded = SignatureManifest.decode(json);
    expect(decoded.signatures.first.signingOrder, 3);
    expect(decoded.sourceFileName, 'origen.pdf');
  });
}
