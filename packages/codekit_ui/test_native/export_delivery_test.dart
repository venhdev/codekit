import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/src/export/export_confirmation_dialog.dart';
import 'package:codekit_ui/src/platform/native_export_delivery.dart';
import 'package:flutter/material.dart';
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

  testWidgets(
    'dismissed share stays open and unavailable share reports error',
    (tester) async {
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      var shareResult = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        (call) async {
          expect(call.method, 'share');
          return shareResult;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          shareChannel,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showExportConfirmation(
                  context,
                  export: (_) async => const ExportResult.success('record', 1),
                ),
                child: const Text('Open export'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm export'), findsOneWidget);
      expect(find.text('Shared diagnostics'), findsNothing);

      shareResult = 'dev.fluttercommunity.plus/share/unavailable';
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm export'), findsOneWidget);
      expect(find.text('Share unavailable'), findsOneWidget);
    },
  );
}
