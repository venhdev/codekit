import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../export/export_confirmation_dialog.dart';
import '../shared/codekit_bottom_sheet.dart';
import '../shared/guarded_action.dart';

Future<TraceSession?> showTraceSessionsSheet(
  BuildContext context,
  CodeKitDiagnostics diagnostics,
) => showCodeKitBottomSheet<TraceSession>(
  context,
  body: _TraceSessionsSheet(diagnostics: diagnostics),
);

class _TraceSessionsSheet extends StatefulWidget {
  const _TraceSessionsSheet({required this.diagnostics});
  final CodeKitDiagnostics diagnostics;

  @override
  State<_TraceSessionsSheet> createState() => _TraceSessionsSheetState();
}

class _TraceSessionsSheetState extends State<_TraceSessionsSheet> {
  List<TraceSession> _sessions = const [];
  bool _active = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _active = widget.diagnostics.isTraceActive;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await guardAction(
      () async {
        final sessions = await widget.diagnostics.listTraceSessions();
        if (mounted) {
          setState(() {
            _sessions = sessions;
            _error = null;
          });
        }
      },
      onError: (e, st) {
        if (mounted) setState(() => _error = 'Could not load Trace sessions');
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleTrace() async {
    await guardAction(
      () async {
        if (_active) {
          await widget.diagnostics.stopTrace();
        } else {
          widget.diagnostics.startTrace();
        }
        if (mounted) setState(() => _active = !_active);
        if (!_active) await _reload();
      },
      onError: (e, st) {
        if (mounted) setState(() => _error = 'Trace action failed');
      },
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<int> _countRecords(DateTime from, DateTime to) async {
    if (from.isAfter(to)) return 0;
    var count = 0;
    String? cursor;
    do {
      final page = await widget.diagnostics.query(
        RecordQuery(from: from, to: to, cursor: cursor),
      );
      count += page.records.length;
      cursor = page.nextCursor;
    } while (cursor != null);
    return count;
  }

  Future<void> _create() async {
    var from = DateTime.now().subtract(const Duration(minutes: 10));
    var to = DateTime.now();
    var count = _countRecords(from, to);
    final chosen = await showCodeKitDialog<(DateTime, DateTime)>(
      context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Create Trace session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('From $from'),
                onTap: () async {
                  final value = await _pickDateTime(from);
                  if (value != null) {
                    update(() {
                      from = value;
                      count = _countRecords(from, to);
                    });
                  }
                },
              ),
              ListTile(
                title: Text('To $to'),
                onTap: () async {
                  final value = await _pickDateTime(to);
                  if (value != null) {
                    update(() {
                      to = value;
                      count = _countRecords(from, to);
                    });
                  }
                },
              ),
              if (from.isAfter(to)) const Text('From must be before To'),
              FutureBuilder<int>(
                future: count,
                builder: (context, snapshot) => Text(
                  snapshot.hasError
                      ? 'Count unavailable'
                      : snapshot.hasData
                      ? 'Records in range: ${snapshot.data}'
                      : 'Counting records…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: from.isAfter(to)
                  ? null
                  : () => Navigator.pop(dialogContext, (from, to)),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await guardAction(
      () async {
        final session = await widget.diagnostics.createTraceSession(
          from: chosen.$1,
          to: chosen.$2,
        );
        if (session == null && mounted) {
          setState(() => _error = 'No records in that time range');
        }
        await _reload();
      },
      onError: (e, st) {
        if (mounted) setState(() => _error = 'Could not create Trace session');
      },
    );
  }

  Future<void> _export(TraceSession session) async {
    await guardAction(
      () async {
        final available = await widget.diagnostics.getByIds(session.recordIds);
        if (!mounted) return;
        if (available.isEmpty) {
          final delete = await showCodeKitDialog<bool>(
            context,
            builder: (context) => AlertDialog(
              title: const Text('No records available'),
              content: const Text(
                'None of this session’s saved IDs currently resolve to records.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete session'),
                ),
              ],
            ),
          );
          if (delete == true) {
            await widget.diagnostics.deleteTraceSession(session.id);
            await _reload();
          }
          return;
        }
        await showExportConfirmation(
          context,
          selectedCount: available.length,
          export: (representation) => widget.diagnostics.exportTraceSession(
            session.id,
            representation: representation,
          ),
        );
      },
      onError: (e, st) {
        if (mounted) setState(() => _error = 'Could not export Trace session');
      },
    );
  }

  Future<void> _deleteSession(TraceSession session) async {
    final confirmed = await showCodeKitDialog<bool>(
      context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trace session?'),
        content: const Text('Its diagnostic records will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await guardAction(
      () async {
        await widget.diagnostics.deleteTraceSession(session.id);
        await _reload();
      },
      onError: (e, st) {
        if (mounted) setState(() => _error = 'Could not delete Trace session');
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text('Trace sessions', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          TextButton.icon(
            onPressed: _loading ? null : _create,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _toggleTrace,
          icon: Icon(_active ? Icons.stop : Icons.fiber_manual_record),
          label: Text(_active ? 'Stop capture' : 'Start capture'),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 8),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_sessions.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No Trace sessions')),
        )
      else
        for (final session in _sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              session.name ??
                  '${session.from.toLocal()} – ${session.to.toLocal()}',
            ),
            subtitle: Text('${session.recordIds.length} saved IDs'),
            onTap: () => Navigator.of(context).pop(session),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _export(session),
                  child: const Text('Export'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Trace session actions',
                  onSelected: (_) => _deleteSession(session),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
    ],
  );
}
