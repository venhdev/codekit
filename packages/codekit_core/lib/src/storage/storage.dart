import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../models/records.dart';

enum StorageKind { memory, persistent }

enum DiagnosticRecordType { log, http }

enum DurationLevel {
  fast,
  normal,
  warn,
  slow,
  unknown;

  DiagnosticTone get tone => switch (this) {
    fast => DiagnosticTone.success,
    normal => DiagnosticTone.info,
    warn => DiagnosticTone.warning,
    slow => DiagnosticTone.danger,
    unknown => DiagnosticTone.neutral,
  };

  bool get isPromotedAlert => this == warn || this == slow;
}

class DurationThresholds {
  final Duration normalAt;
  final Duration warnAt;
  final Duration slowAt;
  DurationThresholds({Duration? normalAt, Duration? warnAt, Duration? slowAt})
    : normalAt = normalAt ?? const Duration(milliseconds: 200),
      warnAt = warnAt ?? const Duration(seconds: 1),
      slowAt = slowAt ?? const Duration(seconds: 3) {
    if (this.normalAt.isNegative ||
        this.warnAt <= this.normalAt ||
        this.slowAt <= this.warnAt) {
      throw ArgumentError('Duration thresholds must increase');
    }
  }
  DurationLevel classify(Duration? d) => d == null
      ? DurationLevel.unknown
      : d < normalAt
      ? DurationLevel.fast
      : d < warnAt
      ? DurationLevel.normal
      : d < slowAt
      ? DurationLevel.warn
      : DurationLevel.slow;
  List<int> get fingerprint => [
    normalAt.inMicroseconds,
    warnAt.inMicroseconds,
    slowAt.inMicroseconds,
  ];
}

class RetentionPolicy {
  /// Maximum number of retained records.
  ///
  /// `null` means unlimited (default).
  /// Values below 100 are normalized to 100.
  /// When exceeded, removes the oldest records in batches of at least
  /// 5% of this limit, rounded up, or more if needed to meet the limit.
  final int? maxRecords;
  RetentionPolicy({int? maxRecords})
    : maxRecords = maxRecords == null ? null : max(100, maxRecords);
}

class RecordQuery {
  final int limit;
  final String? cursor;
  final String? text;
  final RegExp? regex;
  final Set<DiagnosticRecordType>? types;
  final Set<String>? methods;
  final Set<HttpStatusGroup>? statusGroups;
  final Set<DurationLevel>? durationLevels;
  final DateTime? from;
  final DateTime? to;
  final DurationThresholds thresholds;
  RecordQuery({
    int? limit,
    this.cursor,
    this.text,
    this.regex,
    Set<DiagnosticRecordType>? types,
    Set<String>? methods,
    Set<HttpStatusGroup>? statusGroups,
    Set<DurationLevel>? durationLevels,
    this.from,
    this.to,
    DurationThresholds? thresholds,
  }) : limit = limit ?? 100,
       types = types == null ? null : Set.unmodifiable(types),
       methods = methods == null
           ? null
           : Set.unmodifiable(methods.map((m) => m.toUpperCase())),
       statusGroups = statusGroups == null
           ? null
           : Set.unmodifiable(statusGroups),
       durationLevels = durationLevels == null
           ? null
           : Set.unmodifiable(durationLevels),
       thresholds = thresholds ?? DurationThresholds() {
    if (this.limit < 1 ||
        (text != null && regex != null) ||
        (from != null && to != null && from!.isAfter(to!))) {
      throw ArgumentError('Invalid query');
    }
  }
  String get fingerprint {
    List<String>? names(Iterable<Enum>? v) =>
        v == null ? null : (v.map((e) => e.name).toList()..sort());
    List<String>? sortedStrings(Iterable<String>? v) =>
        v == null ? null : (v.toList()..sort());
    return jsonEncode({
      'text': text,
      'regex': regex?.pattern,
      if (regex != null)
        'flags': [
          regex!.isCaseSensitive,
          regex!.isMultiLine,
          regex!.isUnicode,
          regex!.isDotAll,
        ],
      'types': names(types),
      'methods': sortedStrings(methods),
      'status': names(statusGroups),
      'duration': names(durationLevels),
      'from': from?.toUtc().toIso8601String(),
      'to': to?.toUtc().toIso8601String(),
      'thresholds': thresholds.fingerprint,
    });
  }

  bool matches(DiagnosticRecord record) {
    final p = record.payload;
    final type = p is HttpPayload
        ? DiagnosticRecordType.http
        : DiagnosticRecordType.log;
    bool allowed<T>(Set<T>? set, T value) =>
        set == null || set.isEmpty || set.contains(value);
    if (!allowed(types, type)) return false;
    if (methods != null && methods!.isNotEmpty) {
      final method = p is HttpPayload ? p.method.toUpperCase() : null;
      if (method == null || !methods!.contains(method)) return false;
    }
    final status = p is HttpPayload
        ? HttpStatusGroup.fromCode(p.response?.statusCode)
        : HttpStatusGroup.unknown;
    if (!allowed(statusGroups, status)) return false;
    if (!allowed(
      durationLevels,
      thresholds.classify(p is HttpPayload ? p.duration : null),
    )) {
      return false;
    }
    if ((from != null && record.recordedAt.isBefore(from!)) ||
        (to != null && record.recordedAt.isAfter(to!))) {
      return false;
    }
    final fields = [
      record.source,
      if (p is LogPayload) ...[p.message, p.error?.message],
      if (p is HttpPayload) ...[p.method, p.uri.toString(), p.error?.message],
    ].whereType<String>();
    if (text != null &&
        !fields.any((f) => f.toLowerCase().contains(text!.toLowerCase()))) {
      return false;
    }
    if (regex != null && !fields.any(regex!.hasMatch)) return false;
    return true;
  }
}

class RecordPage {
  final List<DiagnosticRecord> records;
  final String? nextCursor;
  RecordPage(Iterable<DiagnosticRecord> records, this.nextCursor)
    : records = List.unmodifiable(records);
}

abstract interface class DiagnosticStore {
  StorageKind get kind;
  FutureOr<void> appendAndRetain(
    DiagnosticRecord record, {
    required RetentionPolicy retention,
  });
  Future<DiagnosticRecord?> getById(String id);
  Future<List<DiagnosticRecord>> getByIds(List<String> ids);
  Future<RecordPage> query(RecordQuery query);
  Future<int> deleteByIds(List<String> ids);
  Future<int> clearRecords();
  Future<void> saveTraceSession(TraceSession session);
  Future<List<TraceSession>> listTraceSessions();
  Future<bool> deleteTraceSession(String id);
  Future<void> close();
}

/// Shared cursor scope generator and base64Url JSON cursor envelope codec.
final class DiagnosticCursorCodec {
  static const int version = 1;

  const DiagnosticCursorCodec._();

  static String createScope() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';

  static int? decodeBefore({
    required String? cursor,
    required String scope,
    required RecordQuery query,
  }) {
    if (cursor == null) return null;
    try {
      final decoded = jsonMap(
        jsonDecode(utf8.decode(base64Url.decode(cursor))),
      );
      if (decoded['v'] != version ||
          decoded['scope'] != scope ||
          decoded['query'] != query.fingerprint ||
          decoded['before'] is! int) {
        throw const FormatException();
      }
      return decoded['before'] as int;
    } catch (_) {
      throw ArgumentError('Invalid cursor or changed query');
    }
  }

  static String encode({
    required String scope,
    required RecordQuery query,
    required int before,
  }) => base64Url.encode(
    utf8.encode(
      jsonEncode({
        'v': version,
        'scope': scope,
        'query': query.fingerprint,
        'before': before,
      }),
    ),
  );
}

class MemoryDiagnosticStore implements DiagnosticStore {
  final _rows = <int, DiagnosticRecord>{};
  final _ids = <String, int>{};
  final _sessions = <String, TraceSession>{};
  final _scope = DiagnosticCursorCodec.createScope();
  int _order = 0;
  bool _closed = false;
  @override
  StorageKind get kind => StorageKind.memory;
  void _check() {
    if (_closed) throw StateError('Store closed');
  }

  @override
  void appendAndRetain(
    DiagnosticRecord record, {
    required RetentionPolicy retention,
  }) {
    _check();
    if (_ids.containsKey(record.id)) throw StateError('Duplicate record ID');
    _rows[++_order] = record;
    _ids[record.id] = _order;
    final limit = retention.maxRecords;
    if (limit != null && _rows.length > limit) {
      final count = max(_rows.length - limit, (limit * 0.05).ceil());
      final orders = _rows.keys.take(count).toList();
      for (final order in orders) {
        _ids.remove(_rows.remove(order)!.id);
      }
    }
  }

  @override
  Future<DiagnosticRecord?> getById(String id) async {
    _check();
    return _rows[_ids[id]];
  }

  @override
  Future<List<DiagnosticRecord>> getByIds(List<String> ids) async {
    _check();
    return List.unmodifiable(
      ids.toSet().map((id) => _rows[_ids[id]]).whereType<DiagnosticRecord>(),
    );
  }

  @override
  Future<RecordPage> query(RecordQuery query) async {
    _check();
    final before = DiagnosticCursorCodec.decodeBefore(
      cursor: query.cursor,
      scope: _scope,
      query: query,
    );
    final hits = <MapEntry<int, DiagnosticRecord>>[];
    for (final order in _rows.keys.toList().reversed) {
      if (before != null && order >= before) continue;
      final r = _rows[order]!;
      if (query.matches(r)) hits.add(MapEntry(order, r));
      if (hits.length > query.limit) break;
    }
    final visible = hits.take(query.limit).toList();
    final cursor = hits.length <= query.limit
        ? null
        : DiagnosticCursorCodec.encode(
            scope: _scope,
            query: query,
            before: visible.last.key,
          );
    return RecordPage(visible.map((e) => e.value), cursor);
  }

  @override
  Future<int> deleteByIds(List<String> ids) async {
    _check();
    var count = 0;
    for (final id in ids.toSet()) {
      final order = _ids.remove(id);
      if (order != null) {
        _rows.remove(order);
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> clearRecords() async {
    _check();
    final count = _rows.length;
    _rows.clear();
    _ids.clear();
    return count;
  }

  @override
  Future<void> saveTraceSession(TraceSession session) async {
    _check();
    _sessions[session.id] = session;
  }

  @override
  Future<List<TraceSession>> listTraceSessions() async {
    _check();
    return List.unmodifiable(_sessions.values.toList().reversed);
  }

  @override
  Future<bool> deleteTraceSession(String id) async {
    _check();
    return _sessions.remove(id) != null;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _rows.clear();
    _ids.clear();
    _sessions.clear();
  }
}
