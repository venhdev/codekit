import 'dart:io';

import 'package:codekit_ui/src/platform/native_export_delivery.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native file share writes selected text to a temporary .txt', () async {
    final directory = await Directory.systemTemp.createTemp('codekit-share-');
    addTearDown(() => directory.delete(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    List<String>? sharedPaths;
    var shareResult = 'mock.success';
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      expect(call.method, 'getTemporaryDirectory');
      return directory.path;
    });
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      expect(call.method, 'share');
      final paths = (call.arguments as Map)['paths'];
      sharedPaths = paths == null ? null : List<String>.from(paths as List);
      return shareResult;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });

    expect(await shareFile('CodeKit diagnostic text'), isTrue);
    expect(sharedPaths, hasLength(1));
    expect(sharedPaths!.single, endsWith('.txt'));
    expect(
      await File(sharedPaths!.single).readAsString(),
      'CodeKit diagnostic text',
    );

    shareResult = '';
    expect(await shareText('Copy for another app'), isFalse);
    shareResult = 'dev.fluttercommunity.plus/share/unavailable';
    await expectLater(shareText('Copy for another app'), throwsStateError);
  });
}
