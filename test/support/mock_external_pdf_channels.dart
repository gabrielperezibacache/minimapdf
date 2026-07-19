import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evita MissingPluginException en tests de widget al montar LibraryScreen.
void mockExternalPdfOpenChannels({String? initialPdfPath}) {
  const methodChannel = MethodChannel('minimal_pdf/external_open');
  const eventChannel = EventChannel('minimal_pdf/external_open/events');

  var consumedInitial = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methodChannel, (call) async {
    switch (call.method) {
      case 'getInitialPdfPath':
        if (consumedInitial || initialPdfPath == null) return null;
        consumedInitial = true;
        return initialPdfPath;
      case 'openDefaultAppsSettings':
        return true;
      default:
        return null;
    }
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    eventChannel,
    MockStreamHandler.inline(
      onListen: (arguments, events) {},
    ),
  );
}

void clearExternalPdfOpenChannelMocks() {
  const methodChannel = MethodChannel('minimal_pdf/external_open');
  const eventChannel = EventChannel('minimal_pdf/external_open/events');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(methodChannel, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(eventChannel, null);
}
