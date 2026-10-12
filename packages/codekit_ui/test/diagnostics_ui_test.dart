import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codekit_ui/src/export/export_confirmation_dialog.dart';

void main() {
  testWidgets('bubble opens records and supports selection and export choice', (
    tester,
  ) async {
    final diagnostics = CodeKitDiagnostics();
    final receipt = diagnostics.log(const LogInput(message: 'Payment failed'));
    await receipt.persistedOrNull();
    expect(
      (await diagnostics.exportRecords([receipt.recordId!])).status,
      ExportStatus.success,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => CodeKitBubble(
          diagnostics: diagnostics,
          navigatorKey: navigatorKey,
          child: child!,
        ),
        home: const Scaffold(body: Text('Application')),
      ),
    );
    expect(find.text('Application'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Payment failed'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.byTooltip('Select records'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.textContaining('1 selected'), findsOneWidget);
    await tester.tap(find.text('Export selected'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm export'), findsOneWidget);
    expect(find.text('Redacted'), findsOneWidget);
    await tester.tap(find.text('As stored'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm export'), findsNothing);
    await diagnostics.dispose();
  });

  testWidgets('confirmed COPY sends selected representation to clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExportConfirmation(
                context,
                selectedCount: 1,
                export: (representation) async =>
                    ExportResult.success(representation.name, 1),
              ),
              child: const Text('Open export'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('COPY'));
    await tester.pumpAndSettle();
    expect(copied, 'redacted');
  });

  testWidgets(
    'filter sheet exposes 1xx and Unknown and search history reuses query',
    (tester) async {
      final diagnostics = CodeKitDiagnostics();
      await diagnostics
          .log(const LogInput(message: 'Payment failed'))
          .persistedOrNull();
      await tester.pumpWidget(
        MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close sheet'), findsOneWidget);
      expect(find.text('1xx'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Payment');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search history'));
      await tester.pumpAndSettle();
      expect(find.text('Payment'), findsWidgets);
      await diagnostics.dispose();
    },
  );

  testWidgets('manual Trace capture survives closing and reopening the sheet', (
    tester,
  ) async {
    final diagnostics = CodeKitDiagnostics();
    await tester.pumpWidget(
      MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trace sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start capture'));
    await tester.pumpAndSettle();
    await diagnostics
        .log(const LogInput(message: 'Within trace'))
        .persistedOrNull();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Trace sessions'));
    await tester.pumpAndSettle();
    expect(find.text('Stop capture'), findsOneWidget);
    await tester.tap(find.text('Stop capture'));
    await tester.pumpAndSettle();
    expect(find.text('1 saved IDs'), findsOneWidget);
    await diagnostics.dispose();
  });

  testWidgets(
    'tapping a Trace session scopes the records list to its saved IDs',
    (tester) async {
      final diagnostics = CodeKitDiagnostics();
      await tester.pumpWidget(
        MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Trace sessions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start capture'));
      await tester.pumpAndSettle();
      await diagnostics
          .log(const LogInput(message: 'Captured by trace'))
          .persistedOrNull();
      await tester.tap(find.text('Stop capture'));
      await tester.pumpAndSettle();
      await diagnostics
          .log(const LogInput(message: 'Outside trace'))
          .persistedOrNull();
      await tester.tap(find.text('1 saved IDs'));
      await tester.pumpAndSettle();
      expect(find.text('Captured by trace'), findsOneWidget);
      expect(find.text('Outside trace'), findsNothing);
      expect(find.textContaining('Trace:'), findsOneWidget);
      await diagnostics.dispose();
    },
  );

  testWidgets(
    'HTTP details expose captured JSON tree and fragment copy choice',
    (tester) async {
      final diagnostics = CodeKitDiagnostics();
      await diagnostics
          .log(
            HttpInput(
              recordId: diagnostics.createRecordId(),
              requestStartedAt: DateTime.now(),
              method: 'POST',
              uri: Uri.parse('https://example.test/payments'),
              requestBody: BodySnapshot.json({
                'customer': {'email': 'person@example.test'},
              }),
              response: const HttpResponseSnapshot(statusCode: 201),
            ),
          )
          .persistedOrNull();
      await tester.pumpWidget(
        MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('POST https://example.test/payments'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Status: 201'), findsOneWidget);
      expect(find.text('Response'), findsOneWidget);
      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tree'));
      await tester.pumpAndSettle();
      expect(find.text('Root (1)'), findsOneWidget);
      await tester.tap(find.text('Copy body'));
      await tester.pumpAndSettle();
      expect(find.text('Redacted'), findsOneWidget);
      expect(find.text('As stored'), findsOneWidget);
      await diagnostics.dispose();
    },
  );

  testWidgets(
    'empty HTTP fragments hide copy actions and metadata opens on demand',
    (tester) async {
      final diagnostics = CodeKitDiagnostics();
      await diagnostics
          .log(
            HttpInput(
              recordId: diagnostics.createRecordId(),
              requestStartedAt: DateTime.now(),
              method: 'GET',
              uri: Uri.parse('https://example.test/empty'),
              response: const HttpResponseSnapshot(statusCode: 204),
            ),
          )
          .persistedOrNull();
      await tester.pumpWidget(
        MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('GET https://example.test/empty'));
      await tester.pumpAndSettle();
      expect(find.text('Copy headers'), findsNothing);
      expect(find.text('Copy body'), findsNothing);
      expect(find.textContaining('ID:'), findsNothing);
      await tester.tap(find.byTooltip('Record information'));
      await tester.pumpAndSettle();
      expect(find.text('Record information'), findsOneWidget);
      expect(find.textContaining('ID:'), findsOneWidget);
      await diagnostics.dispose();
    },
  );
}
