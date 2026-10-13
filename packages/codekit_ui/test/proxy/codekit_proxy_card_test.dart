import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('CodeKitProxyCard', () {
    testWidgets('displays DIRECT status when proxy is disabled', (
      tester,
    ) async {
      const config = DevProxyConfig(isEnabled: false);

      await tester.pumpWidget(
        buildTestableWidget(
          CodeKitProxyCard(config: config, onConfigChanged: (_) {}),
        ),
      );

      expect(find.text('Dev Proxy (Proxyman / Charles)'), findsOneWidget);
      expect(find.text('OFF: DIRECT (No proxy)'), findsOneWidget);
      final switchFinder = find.byKey(const Key('codekit-proxy-toggle'));
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets('displays active proxy address when enabled and valid', (
      tester,
    ) async {
      const config = DevProxyConfig(
        isEnabled: true,
        host: '192.168.1.100',
        port: 9090,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          CodeKitProxyCard(config: config, onConfigChanged: (_) {}),
        ),
      );

      expect(find.text('ON: PROXY 192.168.1.100:9090'), findsOneWidget);
      final switchFinder = find.byKey(const Key('codekit-proxy-toggle'));
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('toggles state when switch is tapped on valid config', (
      tester,
    ) async {
      DevProxyConfig? changedConfig;
      const config = DevProxyConfig(
        isEnabled: false,
        host: '192.168.1.100',
        port: 9090,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          CodeKitProxyCard(
            config: config,
            onConfigChanged: (val) => changedConfig = val,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('codekit-proxy-toggle')));
      await tester.pumpAndSettle();

      expect(changedConfig, isNotNull);
      expect(changedConfig!.isEnabled, isTrue);
      expect(changedConfig!.host, equals('192.168.1.100'));
    });

    testWidgets(
      'opens edit dialog when switch is tapped on unconfigured config',
      (tester) async {
        const config = DevProxyConfig(isEnabled: false, host: '', port: 9090);

        await tester.pumpWidget(
          buildTestableWidget(
            CodeKitProxyCard(config: config, onConfigChanged: (_) {}),
          ),
        );

        await tester.tap(find.byKey(const Key('codekit-proxy-toggle')));
        await tester.pumpAndSettle();

        expect(find.text('Configure Dev Proxy'), findsOneWidget);
      },
    );

    testWidgets(
      'opens edit dialog when configure button is tapped and preset updates port',
      (tester) async {
        DevProxyConfig? savedConfig;
        const config = DevProxyConfig(
          isEnabled: false,
          host: '10.0.0.1',
          port: 9090,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            CodeKitProxyCard(
              config: config,
              onConfigChanged: (val) => savedConfig = val,
            ),
          ),
        );

        // Tap configure button
        await tester.tap(find.byKey(const Key('codekit-proxy-edit-btn')));
        await tester.pumpAndSettle();

        // Dialog is displayed
        expect(find.text('Configure Dev Proxy'), findsOneWidget);
        expect(
          find.byKey(const Key('codekit-proxy-host-input')),
          findsOneWidget,
        );

        // Tap preset 8888 chip
        await tester.tap(find.byKey(const Key('codekit-preset-8888')));
        await tester.pumpAndSettle();

        final portField = tester.widget<TextField>(
          find.byKey(const Key('codekit-proxy-port-input')),
        );
        expect(portField.controller!.text, equals('8888'));

        // Tap Save
        await tester.tap(find.byKey(const Key('codekit-proxy-save-btn')));
        await tester.pumpAndSettle();

        expect(savedConfig, isNotNull);
        expect(savedConfig!.isEnabled, isTrue);
        expect(savedConfig!.port, equals(8888));
        expect(savedConfig!.host, equals('10.0.0.1'));
      },
    );

    testWidgets('shows validation error when saving invalid host or port', (
      tester,
    ) async {
      const config = DevProxyConfig(isEnabled: false, host: '', port: 9090);

      await tester.pumpWidget(
        buildTestableWidget(
          CodeKitProxyCard(config: config, onConfigChanged: (_) {}),
        ),
      );

      await tester.tap(find.byKey(const Key('codekit-proxy-edit-btn')));
      await tester.pumpAndSettle();

      // Tap Save with empty host
      await tester.tap(find.byKey(const Key('codekit-proxy-save-btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a valid host IP and port (1–65535).'),
        findsOneWidget,
      );

      // Cancel dismisses dialog
      await tester.tap(find.byKey(const Key('codekit-proxy-cancel-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Configure Dev Proxy'), findsNothing);
    });
  });
}
