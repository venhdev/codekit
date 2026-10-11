import 'dart:async';

import 'package:codekit_core/codekit_core.dart';

/// Controls write completion to test core queue semantics without disk claims.
class ControlledStore implements DiagnosticStore {
  final memory = MemoryDiagnosticStore();
  final started = <String>[];
  final gates = <Completer<void>>[];
  bool failNext = false;
  bool failReads = false;
  Completer<void>? readGate;
  bool closed = false;
  @override
  StorageKind get kind => StorageKind.persistent;
  @override
  Future<void> appendAndRetain(
    DiagnosticRecord record, {
    required RetentionPolicy retention,
  }) async {
    started.add(record.id);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    if (failNext) {
      failNext = false;
      throw StateError('Controlled write failure');
    }
    if (closed) throw StateError('Closed');
    memory.appendAndRetain(record, retention: retention);
  }

  void release(int index) => gates[index].complete();
  @override
  Future<DiagnosticRecord?> getById(String id) => memory.getById(id);
  @override
  Future<List<DiagnosticRecord>> getByIds(List<String> ids) async {
    if (readGate != null) await readGate!.future;
    if (failReads) throw StateError('Controlled read failure');
    return memory.getByIds(ids);
  }

  @override
  Future<RecordPage> query(RecordQuery query) => memory.query(query);
  @override
  Future<int> deleteByIds(List<String> ids) => memory.deleteByIds(ids);
  @override
  Future<int> clearRecords() => memory.clearRecords();
  @override
  Future<void> saveTraceSession(TraceSession session) =>
      memory.saveTraceSession(session);
  @override
  Future<List<TraceSession>> listTraceSessions() => memory.listTraceSessions();
  @override
  Future<bool> deleteTraceSession(String id) => memory.deleteTraceSession(id);
  @override
  Future<void> close() async {
    closed = true;
    await memory.close();
  }
}

class CollectingSink implements DiagnosticSink {
  @override
  final HttpDispatchPolicy? httpDispatchPolicy;
  @override
  final LogDispatchPolicy? logDispatchPolicy;
  final records = <DiagnosticRecord>[];
  bool fail = false;
  bool disposed = false;
  CollectingSink({this.httpDispatchPolicy, this.logDispatchPolicy});
  @override
  void dispatch(DiagnosticRecord record) {
    if (fail) throw StateError('Sink failed');
    records.add(record);
  }

  @override
  void dispose() {
    disposed = true;
  }
}
