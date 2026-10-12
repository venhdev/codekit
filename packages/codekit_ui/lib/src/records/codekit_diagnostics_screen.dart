import 'dart:async';

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../export/export_confirmation_dialog.dart';
import '../record_details/record_details_screen.dart';
import '../search_history/search_history_sheet.dart';
import '../search_history/search_history_store.dart';
import '../settings/codekit_viewer_settings.dart';
import '../settings/diagnostics_settings_sheet.dart';
import '../traces/trace_sessions_sheet.dart';
import 'diagnostic_record_tile.dart';
import 'filters_sheet.dart';
import 'records_controller.dart';

class CodeKitDiagnosticsScreen extends StatefulWidget {
  const CodeKitDiagnosticsScreen({
    super.key,
    required this.diagnostics,
    this.searchHistory,
    this.viewerSettings = const CodeKitViewerSettings(),
  });

  final CodeKitDiagnostics diagnostics;
  final SearchHistoryStore? searchHistory;
  final CodeKitViewerSettings viewerSettings;

  @override
  State<CodeKitDiagnosticsScreen> createState() =>
      _CodeKitDiagnosticsScreenState();
}

class _CodeKitDiagnosticsScreenState extends State<CodeKitDiagnosticsScreen> {
  late final SearchHistoryStore _history;
  late final RecordsController _controller;
  final TextEditingController _search = TextEditingController();
  bool _regex = false;
  bool _busy = false;
  bool _selectionMode = false;
  TraceSession? _traceSession;
  Timer? _traceCountTimer;

  @override
  void initState() {
    super.initState();
    _history = widget.searchHistory ?? SearchHistoryStore();
    _controller = RecordsController(widget.diagnostics, _history);
    _controller.addListener(_refresh);
    _controller.reload();
    _syncTraceCountTimer();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _traceCountTimer?.cancel();
    if (widget.searchHistory == null) _history.dispose();
    _search.dispose();
    super.dispose();
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    final error = await _controller.submitSearch(_search.text, _regex);
    if (mounted && error != null) _message(error);
  }

  Future<void> _historySheet() async {
    final selected = await showSearchHistorySheet(context, _history);
    if (selected == null || !mounted) return;
    _search.text = selected.text;
    setState(() => _regex = selected.isRegex);
    await _submit();
  }

  Future<void> _traceSessions() async {
    final session = await showTraceSessionsSheet(context, widget.diagnostics);
    if (!mounted) return;
    _syncTraceCountTimer();
    if (session == null) {
      setState(() {});
      return;
    }
    setState(() => _traceSession = session);
    await _controller.setTraceScope(session.recordIds);
  }

  Future<void> _clearTraceScope() async {
    setState(() => _traceSession = null);
    await _controller.clearTraceScope();
  }

  void _toggleSelectionMode() => setState(() {
    _selectionMode = !_selectionMode;
    if (!_selectionMode) _controller.clearSelection();
  });

  void _enterSelection(String id) {
    _selectionMode = true;
    _controller.toggleSelected(id);
    setState(() {});
  }

  void _syncTraceCountTimer() {
    _traceCountTimer?.cancel();
    if (!widget.diagnostics.isTraceActive) return;
    _traceCountTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.diagnostics.isTraceActive) {
        _syncTraceCountTimer();
        return;
      }
      setState(() {});
    });
  }

  void _startTrace() {
    try {
      widget.diagnostics.startTrace();
      _syncTraceCountTimer();
      setState(() {});
    } on StateError {
      _message('Trace is already active');
    }
  }

  Future<void> _stopTrace() async {
    try {
      final session = await widget.diagnostics.stopTrace();
      _syncTraceCountTimer();
      if (!mounted) return;
      setState(() {});
      _message(
        session == null
            ? 'Trace had no accepted records'
            : 'Trace saved ${session.recordIds.length} IDs',
      );
    } on StateError {
      _message('No active Trace');
    }
  }

  Future<void> _export({required bool allMatching}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ids = allMatching
          ? await _controller.allMatchingIds()
          : _controller.selectedIds.toList();
      if (!mounted) return;
      if (ids.isEmpty) {
        _message('No records selected');
        return;
      }
      await showExportConfirmation(
        context,
        selectedCount: ids.length,
        export: (representation) => widget.diagnostics.exportRecords(
          ids,
          representation: representation,
        ),
      );
    } catch (_) {
      if (mounted) _message('Could not load matching records');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ids = _controller.selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${ids.length} records?'),
        content: const Text('Saved Trace sessions are kept.'),
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
    if (confirmed != true || !mounted) return;
    try {
      await widget.diagnostics.deleteByIds(ids);
      await _controller.reload();
    } catch (_) {
      if (mounted) _message('Delete failed');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: _selectionMode ? 'Close selection' : 'Back',
        icon: Icon(_selectionMode ? Icons.close : Icons.arrow_back),
        onPressed: _selectionMode
            ? _toggleSelectionMode
            : () => Navigator.maybePop(context),
      ),
      title: Text(
        _selectionMode
            ? '${_controller.selectedIds.length} selected'
            : 'CodeKit',
      ),
      actions: [
        if (!_selectionMode) ...[
          IconButton(
            tooltip: 'Filters',
            icon: const Icon(Icons.tune),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              enableDrag: true,
              showDragHandle: true,
              builder: (_) => FiltersSheet(controller: _controller),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showDiagnosticsSettingsSheet(
              context,
              diagnostics: widget.diagnostics,
              settings: widget.viewerSettings,
            ),
          ),
        ],
      ],
    ),
    body: Column(
      children: [
        if (!_selectionMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Search records',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: _regex
                            ? 'Regex search enabled'
                            : 'Text search enabled',
                        icon: Text(_regex ? '.*' : 'abc'),
                        onPressed: () => setState(() => _regex = !_regex),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Search history',
                  icon: const Icon(Icons.history),
                  onPressed: _historySheet,
                ),
                IconButton(
                  tooltip: 'Reload',
                  icon: const Icon(Icons.refresh),
                  onPressed: _controller.reload,
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                _selectionMode
                    ? '${_controller.selectedIds.length} selected'
                    : _controller.matchingLabel,
              ),
              if (_traceSession != null && !_selectionMode)
                InputChip(
                  label: Text(
                    'Trace: ${_traceSession!.name ?? _traceSession!.id}',
                  ),
                  onDeleted: _clearTraceScope,
                ),
              if (_selectionMode && widget.diagnostics.isTraceActive)
                Chip(
                  label: Text(
                    'Trace · ${widget.diagnostics.activeTraceRecordCount} IDs',
                  ),
                )
              else if (!_selectionMode)
                _TraceControl(
                  active: widget.diagnostics.isTraceActive,
                  count: widget.diagnostics.activeTraceRecordCount,
                  onOpenSessions: _traceSessions,
                  onToggle: widget.diagnostics.isTraceActive
                      ? _stopTrace
                      : _startTrace,
                ),
            ],
          ),
        ),
        Expanded(child: _recordsList()),
      ],
    ),
    bottomNavigationBar: !_selectionMode
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _controller.selectedIds.isEmpty || _busy
                        ? null
                        : () => _export(allMatching: false),
                    child: const Text('Export selected'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _export(allMatching: true),
                    child: const Text('All matching'),
                  ),
                  TextButton(
                    onPressed: _controller.selectedIds.isEmpty || _busy
                        ? null
                        : _delete,
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ),
  );

  Widget _recordsList() {
    final list = _controller.error != null
        ? Center(child: Text(_controller.error!))
        : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 300 &&
                  _controller.hasMore &&
                  !_controller.loading) {
                _controller.loadMore();
              }
              return false;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount:
                  _controller.records.length + (_controller.loading ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == _controller.records.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final record = _controller.records[index];
                return DiagnosticRecordTile(
                  record: record,
                  selectionMode: _selectionMode,
                  selected: _controller.selectedIds.contains(record.id),
                  onSelect: () => _controller.toggleSelected(record.id),
                  onLongPress: () => _enterSelection(record.id),
                  onOpen: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordDetailsScreen(
                        diagnostics: widget.diagnostics,
                        record: record,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
    return _selectionMode
        ? list
        : RefreshIndicator(onRefresh: _controller.reload, child: list);
  }
}

class _TraceControl extends StatelessWidget {
  const _TraceControl({
    required this.active,
    required this.count,
    required this.onOpenSessions,
    required this.onToggle,
  });

  final bool active;
  final int count;
  final VoidCallback onOpenSessions;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenSessions,
        child: Chip(
          avatar: Icon(
            active ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
            color: active ? Theme.of(context).colorScheme.error : null,
            size: 16,
          ),
          label: Text(active ? 'Trace · $count IDs' : 'Trace off'),
        ),
      ),
      IconButton(
        tooltip: active ? 'Stop Trace' : 'Start Trace',
        icon: Icon(active ? Icons.stop : Icons.play_arrow),
        onPressed: onToggle,
      ),
    ],
  );
}
