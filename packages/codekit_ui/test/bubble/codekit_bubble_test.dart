import 'dart:async';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeKitBubble - Trigger Modes, Idle Opacity & Edge Docking', () {
    testWidgets(
      'CodeKitBubble defaults to BubbleTriggerMode.shakeToToggle and starts hidden',
      (tester) async {
        final diagnostics = CodeKitDiagnostics();
        final navigatorKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CodeKitBubble(
              navigatorKey: navigatorKey,
              diagnostics: diagnostics,
              child: child!,
            ),
            home: const Scaffold(body: Text('Home Screen')),
          ),
        );

        // Hidden by default
        expect(find.byIcon(Icons.bug_report_outlined), findsNothing);

        await diagnostics.dispose();
      },
    );

    testWidgets('BubbleTriggerMode.immediate renders bubble on startup', (
      tester,
    ) async {
      final diagnostics = CodeKitDiagnostics();
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => CodeKitBubble(
            navigatorKey: navigatorKey,
            diagnostics: diagnostics,
            triggerMode: BubbleTriggerMode.immediate,
            child: child!,
          ),
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
      expect(
        find.byKey(const Key('codekit-bubble-docked-indicator')),
        findsNothing,
      );

      await diagnostics.dispose();
    });

    testWidgets(
      'BubbleTriggerMode.shakeToToggle starts hidden and toggles on shakeStream',
      (tester) async {
        final diagnostics = CodeKitDiagnostics();
        final navigatorKey = GlobalKey<NavigatorState>();
        final shakeController = StreamController<void>.broadcast();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CodeKitBubble(
              navigatorKey: navigatorKey,
              diagnostics: diagnostics,
              triggerMode: BubbleTriggerMode.shakeToToggle,
              shakeStream: shakeController.stream,
              child: child!,
            ),
            home: const Scaffold(body: Text('Home Screen')),
          ),
        );

        // Initially hidden
        expect(find.byIcon(Icons.bug_report_outlined), findsNothing);

        // First shake: reveals bubble
        shakeController.add(null);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);

        // Second shake: hides bubble
        shakeController.add(null);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.bug_report_outlined), findsNothing);

        await shakeController.close();
        await diagnostics.dispose();
      },
    );

    testWidgets('Keyboard shortcut Ctrl+Shift+D toggles shakeToToggle bubble', (
      tester,
    ) async {
      final diagnostics = CodeKitDiagnostics();
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => CodeKitBubble(
            navigatorKey: navigatorKey,
            diagnostics: diagnostics,
            triggerMode: BubbleTriggerMode.shakeToToggle,
            child: child!,
          ),
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );

      expect(find.byIcon(Icons.bug_report_outlined), findsNothing);

      // Simulate pressing Ctrl+Shift+D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);

      await diagnostics.dispose();
    });

    testWidgets(
      'Bubble dims to idleOpacity after idleTimeout and wakes on tap',
      (tester) async {
        final diagnostics = CodeKitDiagnostics();
        final navigatorKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CodeKitBubble(
              navigatorKey: navigatorKey,
              diagnostics: diagnostics,
              triggerMode: BubbleTriggerMode.immediate,
              idleTimeout: const Duration(seconds: 3),
              idleOpacity: 0.25,
              child: child!,
            ),
            home: const Scaffold(body: Text('Home Screen')),
          ),
        );

        // Initially full opacity
        AnimatedOpacity opacityWidget() {
          return tester.widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(Positioned),
              matching: find.byType(AnimatedOpacity),
            ),
          );
        }

        expect(opacityWidget().opacity, 1.0);

        // Advance time by 3 seconds
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 300));
        expect(opacityWidget().opacity, 0.25);

        // Tap down on the bubble to wake it up without opening the viewer
        final gesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.bug_report_outlined)),
        );
        await tester.pump();
        expect(opacityWidget().opacity, 1.0);
        await gesture.up();
        await tester.pump();

        await diagnostics.dispose();
      },
    );

    testWidgets(
      'Dragging bubble close to screen edge docks and minimizes to 8px indicator',
      (tester) async {
        final diagnostics = CodeKitDiagnostics();
        final navigatorKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CodeKitBubble(
              navigatorKey: navigatorKey,
              diagnostics: diagnostics,
              triggerMode: BubbleTriggerMode.immediate,
              child: child!,
            ),
            home: const Scaffold(body: Text('Home Screen')),
          ),
        );

        final bubbleFinder = find.byIcon(Icons.bug_report_outlined);
        expect(bubbleFinder, findsOneWidget);

        // Drag towards the right edge
        await tester.drag(bubbleFinder, const Offset(300, 0));
        await tester.pumpAndSettle();

        // Now docked indicator is shown
        expect(
          find.byKey(const Key('codekit-bubble-docked-indicator')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.bug_report_outlined), findsNothing);

        // Tap the docked indicator to undock
        await tester.tap(
          find.byKey(const Key('codekit-bubble-docked-indicator')),
        );
        await tester.pumpAndSettle();

        // Returns to full round bubble
        expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
        expect(
          find.byKey(const Key('codekit-bubble-docked-indicator')),
          findsNothing,
        );

        await diagnostics.dispose();
      },
    );
  });
}
