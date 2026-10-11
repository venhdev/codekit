import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:codekit_core/codekit_core.dart';
import 'package:drift/drift.dart';

import 'database/diagnostic_database.dart';

const int _idQueryBatchSize = 500;
const int _queryScanBatchSize = 256;
const int _cursorVersion = 1;

typedef DriftStoreWarningCallback = void Function(
  String message,
  Object? error,
  StackTrace? stackTrace,
);

Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
  for (var start = 0; start < values.length; start += size) {
    final end = min(start + size, values.length);
    yield values.sublist(start, end);
  }
}

DiagnosticDatabase _createDatabase(String databasePath) {
  final previousSetting = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  // Drift's debug warning counts database instances by generated class, even
  // when each CodeKit store has its own executor and file. Multiple CodeKit
  // instances/reopens are supported, so suppress only this synchronous create.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  try {
    return DiagnosticDatabase(openNativeDatabase(databasePath));
  } finally {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousSetting;
  }
}

/// A native SQLite-backed implementation of [DiagnosticStore].
final class DriftDiagnosticStore implements DiagnosticStore {
  final DiagnosticDatabase _database;
  final DriftStoreWarningCallback? _onWarning;
  final String _cursorScope;
  bool _closed = false;

  DriftDiagnosticStore._(this._database, this._onWarning)
    : _cursorScope =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000)}';

  /// Opens a native SQLite database at [databasePath].
  ///
  /// The parent directory is created when needed. The application chooses
  /// the path and decides when the owning diagnostics instance is disposed.
  static Future<DriftDiagnosticStore> open({
    required String databasePath,
    DriftStoreWarningCallback? onWarning,
  }) async {
    if (databasePath.trim().isEmpty) {
      throw ArgumentError.value(
        databasePath,
        'databasePath',
        'Must not be empty',
      );
    }
    final file = File(databasePath).absolute;
    await file.parent.create(recursive: true);
    final database = _createDatabase(file.path);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return DriftDiagnosticStore._(database, onWarning);
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  @override
  StorageKind get kind => StorageKind.persistent;

  void _checkOpen() {
    if (_closed) throw StateError('DriftDiagnosticStore is closed');
  }

  void _warn(String message, [Object? error, StackTrace? stackTrace]) {
    try {
      final callback = _onWarning;
      if (callback != null) {
        callback(message, error, stackTrace);
      } else {
        developer.log(
          message,
          name: 'codekit.drift',
          error: error,
          stackTrace: stackTrace,
          level: 900,
        );
      }
    } catch (_) {
      // A warning handler must not turn a query into a recorder failure.
    }
  }

  DiagnosticRecord? _decode(String id, String json) {
    final result = const DiagnosticRecordCodec().decode(utf8.encode(json));
    if (result.status == RecordDecodeStatus.success) return result.record;
    _warn(
      'Skipping unreadable persisted diagnostic record "$id" (${result.status.name}).',
    );
    return null;
  }

  @override
  Future<void> appendAndRetain(
    DiagnosticRecord record, {
    required RetentionPolicy retention,
  }) async {
    _checkOpen();
    await _database.transaction(() async {
      await _database
          .into(_database.storedRecordRows)
          .insert(
            StoredRecordRowsCompanion.insert(
              recordId: record.id,
              recordedAtMicros: record.recordedAt.microsecondsSinceEpoch,
              recordJson: utf8.decode(
                const DiagnosticRecordCodec().encode(record),
              ),
            ),
          );

      final limit = retention.maxRecords;
      if (limit == null) return;
      final countExpression = _database.storedRecordRows.order.count();
      final countQuery = _database.selectOnly(_database.storedRecordRows)
        ..addColumns([countExpression]);
      final count = (await countQuery.getSingle()).read(countExpression) ?? 0;
      if (count <= limit) return;

      final excess = count - limit;
      final batchSize = (limit * 0.05).ceil();
      final deleteCount = max(excess, batchSize);
      final oldest =
          await (_database.select(_database.storedRecordRows)
                ..orderBy([(row) => OrderingTerm.asc(row.order)])
                ..limit(deleteCount))
              .get();
      await (_database.delete(
        _database.storedRecordRows,
      )..where((row) => row.order.isIn(oldest.map((row) => row.order)))).go();
    });
  }

  @override
  Future<DiagnosticRecord?> getById(String id) async {
    _checkOpen();
    final row = await (_database.select(
      _database.storedRecordRows,
    )..where((row) => row.recordId.equals(id))).getSingleOrNull();
    return row == null ? null : _decode(row.recordId, row.recordJson);
  }

  @override
  Future<List<DiagnosticRecord>> getByIds(List<String> ids) async {
    _checkOpen();
    if (ids.isEmpty) return const [];
    final uniqueIds = ids.toSet().toList();
    final records = <String, DiagnosticRecord>{};
    for (final idBatch in _chunks(uniqueIds, _idQueryBatchSize)) {
      final rows = await (_database.select(
        _database.storedRecordRows,
      )..where((row) => row.recordId.isIn(idBatch))).get();
      for (final row in rows) {
        final record = _decode(row.recordId, row.recordJson);
        if (record != null) records[record.id] = record;
      }
    }
    return List.unmodifiable(
      uniqueIds.map((id) => records[id]).whereType<DiagnosticRecord>(),
    );
  }

  @override
  Future<RecordPage> query(RecordQuery query) async {
    _checkOpen();
    final before = _decodeCursor(query);
    final matching = <({int order, DiagnosticRecord record})>[];
    var scanBefore = before;
    while (matching.length <= query.limit) {
      final rowsQuery = _database.select(_database.storedRecordRows)
        ..orderBy([(row) => OrderingTerm.desc(row.order)])
        ..limit(_queryScanBatchSize);
      if (scanBefore != null) {
        rowsQuery.where(
          (row) => row.order.isSmallerThan(Variable(scanBefore!)),
        );
      }
      final rows = await rowsQuery.get();
      if (rows.isEmpty) break;

      for (final row in rows) {
        scanBefore = row.order;
        final record = _decode(row.recordId, row.recordJson);
        if (record != null && query.matches(record)) {
          matching.add((order: row.order, record: record));
          if (matching.length > query.limit) break;
        }
      }
      if (matching.length > query.limit || rows.length < _queryScanBatchSize) {
        break;
      }
    }

    final hasMore = matching.length > query.limit;
    final visible = matching.take(query.limit).toList();
    final nextCursor = hasMore && visible.isNotEmpty
        ? _encodeCursor(query, visible.last.order)
        : null;
    return RecordPage(visible.map((entry) => entry.record), nextCursor);
  }

  int? _decodeCursor(RecordQuery query) {
    final value = query.cursor;
    if (value == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (decoded is! Map<String, dynamic> ||
          decoded['v'] != _cursorVersion ||
          decoded['scope'] != _cursorScope ||
          decoded['query'] != query.fingerprint ||
          decoded['before'] is! int) {
        throw const FormatException();
      }
      return decoded['before'] as int;
    } catch (_) {
      throw ArgumentError('Invalid cursor or changed query');
    }
  }

  String _encodeCursor(RecordQuery query, int before) => base64Url.encode(
    utf8.encode(
      jsonEncode({
        'v': _cursorVersion,
        'scope': _cursorScope,
        'query': query.fingerprint,
        'before': before,
      }),
    ),
  );

  @override
  Future<int> deleteByIds(List<String> ids) async {
    _checkOpen();
    if (ids.isEmpty) return 0;
    var deleted = 0;
    final uniqueIds = ids.toSet().toList();
    await _database.transaction(() async {
      for (final idBatch in _chunks(uniqueIds, _idQueryBatchSize)) {
        deleted += await (_database.delete(
          _database.storedRecordRows,
        )..where((row) => row.recordId.isIn(idBatch))).go();
      }
    });
    return deleted;
  }

  @override
  Future<int> clearRecords() async {
    _checkOpen();
    return _database.delete(_database.storedRecordRows).go();
  }

  @override
  Future<void> saveTraceSession(TraceSession session) async {
    _checkOpen();
    await _database
        .into(_database.storedTraceSessionRows)
        .insert(
          StoredTraceSessionRowsCompanion.insert(
            sessionId: session.id,
            name: Value(session.name),
            fromMicros: session.from.microsecondsSinceEpoch,
            toMicros: session.to.microsecondsSinceEpoch,
            recordIdsJson: jsonEncode(session.recordIds),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<List<TraceSession>> listTraceSessions() async {
    _checkOpen();
    final rows = await (_database.select(
      _database.storedTraceSessionRows,
    )..orderBy([(row) => OrderingTerm.desc(row.order)])).get();
    final sessions = <TraceSession>[];
    for (final row in rows) {
      try {
        final ids = jsonDecode(row.recordIdsJson) as List<dynamic>;
        if (ids.any((id) => id is! String)) throw const FormatException();
        sessions.add(
          TraceSession(
            id: row.sessionId,
            name: row.name,
            from: DateTime.fromMicrosecondsSinceEpoch(
              row.fromMicros,
              isUtc: true,
            ),
            to: DateTime.fromMicrosecondsSinceEpoch(row.toMicros, isUtc: true),
            recordIds: ids.cast<String>(),
          ),
        );
      } catch (error, stackTrace) {
        _warn(
          'Skipping unreadable persisted Trace session "${row.sessionId}".',
          error,
          stackTrace,
        );
      }
    }
    return List.unmodifiable(sessions);
  }

  @override
  Future<bool> deleteTraceSession(String id) async {
    _checkOpen();
    final deleted = await (_database.delete(
      _database.storedTraceSessionRows,
    )..where((row) => row.sessionId.equals(id))).go();
    return deleted > 0;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _database.close();
  }
}
