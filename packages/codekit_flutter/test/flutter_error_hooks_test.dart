import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_flutter/codekit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'records Flutter and platform errors, chains and restores handlers',
    () async {
      final dispatcher = PlatformDispatcher.instance;
      final originalFlutter = FlutterError.onError;
      final originalPlatform = dispatcher.onError;
      var flutterCalls = 0;
      var platformCalls = 0;
      FlutterError.onError = (_) => flutterCalls++;
      dispatcher.onError = (_, _) {
        platformCalls++;
        return true;
      };
      final appFlutter = FlutterError.onError;
      final appPlatform = dispatcher.onError;
      final diagnostics = CodeKitDiagnostics();
      try {
        final hooks = CodeKitFlutterErrorHooks.install(diagnostics);
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError('framework failure'),
            stack: StackTrace.current,
            library: 'sample',
          ),
        );
        expect(
          dispatcher.onError!(StateError('root failure'), StackTrace.current),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        final page = await diagnostics.query(RecordQuery());
        expect(page.records.length, 2);
        expect(
          page.records.map((r) => r.source),
          containsAll(['sample', 'PlatformDispatcher']),
        );
        expect(flutterCalls, 1);
        expect(platformCalls, 1);
        hooks.dispose();
        expect(identical(FlutterError.onError, appFlutter), isTrue);
        expect(identical(dispatcher.onError, appPlatform), isTrue);
        hooks.dispose();
      } finally {
        FlutterError.onError = originalFlutter;
        dispatcher.onError = originalPlatform;
        await diagnostics.dispose();
      }
    },
  );

  test('dispose does not replace handlers installed later by the app', () {
    final dispatcher = PlatformDispatcher.instance;
    final originalFlutter = FlutterError.onError;
    final originalPlatform = dispatcher.onError;
    final diagnostics = CodeKitDiagnostics();
    try {
      final hooks = CodeKitFlutterErrorHooks.install(diagnostics);
      expect(
        () => CodeKitFlutterErrorHooks.install(diagnostics),
        throwsStateError,
      );
      void laterFlutter(FlutterErrorDetails _) {}
      bool laterPlatform(Object error, StackTrace stack) => false;
      FlutterError.onError = laterFlutter;
      dispatcher.onError = laterPlatform;
      hooks.dispose();
      expect(identical(FlutterError.onError, laterFlutter), isTrue);
      expect(identical(dispatcher.onError, laterPlatform), isTrue);
    } finally {
      FlutterError.onError = originalFlutter;
      dispatcher.onError = originalPlatform;
      diagnostics.dispose();
    }
  });
}
