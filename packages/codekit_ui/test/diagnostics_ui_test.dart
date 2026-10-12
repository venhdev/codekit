import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codekit_ui/src/export/export_confirmation_dialog.dart';
import 'package:codekit_ui/src/record_details/record_details_screen.dart';
import 'package:codekit_ui/src/records/records_controller.dart';
import 'package:codekit_ui/src/search_history/search_history_store.dart';
import 'package:codekit_ui/src/shared/codekit_bottom_sheet.dart';

void main() {
  testWidgets('long HTTP summary keeps tabs visible on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final diagnostics = CodeKitDiagnostics();
    final record = DiagnosticRecord(
      id: 'forecast',
      recordedAt: DateTime.utc(2026),
      recordMode: RecordMode.storeRaw,
      payload: HttpPayload(
        requestStartedAt: DateTime.utc(2026),
        method: 'GET',
        uri: Uri.https('example.test', '/v1/forecast', {
          'latitude': '10.8231',
          'hourly': 'temperature,precipitation',
        }),
        response: const HttpResponseSnapshot(statusCode: 503),
        error: DiagnosticError(
          type: 'DioException',
          message: List.filled(50, 'Service unavailable.').join(' '),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailsScreen(diagnostics: diagnostics, record: record),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.byType(TabBar)).dy, lessThan(640));
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs.cast<Tab>();
    expect(tabs.map((tab) => tab.text), ['Summary', 'Request', 'Response']);
    final summaryScrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Copy cURL'),
      200,
      scrollable: summaryScrollable,
    );
    expect(tester.getBottomLeft(find.byType(TabBar)).dy, lessThan(640));
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsWidgets);
    await tester.tap(find.text('Response'));
    await tester.pumpAndSettle();
    expect(find.text('Body'), findsWidgets);
    expect(tester.takeException(), isNull);
    await diagnostics.dispose();
  });

  test(
    'search, filters, reload and Trace scope preserve selected IDs',
    () async {
      final diagnostics = CodeKitDiagnostics();
      final receipt = diagnostics.log(const LogInput(message: 'selected'));
      await receipt.persistedOrNull();
      final history = SearchHistoryStore();
      final controller = RecordsController(diagnostics, history);
      await controller.reload();
      controller.toggleSelected(receipt.recordId!);
      await controller.submitSearch('no results', false);
      expect(controller.records, isEmpty);
      expect(controller.selectedIds, {receipt.recordId});
      await controller.applyFilters(
        statuses: {},
        durations: {},
        recordTypes: {DiagnosticRecordType.http},
      );
      expect(controller.selectedIds, {receipt.recordId});
      await controller.reload();
      await controller.setTraceScope([]);
      await controller.clearTraceScope();
      expect(controller.selectedIds, {receipt.recordId});
      controller.dispose();
      history.dispose();
      await diagnostics.dispose();
    },
  );

  test(
    'checkbox selects only loaded IDs and preserves selection outside the list',
    () async {
      final diagnostics = CodeKitDiagnostics();
      for (var index = 0; index < 105; index++) {
        await diagnostics
            .log(LogInput(message: 'record $index'))
            .persistedOrNull();
      }
      final history = SearchHistoryStore();
      final controller = RecordsController(diagnostics, history);
      await controller.reload();
      expect(controller.records, hasLength(100));
      expect(controller.resultsLabel, '100+ results');
      expect(controller.visibleSelection, isFalse);
      controller.toggleVisibleSelection();
      expect(controller.selectedIds, hasLength(100));
      expect(controller.visibleSelection, isTrue);
      await controller.loadMore();
      expect(controller.visibleSelection, isNull);
      expect(controller.selectedIds, hasLength(100));
      controller.toggleVisibleSelection();
      expect(controller.selectedIds, hasLength(105));
      final hiddenIds = Set.of(controller.selectedIds);
      await controller.submitSearch('record 104', false);
      expect(controller.visibleSelection, isTrue);
      controller.toggleVisibleSelection();
      expect(controller.selectedIds, hasLength(104));
      expect(controller.visibleSelection, isFalse);
      controller.toggleVisibleSelection();
      expect(controller.selectedIds, hiddenIds);
      await controller.submitSearch('no results', false);
      expect(controller.visibleSelection, isFalse);
      controller.toggleVisibleSelection();
      expect(controller.selectedIds, hiddenIds);
      controller.clearSelection();
      expect(controller.selectedIds, isEmpty);
      controller.dispose();
      history.dispose();
      await diagnostics.dispose();
    },
  );

  testWidgets(
    'selection actions fit one row and export/delete hidden selected IDs',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final diagnostics = CodeKitDiagnostics();
      for (final message in ['first', 'second', 'unselected']) {
        await diagnostics.log(LogInput(message: message)).persistedOrNull();
      }
      await tester.pumpWidget(
        MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'unselected');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      final checkboxCenter = tester.getCenter(find.byType(Checkbox));
      final shareCenter = tester.getCenter(
        find.widgetWithText(FilledButton, 'Share'),
      );
      final deleteCenter = tester.getCenter(
        find.byTooltip('Delete selected records'),
      );
      expect(shareCenter.dy, checkboxCenter.dy);
      expect(deleteCenter.dy, checkboxCenter.dy);
      expect(shareCenter.dx, greaterThan(checkboxCenter.dx));
      expect(deleteCenter.dx, greaterThan(shareCenter.dx));
      expect(find.text('All matching'), findsNothing);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(find.text('2 records selected'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete selected records'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 records?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await diagnostics.query(RecordQuery())).records, hasLength(3));
      await tester.tap(find.byTooltip('Delete selected records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        (await diagnostics.query(RecordQuery())).records.single.payload,
        isA<LogPayload>().having((p) => p.message, 'message', 'unselected'),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Share'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await diagnostics.dispose();
    },
  );

  testWidgets(
    'viewer follows system and overrides light/dark in settings and details',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final diagnostics = CodeKitDiagnostics();
      await diagnostics
          .log(const LogInput(message: 'theme record'))
          .persistedOrNull();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: CodeKitDiagnosticsScreen(diagnostics: diagnostics),
        ),
      );
      await tester.pumpAndSettle();
      Brightness brightness(Finder finder) =>
          Theme.of(tester.element(finder)).brightness;
      expect(brightness(find.text('CodeKit')), Brightness.dark);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('System'), findsOneWidget);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(brightness(find.text('CodeKit settings')), Brightness.light);
      expect(brightness(find.text('CodeKit')), Brightness.light);
      final sheetMaterial = find
          .descendant(
            of: find.byType(CodeKitBottomSheet),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.widget<Material>(sheetMaterial).color,
        Theme.of(tester.element(find.text('CodeKit settings')))
            .colorScheme
            .surfaceContainerLow,
      );
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(brightness(find.text('CodeKit settings')), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(find.text('CodeKit settings')), Brightness.dark);
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(brightness(find.text('CodeKit settings')), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(find.text('CodeKit settings')), Brightness.dark);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.tap(find.text('theme record'));
      await tester.pumpAndSettle();
      expect(brightness(find.text('Log details')), Brightness.dark);
      await diagnostics.dispose();
    },
  );

  testWidgets(
    'bubble retains viewer theme across reopening and leaves host theme intact',
    (tester) async {
      final diagnostics = CodeKitDiagnostics();
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData.light(),
          builder: (context, child) => CodeKitBubble(
            navigatorKey: navigatorKey,
            diagnostics: diagnostics,
            child: child!,
          ),
          home: const Scaffold(body: Text('Host screen')),
        ),
      );
      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Host screen'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('CodeKit'))).brightness,
        Brightness.dark,
      );
      await diagnostics.dispose();
    },
  );

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
    await tester.longPress(find.text('Payment failed'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('1 selected'), findsWidgets);
    await tester.tap(find.text('Share'));
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
    final copy = find.widgetWithText(OutlinedButton, 'COPY');
    final share = find.widgetWithText(FilledButton, 'SHARE');
    expect(copy, findsOneWidget);
    expect(share, findsOneWidget);
    expect(tester.getSize(copy).width, tester.getSize(share).width);
    expect(
      tester.getTopLeft(find.text('Share as file (.txt)')).dy,
      greaterThan(tester.getBottomRight(share).dy),
    );
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
      expect(find.byTooltip('Close sheet'), findsNothing);
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

  testWidgets('selection keeps search and filters and selects listed records', (
    tester,
  ) async {
    final diagnostics = CodeKitDiagnostics();
    for (final message in ['match one', 'match two', 'outside']) {
      await diagnostics.log(LogInput(message: message)).persistedOrNull();
    }
    await tester.pumpWidget(
      MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
    );
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'match');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('match one'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isNull);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Filters active'), findsOneWidget);
    expect(find.text('match one'), findsOneWidget);
    expect(find.text('match two'), findsOneWidget);
    expect(find.text('outside'), findsNothing);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsWidgets);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await diagnostics.dispose();
  });

  testWidgets('bottom sheet closes by tapping outside', (tester) async {
    final diagnostics = CodeKitDiagnostics();
    await tester.pumpWidget(
      MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsNothing);
    await diagnostics.dispose();
  });

  testWidgets('settings exposes opt-in record mode and read-only setup', (
    tester,
  ) async {
    final diagnostics = CodeKitDiagnostics(
      redactionPolicy: RedactionPolicy(
        rules: [
          HeaderRedactionRule(['x-qa-secret']),
          BodyFieldRedactionRule(['password']),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CodeKitDiagnosticsScreen(
          diagnostics: diagnostics,
          viewerSettings: const CodeKitViewerSettings(
            allowRuntimeRecordModeChanges: true,
            setupDetails: [
              CodeKitViewerSetupDetail(
                label: 'Storage',
                value: 'Drift (persistent)',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Drift (persistent)'), findsWidgets);
    expect(find.text('Headers: x-qa-secret'), findsOneWidget);
    expect(find.text('Body fields: password'), findsOneWidget);
    await tester.tap(find.text('Redact before recording'));
    await tester.pumpAndSettle();
    expect(diagnostics.recordMode, RecordMode.redactBeforeRecording);
    await diagnostics.dispose();
  });

  testWidgets('manual Trace capture survives closing and reopening the sheet', (
    tester,
  ) async {
    final diagnostics = CodeKitDiagnostics();
    await tester.pumpWidget(
      MaterialApp(home: CodeKitDiagnosticsScreen(diagnostics: diagnostics)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start Trace'));
    await tester.pumpAndSettle();
    await diagnostics
        .log(const LogInput(message: 'Within trace'))
        .persistedOrNull();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Trace · 1 IDs'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop Trace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trace off'));
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
      await tester.tap(find.byTooltip('Start Trace'));
      await tester.pumpAndSettle();
      await diagnostics
          .log(const LogInput(message: 'Captured by trace'))
          .persistedOrNull();
      await tester.tap(find.byTooltip('Stop Trace'));
      await tester.pumpAndSettle();
      await diagnostics
          .log(const LogInput(message: 'Outside trace'))
          .persistedOrNull();
      await tester.tap(find.text('Trace off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 saved IDs'));
      await tester.pumpAndSettle();
      expect(find.text('Captured by trace'), findsOneWidget);
      expect(find.text('Outside trace'), findsNothing);
      expect(find.textContaining('Trace:'), findsOneWidget);
      expect(
        tester.getTopRight(find.text('1 results')).dx,
        lessThan(tester.getTopLeft(find.textContaining('Trace:')).dx),
      );
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
      expect(find.text('Summary'), findsOneWidget);
      final detailsColumn = find
          .ancestor(of: find.byType(TabBar), matching: find.byType(Column))
          .first;
      expect(
        tester.widget<Column>(detailsColumn).crossAxisAlignment,
        CrossAxisAlignment.stretch,
      );
      await tester.tap(find.text('Request'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile).first)
            .initiallyExpanded,
        isFalse,
      );
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile).at(1))
            .initiallyExpanded,
        isTrue,
      );
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
