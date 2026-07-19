import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/services/external_pdf_open_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('minimal_pdf/external_open');
  const eventChannel = EventChannel('minimal_pdf/external_open/events');

  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = <MethodCall>[];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  test('start emite la ruta inicial del PDF', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodCalls.add(call);
      if (call.method == 'getInitialPdfPath') {
        return '/tmp/externo.pdf';
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {},
      ),
    );

    final service = ExternalPdfOpenService();
    final paths = <String>[];
    final sub = service.incomingPaths.listen(paths.add);

    await service.start();
    await Future<void>.delayed(Duration.zero);

    expect(paths, ['/tmp/externo.pdf']);
    expect(methodCalls.map((c) => c.method), contains('getInitialPdfPath'));

    await sub.cancel();
    await service.dispose();
  });

  test('openDefaultAppsSettings invoca el canal nativo', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodCalls.add(call);
      return true;
    });

    final service = ExternalPdfOpenService();
    final opened = await service.openDefaultAppsSettings();

    expect(opened, isTrue);
    expect(methodCalls.single.method, 'openDefaultAppsSettings');
    await service.dispose();
  });

  test('openDefaultAppsSettings tolera plugin ausente', () async {
    final service = ExternalPdfOpenService();
    final opened = await service.openDefaultAppsSettings();
    expect(opened, isFalse);
    await service.dispose();
  });
}
