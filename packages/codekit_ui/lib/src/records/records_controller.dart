import 'package:codekit_core/codekit_core.dart';
import 'package:flutter/foundation.dart';

import '../search_history/search_history_store.dart';

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

  String get matchingLabel => '${records.length}${hasMore ? '+' : ''} matching';
  bool get hasTraceScope => _traceRecordIds != null;

  RecordQuery _query({String? cursor}) => RecordQuery(
    cursor: cursor,
    text: !regexMode && search.isNotEmpty ? search : null,
    regex: regexMode && search.isNotEmpty ? RegExp(search) : null,
    types: types.isEmpty ? null : types,
    statusGroups: statusGroups.isEmpty ? null : statusGroups,
    durationLevels: durationLevels.isEmpty ? null : durationLevels,
    from: from,
    to: to,
  );

  Future<void> reload() async {
    _generation++;
    records = const [];
    selectedIds.clear();
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
      final saved = await diagnostics.getByIds(_traceRecordIds!);
      if (generation != _generation) return;
      final query = _query();
      records = List.unmodifiable(saved.where(query.matches));
      hasMore = false;
      error = null;
    } catch (_) {
      if (generation == _generation) error = 'Could not load Trace session';
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
      final page = await diagnostics.query(_query(cursor: cursor));
      if (generation != _generation) return;
      records = List.unmodifiable([...records, ...page.records]);
      _cursor = page.nextCursor;
      hasMore = _cursor != null;
      error = null;
    } catch (_) {
      if (generation == _generation) error = 'Could not load records';
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
    DateTime? from,
    DateTime? to,
  }) async {
    statusGroups = Set.of(statuses);
    durationLevels = Set.of(durations);
    types = Set.of(recordTypes);
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

  /// Resolves every match only for an explicit all-matching export.
  Future<List<String>> allMatchingIds() async {
    if (_traceRecordIds != null) {
      return records.map((record) => record.id).toList();
    }
    final ids = <String>[];
    String? cursor;
    do {
      final page = await diagnostics.query(_query(cursor: cursor));
      ids.addAll(page.records.map((record) => record.id));
      cursor = page.nextCursor;
    } while (cursor != null);
    return ids;
  }
}
