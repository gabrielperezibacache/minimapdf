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

  void mockChannels({
    List<String> initialPaths = const [],
    void Function(MockStreamHandlerEventSink events)? onListen,
  }) {
    var initialIndex = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
      methodCalls.add(call);
      if (call.method == 'getInitialPdfPath') {
        if (initialIndex >= initialPaths.length) return null;
        return initialPaths[initialIndex++];
      }
      if (call.method == 'openDefaultAppsSettings') return true;
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) => onListen?.call(events),
      ),
    );
  }

  test('start encola la ruta inicial del PDF', () async {
    mockChannels(initialPaths: ['/tmp/externo.pdf']);

    final service = ExternalPdfOpenService();
    var notified = 0;
    service.addListener(() => notified++);

    await service.start();
    await Future<void>.delayed(Duration.zero);

    expect(service.hasQueued, isTrue);
    expect(service.takeNext(), '/tmp/externo.pdf');
    expect(service.hasQueued, isFalse);
    expect(notified, greaterThan(0));
    expect(methodCalls.map((c) => c.method), contains('getInitialPdfPath'));

    service.dispose();
  });

  test('start drena varias rutas iniciales', () async {
    mockChannels(initialPaths: ['/tmp/a.pdf', '/tmp/b.pdf']);

    final service = ExternalPdfOpenService();
    await service.start();

    expect(service.queuedPaths, ['/tmp/a.pdf', '/tmp/b.pdf']);
    service.dispose();
  });

  test('deduplica la misma ruta en ventana corta', () async {
    mockChannels(
      initialPaths: ['/tmp/mismo.pdf'],
      onListen: (events) => events.success('/tmp/mismo.pdf'),
    );

    final service = ExternalPdfOpenService();
    await service.start();
    await Future<void>.delayed(Duration.zero);

    expect(service.queuedPaths, ['/tmp/mismo.pdf']);
    service.dispose();
  });

  test('requeue vuelve a poner el path al frente', () async {
    mockChannels();

    final service = ExternalPdfOpenService();
    await service.start();
    service.requeue('/b.pdf');
    service.requeue('/a.pdf');
    expect(service.takeNext(), '/a.pdf');
    expect(service.takeNext(), '/b.pdf');
    service.dispose();
  });

  test('queueLast encola al final sin duplicar', () async {
    mockChannels();

    final service = ExternalPdfOpenService();
    await service.start();
    service.requeue('/primero.pdf');
    service.queueLast('/reintento.pdf');
    service.queueLast('/reintento.pdf');
    expect(service.takeNext(), '/primero.pdf');
    expect(service.takeNext(), '/reintento.pdf');
    expect(service.hasQueued, isFalse);
    service.dispose();
  });

  test('openDefaultAppsSettings invoca el canal nativo', () async {
    mockChannels();

    final service = ExternalPdfOpenService();
    final opened = await service.openDefaultAppsSettings();

    expect(opened, isTrue);
    expect(
      methodCalls.where((c) => c.method == 'openDefaultAppsSettings'),
      hasLength(1),
    );
    service.dispose();
  });

  test('openDefaultAppsSettings tolera plugin ausente', () async {
    final service = ExternalPdfOpenService();
    final opened = await service.openDefaultAppsSettings();
    expect(opened, isFalse);
    service.dispose();
  });
}
