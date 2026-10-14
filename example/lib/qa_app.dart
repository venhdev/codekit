import 'dart:async';

import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';

import 'qa_actions.dart';
import 'qa_services.dart';

final class QaApp extends StatefulWidget {
  const QaApp({super.key, required this.services});

  final QaServices services;

  @override
  State<QaApp> createState() => _QaAppState();
}

final class _QaAppState extends State<QaApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  late final QaActions actions;
  late final CodeKitViewerSettings viewerSettings;

  @override
  void initState() {
    super.initState();
    actions = QaActions(widget.services);
    viewerSettings = CodeKitViewerSettings(
      allowRuntimeRecordModeChanges: true,
      devProxyProvider: () => widget.services.devProxyConfig,
      onDevProxyConfigChanged: (updated) {
        widget.services.devProxyConfig = updated;
      },
      setupDetails: [
        CodeKitViewerSetupDetail(
          label: 'Storage',
          value: widget.services.storageDescription,
        ),
        const CodeKitViewerSetupDetail(
          label: 'Dio',
          value: 'Interceptor attached',
        ),
        const CodeKitViewerSetupDetail(
          label: 'package:http',
          value: 'Wrapped; headers-only body',
        ),
        CodeKitViewerSetupDetail(
          label: 'Flutter error hooks',
          value: widget.services.errorHooks == null
              ? 'Not installed'
              : 'Installed',
        ),
      ],
    );
  }

  @override
  void dispose() {
    unawaited(widget.services.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CodeKit QA',
    navigatorKey: navigatorKey,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    builder: (context, child) => CodeKitBubble(
      diagnostics: widget.services.diagnostics,
      navigatorKey: navigatorKey,
      viewerSettings: viewerSettings,
      child: child!,
    ),
    home: _QaHome(
      actions: actions,
      openViewer: () => navigatorKey.currentState?.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CodeKitDiagnosticsScreen(
            diagnostics: widget.services.diagnostics,
            viewerSettings: viewerSettings,
          ),
        ),
      ),
    ),
  );
}

final class _QaHome extends StatefulWidget {
  const _QaHome({required this.actions, required this.openViewer});

  final QaActions actions;
  final VoidCallback openViewer;

  @override
  State<_QaHome> createState() => _QaHomeState();
}

final class _QaHomeState extends State<_QaHome> {
  bool busy = false;
  String? lastAction;

  Future<void> run(String label, Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      lastAction = 'Running $label...';
    });
    try {
      await action();
      if (mounted) setState(() => lastAction = 'Completed: $label');
    } catch (error) {
      if (mounted) {
        setState(() => lastAction = 'Failed: $label');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CodeKit integration QA')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Use the CodeKit bubble or open the viewer directly. API scenarios '
          'require internet access and write captured records to native Drift.',
        ),
        const SizedBox(height: 8),
        if (lastAction != null)
          Text(lastAction!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: busy ? null : widget.openViewer,
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Open diagnostics viewer'),
        ),
        _section('Seed data', [
          _button('Log level matrix', () => widget.actions.seedLogMatrix()),
          _button(
            'Sensitive HTTP record',
            () => widget.actions.seedSensitiveRecords(),
          ),
          _button(
            'Generate 120 records',
            () => widget.actions.generatePaginationDataset(),
          ),
          _button('Start trace', () => widget.actions.startTrace()),
          _button('Stop trace', () => widget.actions.stopTrace()),
          _button(
            'Clear records',
            () => widget.actions.clearRecords(),
            destructive: true,
          ),
        ]),
        _section('Dio', [
          _button('httpbin JSON', () => widget.actions.runDioHealth()),
          _button('Open-Meteo weather', () => widget.actions.runDioWeather()),
          _button(
            'DummyJSON product',
            () => widget.actions.runDioProductDetail(),
          ),
          _button('HTTP 404', () => widget.actions.runDioStatus(404)),
          _button('HTTP 500', () => widget.actions.runDioStatus(500)),
          _button('Redirect', () => widget.actions.runDioRedirect()),
          _button('Delayed response', () => widget.actions.runDioDelay()),
          _button(
            'Response headers',
            () => widget.actions.runDioResponseHeaders(),
          ),
        ]),
        _section('package:http', [
          _button(
            'Currency rates',
            () => widget.actions.runHttpCurrencyRates(),
          ),
          _button(
            'Currency conversion',
            () => widget.actions.runHttpCurrencyRate(),
          ),
          _button('Product list', () => widget.actions.runHttpProducts()),
          _button(
            'Product search',
            () => widget.actions.runHttpProductSearch(),
          ),
          _button('Product CRUD', () => widget.actions.runHttpProductCrud()),
          _button('Posts list', () => widget.actions.runHttpPosts()),
          _button('Posts CRUD', () => widget.actions.runHttpPostCrud()),
        ]),
        _section('Flutter integration', [
          _button(
            'Trigger Flutter error',
            () => widget.actions.triggerFlutterError(),
          ),
          _button(
            'Trigger platform error',
            () => widget.actions.triggerPlatformError(),
          ),
          _button(
            'Run safe API suite',
            () => widget.actions.runAllSafeApiScenarios(),
          ),
        ]),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    ),
  );

  Widget _button(
    String label,
    Future<void> Function() action, {
    bool destructive = false,
  }) => OutlinedButton(
    onPressed: busy ? null : () => run(label, action),
    style: destructive
        ? OutlinedButton.styleFrom(foregroundColor: Colors.red)
        : null,
    child: Text(label),
  );
}
