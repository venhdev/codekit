import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/foundation.dart';

import '../search_history/search_history_store.dart';
import '../shared/guarded_action.dart';

/// Screen state around the public, cursor-based diagnostics query API.
class RecordsController extends ChangeNotifier {
  final CodeKitDiagnostics diagnostics;
  final SearchHistoryStore history;

  RecordsController(this.diagnostics, this.history);

  List<DiagnosticRecord> records = const [];
  final Set<String> selectedIds = {};
  Set<HttpStatusGroup> statusGroups = {};
  Set<DurationLevel> durationLevels = {};
  Set<DiagnosticRecordType> types = {};
  Set<String> methods = {};
  DateTime? from;
  DateTime? to;
  String search = '';
  bool regexMode = false;
  String? error;
  bool loading = false;
  bool hasMore = true;
  String? _cursor;
  List<String>? _traceRecordIds;
  int _generation = 0;

  String get resultsLabel => '${records.length}${hasMore ? '+' : ''} results';

  /// Checkbox state reflects only IDs in the currently loaded list.
  bool? get visibleSelection {
    final count = records
        .where((record) => selectedIds.contains(record.id))
        .length;
    if (count == 0) return false;
    return count == records.length ? true : null;
  }

  bool get hasTraceScope => _traceRecordIds != null;
  bool get hasActiveFilters =>
      statusGroups.isNotEmpty ||
      durationLevels.isNotEmpty ||
      types.isNotEmpty ||
      methods.isNotEmpty ||
      from != null ||
      to != null;

  RecordQuery _query({String? cursor}) => RecordQuery(
    cursor: cursor,
    text: !regexMode && search.isNotEmpty ? search : null,
    regex: regexMode && search.isNotEmpty ? RegExp(search) : null,
    types: types.isEmpty ? null : types,
    methods: methods.isEmpty ? null : methods,
    statusGroups: statusGroups.isEmpty ? null : statusGroups,
    durationLevels: durationLevels.isEmpty ? null : durationLevels,
    from: from,
    to: to,
  );

  Future<void> reload() async {
    _generation++;
    records = const [];
    _cursor = null;
    hasMore = true;
    loading = false;
    error = null;
    notifyListeners();
    if (_traceRecordIds != null) {
      await _loadTraceScope(_generation);
      return;
    }
    await loadMore();
  }

  Future<void> _loadTraceScope(int generation) async {
    loading = true;
    notifyListeners();
    try {
      await guardAction(
        () async {
          final saved = await diagnostics.getByIds(_traceRecordIds!);
          if (generation != _generation) return;
          final query = _query();
          records = List.unmodifiable(saved.where(query.matches));
          hasMore = false;
          error = null;
        },
        onError: (e, st) {
          if (generation == _generation) error = 'Could not load Trace session';
        },
      );
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final generation = _generation;
    final cursor = _cursor;
    loading = true;
    notifyListeners();
    try {
      await guardAction(
        () async {
          final page = await diagnostics.query(_query(cursor: cursor));
          if (generation != _generation) return;
          records = List.unmodifiable([...records, ...page.records]);
          _cursor = page.nextCursor;
          hasMore = _cursor != null;
          error = null;
        },
        onError: (e, st) {
          if (generation == _generation) error = 'Could not load records';
        },
      );
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Returns an error for invalid regex without changing the current query.
  Future<String?> submitSearch(String text, bool isRegex) async {
    final value = text.trim();
    if (isRegex && value.isNotEmpty) {
      try {
        RegExp(value);
      } on FormatException {
        return 'Invalid regular expression';
      }
    }
    search = value;
    regexMode = isRegex;
    if (value.isNotEmpty) history.remember(value, isRegex);
    await reload();
    return null;
  }

  Future<void> applyFilters({
    required Set<HttpStatusGroup> statuses,
    required Set<DurationLevel> durations,
    required Set<DiagnosticRecordType> recordTypes,
    Set<String>? methods,
    DateTime? from,
    DateTime? to,
  }) async {
    statusGroups = Set.of(statuses);
    durationLevels = Set.of(durations);
    types = Set.of(recordTypes);
    this.methods = methods != null ? Set.of(methods) : this.methods;
    this.from = from;
    this.to = to;
    await reload();
  }

  void toggleSelected(String id) {
    if (!selectedIds.add(id)) selectedIds.remove(id);
    notifyListeners();
  }

  void clearSelection() {
    if (selectedIds.isEmpty) return;
    selectedIds.clear();
    notifyListeners();
  }

  Future<void> setTraceScope(Iterable<String> recordIds) async {
    _traceRecordIds = List.unmodifiable(recordIds.toSet());
    await reload();
  }

  Future<void> clearTraceScope() async {
    if (_traceRecordIds == null) return;
    _traceRecordIds = null;
    await reload();
  }

  void toggleVisibleSelection() {
    final ids = records.map((record) => record.id);
    if (visibleSelection == true) {
      selectedIds.removeAll(ids);
    } else {
      selectedIds.addAll(ids);
    }
    notifyListeners();
  }

  void removeSelected(Iterable<String> ids) {
    selectedIds.removeAll(ids);
    notifyListeners();
  }
}
