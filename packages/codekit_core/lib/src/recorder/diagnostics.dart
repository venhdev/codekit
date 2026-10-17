import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import '../models/records.dart';
import '../redaction/redaction.dart';
import '../sinks/sinks.dart';
import '../storage/storage.dart';
import 'http_curl_formatter.dart';

enum RecordDropReason {
  excluded,
  invalidInput,
  redactionFailed,
  queueFull,
  disposed,
  storageFailed,
}

class PersistenceConfirmation {
  final String recordId;
  const PersistenceConfirmation(this.recordId);
}

class RecordReceipt {
  final String? recordId;
  final RecordDropReason? dropReason;
  final _persisted = Completer<PersistenceConfirmation?>();
  RecordReceipt._(this.recordId, this.dropReason);
  bool get accepted => dropReason == null;
  Future<PersistenceConfirmation?> persistedOrNull() => _persisted.future;
  void _complete([PersistenceConfirmation? value]) {
    if (!_persisted.isCompleted) _persisted.complete(value);
  }
}

class DiagnosticWarning {
  final String code;
  final String message;
  const DiagnosticWarning(this.code, this.message);
}

class _Write {
  final DiagnosticRecord record;
  final RecordReceipt receipt;
  _Write(this.record, this.receipt);
}

enum ExportRepresentation { redacted, asStored }

enum ExportStatus { success, empty, failed }

enum HttpFragment { body, headers, curl }

class ExportResult {
  final ExportStatus status;
  final String? text;
  final int recordCount;
  final String? error;
  const ExportResult._(this.status, this.text, this.recordCount, this.error);
  const ExportResult.empty() : this._(ExportStatus.empty, null, 0, null);
  const ExportResult.failed(String error)
    : this._(ExportStatus.failed, null, 0, error);
  const ExportResult.success(String text, int count)
    : this._(ExportStatus.success, text, count, null);
}

/// Explicit diagnostics instance owning one store and its configured sinks.
class CodeKitDiagnostics {
  final DiagnosticStore _store;
  final RetentionPolicy retention;
  final List<DiagnosticSink> _sinks;
  final int pendingRecordLimit;
  final DateTime Function() _clock;
  final void Function(DiagnosticWarning)? _onWarning;
  final _pending = Queue<_Write>();
  final _random = Random.secure();
  int _idSequence = 0;
  bool _disposed = false;
  bool _running = false;
  _Write? _active;
  Future<void>? _disposeFuture;
  DateTime? _traceFrom;
  List<String>? _traceIds;
  RecordMode _recordMode;
  RedactionPolicy _redactionPolicy;
  List<RegExp>? _captureExcludeUriPatterns;
  CodeKitDiagnostics({
    DiagnosticStore? store,
    RetentionPolicy? retention,
    RedactionPolicy? redactionPolicy,
    RecordMode? recordMode,
    List<DiagnosticSink>? sinks,
    List<RegExp>? captureExcludeUriPatterns,
    int? pendingRecordLimit,
    DateTime Function()? clock,
    void Function(DiagnosticWarning)? onWarning,
  }) : _store = store ?? MemoryDiagnosticStore(),
       retention = retention ?? RetentionPolicy(),
       _sinks = List.unmodifiable(sinks ?? const []),
       pendingRecordLimit = pendingRecordLimit ?? 1000,
       _clock = clock ?? DateTime.now,
       // Public callback name intentionally differs from private field.
       // ignore: prefer_initializing_formals
       _onWarning = onWarning,
       _recordMode = recordMode ?? RecordMode.storeRaw,
       _redactionPolicy = redactionPolicy ?? RedactionPolicy(),
       _captureExcludeUriPatterns = captureExcludeUriPatterns == null
           ? null
           : List.unmodifiable(captureExcludeUriPatterns) {
    if (this.pendingRecordLimit < 1) {
      throw ArgumentError('Pending limit must be positive');
    }
  }
  RecordMode get recordMode => _recordMode;
  bool get isTraceActive => _traceIds != null;
  int get activeTraceRecordCount => _traceIds?.length ?? 0;
  set recordMode(RecordMode value) {
    _checkOpen();
    _recordMode = value;
  }

  RedactionPolicy get redactionPolicy => _redactionPolicy;
  set redactionPolicy(RedactionPolicy value) {
    _checkOpen();
    _redactionPolicy = value;
  }

  List<RegExp>? get captureExcludeUriPatterns => _captureExcludeUriPatterns;
  set captureExcludeUriPatterns(List<RegExp>? value) {
    _checkOpen();
    _captureExcludeUriPatterns = value == null
        ? null
        : List.unmodifiable(value);
  }

  bool shouldCaptureHttp(Uri uri) =>
      !_disposed &&
      !(_captureExcludeUriPatterns?.any((p) => p.hasMatch(uri.toString())) ??
          false);

  void _checkOpen() {
    if (_disposed) throw StateError('Diagnostics disposed');
  }

  void _warn(String code, String message) {
    try {
      if (_onWarning != null) {
        _onWarning(DiagnosticWarning(code, message));
      } else {
        developer.log(message, name: 'codekit.$code', level: 900);
      }
    } catch (_) {}
  }

  String createRecordId() {
    _checkOpen();
    // A literal avoids JavaScript's 32-bit shift behavior (1 << 32 == 0).
    return '${++_idSequence}-${List.generate(4, (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0')).join()}';
  }

  RecordReceipt _drop(RecordDropReason reason) {
    final receipt = RecordReceipt._(null, reason).._complete();
    if (reason != RecordDropReason.excluded) {
      _warn(reason.name, 'Record was not accepted');
    }
    return receipt;
  }

  RecordReceipt log(DiagnosticInput input) {
    if (_disposed) return _drop(RecordDropReason.disposed);
    if (input is HttpInput && !shouldCaptureHttp(input.uri)) {
      return _drop(RecordDropReason.excluded);
    }
    final mode = _recordMode;
    final policy = _redactionPolicy;
    final DiagnosticRecord raw;
    try {
      final payload = switch (input) {
        LogInput() => LogPayload(
          message: input.message,
          level: input.level,
          tags: input.tags,
          stackTrace: input.stackTrace?.toString(),
          error: input.error == null
              ? null
              : input.error is DiagnosticError
              ? input.error as DiagnosticError
              : DiagnosticError(
                  type: input.error.runtimeType.toString(),
                  message: input.error.toString(),
                  stackTrace: input.stackTrace?.toString(),
                ),
        ),
        HttpInput() => HttpPayload(
          requestStartedAt: input.requestStartedAt,
          duration: input.duration,
          method: input.method,
          uri: input.uri,
          requestHeaders: input.requestHeaders,
          requestBody: input.requestBody,
          response: input.response,
          error: input.error,
        ),
      };
      raw = DiagnosticRecord(
        id: input is HttpInput ? input.recordId : createRecordId(),
        recordedAt: _clock(),
        recordMode: mode,
        payload: payload,
        source: input.source,
        context: input.context,
      );
    } catch (_) {
      return _drop(RecordDropReason.invalidInput);
    }
    // Eligibility/representation for outputs do not depend on store acceptance.
    _dispatch(raw, policy);
    final DiagnosticRecord stored;
    try {
      stored = mode == RecordMode.storeRaw ? raw : policy.apply(raw);
    } catch (_) {
      return _drop(RecordDropReason.redactionFailed);
    }
    final receipt = RecordReceipt._(stored.id, null);
    if (_store.kind == StorageKind.memory) {
      try {
        final operation = _store.appendAndRetain(stored, retention: retention);
        if (operation is Future<void>) {
          unawaited(
            operation.catchError((Object e, StackTrace st) {
              _warn('storage_async_violation', 'Memory store write failed: $e');
            }),
          );
          throw StateError('Memory store must write synchronously');
        }
        receipt._complete();
      } catch (_) {
        return _drop(RecordDropReason.storageFailed);
      }
    } else {
      if (_pending.length >= pendingRecordLimit) {
        return _drop(RecordDropReason.queueFull);
      }
      _pending.add(_Write(stored, receipt));
      if (!_running) {
        _running = true;
        unawaited(_runWrites());
      }
    }
    _traceIds?.add(stored.id);
    return receipt;
  }

  Future<void> _runWrites() async {
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final write = _pending.removeFirst();
        _active = write;
        try {
          await _store.appendAndRetain(write.record, retention: retention);
          write.receipt._complete(
            _disposed ? null : PersistenceConfirmation(write.record.id),
          );
        } catch (_) {
          write.receipt._complete();
          _warn('persistenceFailed', 'Persistent write failed');
        } finally {
          if (identical(_active, write)) _active = null;
        }
      }
    } finally {
      _running = false;
    }
  }

  void _dispatch(DiagnosticRecord raw, RedactionPolicy policy) {
    final targets = <DiagnosticSink>[];
    for (final sink in _sinks) {
      try {
        final matches = switch (raw.payload) {
          HttpPayload p => sink.httpDispatchPolicy?.matches(p) ?? false,
          LogPayload p => sink.logDispatchPolicy?.matches(p) ?? false,
        };
        if (matches) targets.add(sink);
      } catch (_) {
        _warn('sinkFilterFailed', 'Sink filtering failed');
      }
    }
    if (targets.isEmpty) return;
    // Avoid invoking output I/O on the producer path. Capture policy above.
    scheduleMicrotask(() {
      if (_disposed) return;
      final DiagnosticRecord record;
      try {
        record = policy.apply(raw);
      } catch (_) {
        _warn('dispatchRedactionFailed', 'Dispatch redaction failed');
        return;
      }
      for (final sink in targets) {
        try {
          final result = sink.dispatch(record);
          if (result is Future<void>) {
            unawaited(
              result.catchError((Object e, StackTrace st) {
                _warn('sinkFailed', 'Sink dispatch failed');
              }),
            );
          }
        } catch (_) {
          _warn('sinkFailed', 'Sink dispatch failed');
        }
      }
    });
  }

  Future<DiagnosticRecord?> getById(String id) {
    _checkOpen();
    return _store.getById(id);
  }

  Future<List<DiagnosticRecord>> getByIds(List<String> ids) {
    _checkOpen();
    return _store.getByIds(ids);
  }

  Future<RecordPage> query(RecordQuery query) {
    _checkOpen();
    return _store.query(query);
  }

  Future<int> deleteByIds(List<String> ids) {
    _checkOpen();
    return _store.deleteByIds(ids);
  }

  Future<int> clearRecords() {
    _checkOpen();
    return _store.clearRecords();
  }

  void startTrace() {
    _checkOpen();
    if (_traceIds != null) throw StateError('Trace already active');
    _traceFrom = _clock().toUtc();
    _traceIds = [];
  }

  Future<TraceSession?> stopTrace({String? name}) async {
    _checkOpen();
    final ids = _traceIds;
    if (ids == null) throw StateError('No active trace');
    final from = _traceFrom!;
    _traceIds = null;
    _traceFrom = null;
    if (ids.isEmpty) return null;
    final session = TraceSession(
      id: createRecordId(),
      name: name,
      from: from,
      to: _clock(),
      recordIds: ids,
    );
    await _store.saveTraceSession(session);
    return session;
  }

  Future<TraceSession?> createTraceSession({
    required DateTime from,
    required DateTime to,
    String? name,
  }) async {
    _checkOpen();
    final ids = <String>[];
    String? cursor;
    do {
      final page = await _store.query(
        RecordQuery(from: from, to: to, cursor: cursor),
      );
      ids.addAll(page.records.map((r) => r.id));
      cursor = page.nextCursor;
    } while (cursor != null);
    if (ids.isEmpty) return null;
    final session = TraceSession(
      id: createRecordId(),
      name: name,
      from: from,
      to: to,
      recordIds: ids.reversed,
    );
    await _store.saveTraceSession(session);
    return session;
  }

  Future<List<TraceSession>> listTraceSessions() {
    _checkOpen();
    return _store.listTraceSessions();
  }

  Future<bool> deleteTraceSession(String id) {
    _checkOpen();
    return _store.deleteTraceSession(id);
  }

  Future<ExportResult> exportTraceSession(
    String id, {
    ExportRepresentation representation = ExportRepresentation.redacted,
  }) async {
    final policy = _redactionPolicy;
    try {
      _checkOpen();
      final sessions = await _store.listTraceSessions();
      final session = sessions.where((s) => s.id == id).firstOrNull;
      if (session == null) return const ExportResult.empty();
      return await _exportRecords(session.recordIds, representation, policy);
    } catch (_) {
      return const ExportResult.failed('Trace query failed');
    }
  }

  Future<ExportResult> exportRecords(
    List<String> ids, {
    ExportRepresentation representation = ExportRepresentation.redacted,
  }) =>
      _exportRecords(List.unmodifiable(ids), representation, _redactionPolicy);

  Future<ExportResult> _exportRecords(
    List<String> ids,
    ExportRepresentation representation,
    RedactionPolicy policy,
  ) async {
    try {
      _checkOpen();
      final records = await _store.getByIds(ids);
      if (records.isEmpty) return const ExportResult.empty();
      final copies = records
          .map(
            (r) => representation == ExportRepresentation.redacted
                ? policy.apply(r)
                : r,
          )
          .toList();
      final text = copies
          .map((r) => const JsonEncoder.withIndent('  ').convert(r.toJson()))
          .join('\n\n');
      return ExportResult.success(text, copies.length);
    } catch (_) {
      _warn('exportFailed', 'Export failed');
      return const ExportResult.failed('Query or redaction failed');
    }
  }

  Future<ExportResult> formatHttpFragment(
    String id,
    HttpFragment fragment, {
    ExportRepresentation representation = ExportRepresentation.redacted,
    HeaderTarget target = HeaderTarget.both,
  }) async {
    final policy = _redactionPolicy;
    try {
      _checkOpen();
      var record = await _store.getById(id);
      if (record == null) return const ExportResult.empty();
      if (representation == ExportRepresentation.redacted) {
        record = policy.apply(record);
      }
      final p = record.payload;
      if (p is! HttpPayload) {
        return const ExportResult.failed('Not an HTTP record');
      }
      String encode(Object? value) => value is String
          ? value
          : const JsonEncoder.withIndent('  ').convert(value);
      final String text;
      switch (fragment) {
        case HttpFragment.headers:
          text = encode({
            if (target.includesRequest) 'request': p.requestHeaders,
            if (target.includesResponse) 'response': p.response?.headers,
          });
        case HttpFragment.body:
          String bodyText(BodySnapshot? body) =>
              body?.state == BodyCaptureState.captured
              ? encode(body!.data)
              : '[Body ${body?.state.name ?? 'absent'}]';
          if (target == HeaderTarget.request) {
            text = bodyText(p.requestBody);
          } else if (target == HeaderTarget.response) {
            text = bodyText(p.response?.body);
          } else {
            text =
                'Request body:\n${bodyText(p.requestBody)}\n\nResponse body:\n${bodyText(p.response?.body)}';
          }
        case HttpFragment.curl:
          final body = p.requestBody;
          final unreplayableBody =
              body != null &&
              body.state != BodyCaptureState.absent &&
              (body.state != BodyCaptureState.captured ||
                  body.representation == BodyRepresentation.media);
          final incomplete =
              record.recordMode == RecordMode.redactBeforeRecording ||
              representation == ExportRepresentation.redacted ||
              unreplayableBody;
          text =
              '${incomplete ? '# Diagnostic representation; replay may be incomplete\n' : ''}${formatHttpCurl(p)}';
      }
      return ExportResult.success(text, 1);
    } catch (_) {
      return const ExportResult.failed('Fragment formatting failed');
    }
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    final completion = Completer<void>();
    _disposeFuture = completion.future;
    unawaited(
      _dispose().then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  Future<void> _dispose() async {
    _disposed = true;
    for (final write in _pending) {
      write.receipt._complete();
    }
    _pending.clear();
    _active?.receipt._complete();
    _traceIds = null;
    _traceFrom = null;
    // Not a drain: resource-close behavior decides any active operation's fate.
    final closing = <Future<void>>[];
    for (final sink in _sinks) {
      closing.add(
        Future.sync(sink.dispose).catchError((Object e, StackTrace st) {
          _warn('sinkCloseFailed', 'Sink disposal failed');
        }),
      );
    }
    closing.add(
      Future.sync(_store.close).catchError((Object e, StackTrace st) {
        _warn('storeCloseFailed', 'Store close failed');
      }),
    );
    await Future.wait(closing);
  }
}
