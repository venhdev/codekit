import 'dart:async';

import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/material.dart';

import '../export/export_confirmation_dialog.dart';
import '../record_details/record_details_screen.dart';
import '../search_history/search_history_sheet.dart';
import '../search_history/search_history_store.dart';
import '../settings/codekit_viewer_settings.dart';
import '../settings/diagnostics_settings_sheet.dart';
import '../settings/codekit_viewer_theme.dart';
import '../traces/trace_sessions_sheet.dart';
import '../shared/guarded_action.dart';
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
  @override
  Widget build(BuildContext context) {
    final screen = _DiagnosticsRecordsScreen(
      diagnostics: widget.diagnostics,
      searchHistory: widget.searchHistory,
      viewerSettings: widget.viewerSettings,
    );
    return CodeKitViewerTheme.controllerOf(context) == null
        ? CodeKitViewerTheme(
            initialMode: widget.viewerSettings.initialThemeMode,
            child: screen,
          )
        : screen;
  }
}

class _DiagnosticsRecordsScreen extends StatefulWidget {
  const _DiagnosticsRecordsScreen({
    required this.diagnostics,
    required this.searchHistory,
    required this.viewerSettings,
  });

  final CodeKitDiagnostics diagnostics;
  final SearchHistoryStore? searchHistory;
  final CodeKitViewerSettings viewerSettings;

  @override
  State<_DiagnosticsRecordsScreen> createState() =>
      _DiagnosticsRecordsScreenState();
}

class _DiagnosticsRecordsScreenState extends State<_DiagnosticsRecordsScreen> {
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

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ids = _controller.selectedIds.toList();
      if (!mounted) return;
      if (ids.isEmpty) {
        _message('No records selected');
        return;
      }
      await guardAction(
        () async {
          await showExportConfirmation(
            context,
            selectedCount: ids.length,
            export: (representation) => widget.diagnostics.exportRecords(
              ids,
              representation: representation,
            ),
          );
        },
        onError: (e, st) {
          if (mounted) _message('Could not export selected records');
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final ids = _controller.selectedIds.toList();
    if (ids.isEmpty) return;
    setState(() => _busy = true);
    try {
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
      await guardAction(
        () async {
          await widget.diagnostics.deleteByIds(ids);
          if (!mounted) return;
          _controller.removeSelected(ids);
          await _controller.reload();
        },
        onError: (e, st) {
          if (mounted) _message('Delete failed');
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
        IconButton(
          tooltip: 'Reload',
          icon: const Icon(Icons.refresh),
          onPressed: _controller.reload,
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
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
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
                tooltip: _controller.hasActiveFilters
                    ? 'Filters active'
                    : 'Filters',
                icon: Badge(
                  isLabelVisible: _controller.hasActiveFilters,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  enableDrag: true,
                  showDragHandle: false,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CodeKitViewerTheme.wrap(
                    context,
                    FiltersSheet(controller: _controller),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
          child: Row(
            children: [
              Expanded(child: Text(_controller.resultsLabel)),
              if (_traceSession != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: InputChip(
                    label: Text(
                      'Trace: ${_traceSession!.name ?? _traceSession!.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: _clearTraceScope,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              _TraceControl(
                active: widget.diagnostics.isTraceActive,
                count: widget.diagnostics.activeTraceRecordCount,
                onOpenSessions: _selectionMode ? null : _traceSessions,
                onToggle: _selectionMode
                    ? null
                    : widget.diagnostics.isTraceActive
                    ? _stopTrace
                    : _startTrace,
              ),
            ],
          ),
        ),
        if (_controller.hasActiveFilters) _activeFilterChipsRow(),
        Expanded(child: _recordsList()),
      ],
    ),
    bottomNavigationBar: !_selectionMode
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Tooltip(
                    message: _controller.visibleSelection == true
                        ? 'Deselect listed records'
                        : 'Select listed records',
                    child: Checkbox(
                      tristate: true,
                      value: _controller.visibleSelection,
                      semanticLabel: 'Select listed records',
                      onChanged: _busy || _controller.records.isEmpty
                          ? null
                          : (_) => _controller.toggleVisibleSelection(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _controller.selectedIds.isEmpty || _busy
                          ? null
                          : _export,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Delete selected records',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .errorContainer,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onErrorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _controller.selectedIds.isEmpty || _busy
                        ? null
                        : _delete,
                    icon: const Icon(Icons.delete_outline),
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
                      builder: (_) => CodeKitViewerTheme.wrap(
                        context,
                        RecordDetailsScreen(
                          diagnostics: widget.diagnostics,
                          record: record,
                        ),
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

  Widget _activeFilterChipsRow() {
    String statusLabel(HttpStatusGroup group) => switch (group) {
      HttpStatusGroup.informational => '1xx',
      HttpStatusGroup.success => '2xx',
      HttpStatusGroup.redirection => '3xx',
      HttpStatusGroup.clientError => '4xx',
      HttpStatusGroup.serverError => '5xx',
      HttpStatusGroup.unknown => 'Unknown',
    };

    String durationLabel(DurationLevel level) => switch (level) {
      DurationLevel.fast => 'Fast',
      DurationLevel.normal => 'Normal',
      DurationLevel.warn => 'Warn',
      DurationLevel.slow => 'Slow',
      DurationLevel.unknown => 'None',
    };

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: [
          for (final group in _controller.statusGroups)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(statusLabel(group)),
                onDeleted: () {
                  final next = Set<HttpStatusGroup>.of(_controller.statusGroups)
                    ..remove(group);
                  _controller.applyFilters(
                    statuses: next,
                    durations: _controller.durationLevels,
                    recordTypes: _controller.types,
                    from: _controller.from,
                    to: _controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          for (final level in _controller.durationLevels)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(durationLabel(level)),
                onDeleted: () {
                  final next = Set<DurationLevel>.of(_controller.durationLevels)
                    ..remove(level);
                  _controller.applyFilters(
                    statuses: _controller.statusGroups,
                    durations: next,
                    recordTypes: _controller.types,
                    from: _controller.from,
                    to: _controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          for (final type in _controller.types)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  type == DiagnosticRecordType.http ? 'HTTP record' : 'App log',
                ),
                onDeleted: () {
                  final next = Set<DiagnosticRecordType>.of(_controller.types)
                    ..remove(type);
                  _controller.applyFilters(
                    statuses: _controller.statusGroups,
                    durations: _controller.durationLevels,
                    recordTypes: next,
                    from: _controller.from,
                    to: _controller.to,
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_controller.from != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'From: ${_controller.from!.toLocal().toString().split('.').first}',
                ),
                onDeleted: () => _controller.applyFilters(
                  statuses: _controller.statusGroups,
                  durations: _controller.durationLevels,
                  recordTypes: _controller.types,
                  from: null,
                  to: _controller.to,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (_controller.to != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text(
                  'To: ${_controller.to!.toLocal().toString().split('.').first}',
                ),
                onDeleted: () => _controller.applyFilters(
                  statuses: _controller.statusGroups,
                  durations: _controller.durationLevels,
                  recordTypes: _controller.types,
                  from: _controller.from,
                  to: null,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
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
  final VoidCallback? onOpenSessions;
  final VoidCallback? onToggle;

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
