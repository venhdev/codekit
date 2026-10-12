import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../export/http_fragment_copy_dialog.dart';

class RecordDetailsScreen extends StatelessWidget {
  const RecordDetailsScreen({
    super.key,
    required this.diagnostics,
    required this.record,
  });

  final CodeKitDiagnostics diagnostics;
  final DiagnosticRecord record;

  @override
  Widget build(BuildContext context) {
    final payload = record.payload;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          payload is HttpPayload
              ? 'HTTP ${payload.method} ${payload.uri.path}'
              : 'Log details',
        ),
        actions: [
          IconButton(
            tooltip: 'Record information',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Record information'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText('ID: ${record.id}'),
                    Text('Recorded: ${record.recordedAt.toLocal()}'),
                    Text('Record mode: ${record.recordMode.name}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: payload is HttpPayload
          ? _HttpDetails(
              diagnostics: diagnostics,
              record: record,
              payload: payload,
            )
          : _LogDetails(record: record, payload: payload as LogPayload),
    );
  }
}

class _LogDetails extends StatelessWidget {
  const _LogDetails({required this.record, required this.payload});

  final DiagnosticRecord record;
  final LogPayload payload;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      if (record.source != null) Text('Source: ${record.source}'),
      Text(
        payload.level.name.toUpperCase(),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      SelectableText(payload.message),
      if (payload.error != null)
        SelectableText('${payload.error!.type}: ${payload.error!.message}'),
      if (payload.stackTrace != null) SelectableText(payload.stackTrace!),
      if (payload.error?.stackTrace != null)
        SelectableText(payload.error!.stackTrace!),
      if (record.context != null) ...[
        const Divider(),
        Text('Context', style: Theme.of(context).textTheme.titleMedium),
        SelectableText(
          const JsonEncoder.withIndent('  ').convert(record.context),
        ),
      ],
    ],
  );
}

class _HttpDetails extends StatelessWidget {
  const _HttpDetails({
    required this.diagnostics,
    required this.record,
    required this.payload,
  });

  final CodeKitDiagnostics diagnostics;
  final DiagnosticRecord record;
  final HttpPayload payload;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabBar(
          tabs: [
            Tab(text: 'Summary'),
            Tab(text: 'Request'),
            Tab(text: 'Response'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SelectableText('${payload.method} ${payload.uri}'),
                  Text('Status: ${payload.response?.statusCode ?? 'Unknown'}'),
                  Text(
                    'Duration: ${payload.duration?.inMilliseconds ?? 'Unknown'} ms',
                  ),
                  Text('Started: ${payload.requestStartedAt.toLocal()}'),
                  if (record.source != null) Text('Source: ${record.source}'),
                  if (payload.error != null)
                    SelectableText('Error: ${payload.error!.message}'),
                  TextButton.icon(
                    onPressed: () => showHttpFragmentCopyDialog(
                      context,
                      diagnostics: diagnostics,
                      recordId: record.id,
                      fragment: HttpFragment.curl,
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy cURL'),
                  ),
                ],
              ),
              _HttpTab(
                recordId: record.id,
                diagnostics: diagnostics,
                target: HeaderTarget.request,
                headers: payload.requestHeaders,
                body: payload.requestBody,
                recordContext: record.context,
              ),
              _HttpTab(
                recordId: record.id,
                diagnostics: diagnostics,
                target: HeaderTarget.response,
                headers: payload.response?.headers,
                body: payload.response?.body,
                recordContext: record.context,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HttpTab extends StatelessWidget {
  const _HttpTab({
    required this.recordId,
    required this.diagnostics,
    required this.target,
    required this.headers,
    required this.body,
    required this.recordContext,
  });

  final String recordId;
  final CodeKitDiagnostics diagnostics;
  final HeaderTarget target;
  final Map<String, List<String>>? headers;
  final BodySnapshot? body;
  final Map<String, Object?>? recordContext;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      ExpansionTile(
        title: const Text('Headers'),
        initiallyExpanded: false,
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        children: [
          if (headers?.isNotEmpty ?? false)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showHttpFragmentCopyDialog(
                  context,
                  diagnostics: diagnostics,
                  recordId: recordId,
                  fragment: HttpFragment.headers,
                  target: target,
                ),
                child: const Text('Copy headers'),
              ),
            ),
          if (headers == null || headers!.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No headers captured'),
            )
          else
            for (final entry in headers!.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.key),
                subtitle: SelectableText(entry.value.join(', ')),
              ),
        ],
      ),
      ExpansionTile(
        title: const Text('Body'),
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        children: [
          if (_hasCopyableBody(body))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showHttpFragmentCopyDialog(
                  context,
                  diagnostics: diagnostics,
                  recordId: recordId,
                  fragment: HttpFragment.body,
                  target: target,
                ),
                child: const Text('Copy body'),
              ),
            ),
          BodyInspector(body: body),
        ],
      ),
      if (recordContext != null) ...[
        const Divider(),
        Text('Context', style: Theme.of(context).textTheme.titleMedium),
        SelectableText(
          const JsonEncoder.withIndent('  ').convert(recordContext),
        ),
      ],
    ],
  );
}

bool _hasCopyableBody(BodySnapshot? body) {
  if (body == null || body.state != BodyCaptureState.captured) return false;
  final data = body.data;
  if (data == null) return false;
  if (data is String) return data.isNotEmpty;
  if (data is Iterable) return data.isNotEmpty;
  if (data is Map) return data.isNotEmpty;
  return true;
}

/// Inspects captured text, JSON and media metadata without reading file bytes.
class BodyInspector extends StatefulWidget {
  const BodyInspector({super.key, required this.body});
  final BodySnapshot? body;

  @override
  State<BodyInspector> createState() => _BodyInspectorState();
}

class _BodyInspectorState extends State<BodyInspector> {
  String _mode = 'Pretty';
  String _search = '';
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    if (body == null || body.state != BodyCaptureState.captured) {
      return Text(switch (body?.state) {
        BodyCaptureState.unsupported =>
          'Body unavailable: the client did not capture a supported body.',
        BodyCaptureState.disabled => 'Body capture was disabled.',
        _ => 'No body captured.',
      });
    }
    final data = body.data;
    final raw = data is String ? data : jsonEncode(data);
    final pretty = data is String
        ? data
        : const JsonEncoder.withIndent('  ').convert(data);
    final isJson = body.representation == BodyRepresentation.json;
    final isMedia = body.representation == BodyRepresentation.media;
    final visible = _mode == 'Raw' ? raw : pretty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMedia)
          const Text('Media metadata only; file contents were not captured.'),
        if (isJson)
          Wrap(
            spacing: 8,
            children: [
              for (final mode in ['Tree', 'Pretty', 'Raw'])
                ChoiceChip(
                  label: Text(mode),
                  selected: _mode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                ),
              if (_mode == 'Tree')
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Collapse' : 'Expand'),
                ),
            ],
          ),
        TextField(
          decoration: const InputDecoration(labelText: 'Search body'),
          onChanged: (value) => setState(() => _search = value),
        ),
        if (_search.isNotEmpty)
          Text(
            visible.toLowerCase().contains(_search.toLowerCase())
                ? 'Match found'
                : 'No match',
          ),
        if (_mode == 'Tree' && isJson)
          _JsonTree(value: data, expanded: _expanded)
        else
          SelectableText(visible),
      ],
    );
  }
}

class _JsonTree extends StatefulWidget {
  const _JsonTree({
    super.key,
    required this.value,
    required this.expanded,
    this.label,
  });
  final Object? value;
  final bool expanded;
  final String? label;

  @override
  State<_JsonTree> createState() => _JsonTreeState();
}

class _JsonTreeState extends State<_JsonTree> {
  late bool _open = widget.expanded;

  @override
  void didUpdateWidget(covariant _JsonTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) _open = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    if (value is! Map && value is! List) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          '${widget.label ?? 'Value'}: ${jsonEncode(value)}',
        ),
      );
    }
    final length = value is Map ? value.length : (value as List).length;
    return ExpansionTile(
      key: ValueKey((widget.label, widget.expanded)),
      title: Text('${widget.label ?? 'Root'} ($length)'),
      initiallyExpanded: _open,
      onExpansionChanged: (open) => setState(() => _open = open),
      children: _open
          ? [
              if (value is Map)
                for (final entry in value.entries)
                  _JsonTree(
                    key: ValueKey(entry.key),
                    label: entry.key.toString(),
                    value: entry.value,
                    expanded: widget.expanded,
                  ),
              if (value is List)
                for (var i = 0; i < value.length; i++)
                  _JsonTree(
                    key: ValueKey(i),
                    label: '[$i]',
                    value: value[i],
                    expanded: widget.expanded,
                  ),
            ]
          : const [],
    );
  }
}
