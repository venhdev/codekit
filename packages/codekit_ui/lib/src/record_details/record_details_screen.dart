import 'dart:convert';

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../export/http_fragment_copy_dialog.dart';
import '../shared/codekit_bottom_sheet.dart';
import '../shared/codekit_tag.dart';
import 'body_inspector.dart';

class RecordDetailsScreen extends StatefulWidget {
  const RecordDetailsScreen({
    super.key,
    required this.diagnostics,
    required this.record,
  });

  final CodeKitDiagnostics diagnostics;
  final DiagnosticRecord record;

  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
  late DiagnosticRecord _record = widget.record;

  @override
  void initState() {
    super.initState();
    _loadFullRecordIfNeeded();
  }

  Future<void> _loadFullRecordIfNeeded() async {
    final full = await widget.diagnostics.getById(widget.record.id);
    if (full != null && mounted) {
      setState(() => _record = full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
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
            onPressed: () => showCodeKitDialog<void>(
              context,
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
              diagnostics: widget.diagnostics,
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
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          const CodeKitTag.recordKind(recordType: DiagnosticRecordType.log),
          CodeKitTag.tonal(
            label: payload.level.name.toUpperCase(),
            tone: payload.level.tone,
          ),
          if (payload.tags != null)
            for (final tag in payload.tags!) CodeKitTag.customTag(tag: tag),
        ],
      ),
      const SizedBox(height: 8),
      if (record.source != null) Text('Source: ${record.source}'),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const CodeKitTag.recordKind(
                        recordType: DiagnosticRecordType.http,
                      ),
                      CodeKitTag.tonal(
                        label: payload.response?.statusCode?.toString() ?? '—',
                        tone: HttpStatusGroup.fromCode(
                          payload.response?.statusCode,
                        ).tone,
                      ),
                      if (payload.duration != null)
                        CodeKitTag.duration(
                          label: '${payload.duration!.inMilliseconds} ms',
                          durationLevel: DurationThresholds().classify(
                            payload.duration,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
          if (hasCopyableBody(body))
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
