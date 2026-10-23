import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_drift_diagnostic_store/codekit_drift_diagnostic_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late String databasePath;
  late DriftDiagnosticStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('codekit-drift-test-');
    databasePath = '${directory.path}/nested/diagnostics.sqlite';
    store = await DriftDiagnosticStore.open(databasePath: databasePath);
  });

  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test('persists records and Trace sessions across close and reopen', () async {
    final first = record('first', 'alpha');
    final second = record('second', 'beta');
    await store.appendAndRetain(first, retention: RetentionPolicy());
    await store.appendAndRetain(second, retention: RetentionPolicy());
    final session = TraceSession(
      id: 'trace-1',
      name: 'reopen test',
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 1, 2),
      recordIds: ['second', 'first', 'second'],
    );
    await store.saveTraceSession(session);
    await store.close();

    store = await DriftDiagnosticStore.open(databasePath: databasePath);
    expect((await store.getById('first'))?.id, 'first');
    expect(
      (await store.getByIds(['second', 'missing', 'first', 'second']))
          .map((value) => value.id),
      ['second', 'first'],
    );
    final sessions = await store.listTraceSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.recordIds, ['second', 'first']);
  });

  test(
    'regex pagination scans rows without missing or duplicating matches',
    () async {
      for (var index = 0; index < 31; index++) {
        final message = index == 30 || index % 4 == 1
            ? 'match-$index'
            : 'skip-$index';
        await store.appendAndRetain(
          record('id-$index', message),
          retention: RetentionPolicy(),
        );
      }

      final allMatching = <String>[];
      String? cursor;
      do {
        final page = await store.query(
          RecordQuery(limit: 2, regex: RegExp(r'^match-'), cursor: cursor),
        );
        allMatching.addAll(page.records.map((value) => value.id));
        cursor = page.nextCursor;
      } while (cursor != null);

      expect(allMatching, hasLength(9));
      expect(allMatching.toSet(), hasLength(allMatching.length));
      expect(allMatching.first, 'id-30');
      expect(allMatching.last, 'id-1');
    },
  );

  test('retention evicts an oldest-record batch atomically', () async {
    final retention = RetentionPolicy(maxRecords: 100);
    for (var index = 0; index < 101; index++) {
      await store.appendAndRetain(
        record('id-$index', 'record-$index'),
        retention: retention,
      );
    }

    expect(await store.getById('id-0'), isNull);
    expect(await store.getById('id-4'), isNull);
    expect(await store.getById('id-5'), isNotNull);
    final page = await store.query(RecordQuery(limit: 200));
    expect(page.records, hasLength(96));
  });

  test('deletes records without cascading Trace session IDs', () async {
    await store.appendAndRetain(
      record('kept', 'kept'),
      retention: RetentionPolicy(),
    );
    await store.saveTraceSession(
      TraceSession(
        id: 'trace',
        from: DateTime.utc(2026),
        to: DateTime.utc(2026, 1, 1, 0, 1),
        recordIds: ['kept', 'missing'],
      ),
    );
    expect(await store.deleteByIds(['kept']), 1);
    expect((await store.listTraceSessions()).single.recordIds, [
      'kept',
      'missing',
    ]);
    expect(await store.deleteTraceSession('trace'), isTrue);
    expect(await store.deleteTraceSession('trace'), isFalse);
  });

  test('factory diagnostics owns and closes its persistent store', () async {
    final factoryPath = '${directory.path}/factory.sqlite';
    final diagnostics = await createDriftDiagnostics(databasePath: factoryPath);
    final receipt = diagnostics.log(const LogInput(message: 'factory record'));
    final confirmation = await receipt.persistedOrNull();
    expect(confirmation?.recordId, receipt.recordId);
    await diagnostics.dispose();

    final reopened = await DriftDiagnosticStore.open(databasePath: factoryPath);
    expect(await reopened.getById(receipt.recordId!), isNotNull);
    await reopened.close();
  });

  test('query returns lightweight summary records while getById returns full body and headers', () async {
    final httpRecord = DiagnosticRecord(
      id: 'lazy-test',
      recordedAt: DateTime.utc(2026, 1, 1),
      recordMode: RecordMode.storeRaw,
      context: {'deep': 'context'},
      payload: HttpPayload(
        requestStartedAt: DateTime.utc(2026, 1, 1),
        method: 'POST',
        uri: Uri.parse('https://api.example.com/items'),
        duration: const Duration(milliseconds: 42),
        requestHeaders: {
          'authorization': ['Bearer token'],
        },
        requestBody: const BodySnapshot.text('request-payload'),
        response: HttpResponseSnapshot(
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: const BodySnapshot.text('response-payload'),
        ),
      ),
    );

    await store.appendAndRetain(httpRecord, retention: RetentionPolicy());

    final page = await store.query(RecordQuery());
    expect(page.records, hasLength(1));
    final summary = page.records.first;
    expect(summary.id, 'lazy-test');
    expect(summary.context, isNull);
    final summaryPayload = summary.payload as HttpPayload;
    expect(summaryPayload.method, 'POST');
    expect(summaryPayload.uri.toString(), 'https://api.example.com/items');
    expect(summaryPayload.duration?.inMilliseconds, 42);
    expect(summaryPayload.requestHeaders, isNull);
    expect(summaryPayload.requestBody, isNull);
    expect(summaryPayload.response?.statusCode, 200);
    expect(summaryPayload.response?.headers, isNull);
    expect(summaryPayload.response?.body, isNull);

    final full = (await store.getById('lazy-test'))!;
    expect(full.context, {'deep': 'context'});
    final fullPayload = full.payload as HttpPayload;
    expect(fullPayload.requestHeaders, {
      'authorization': ['Bearer token'],
    });
    expect(fullPayload.requestBody?.data, 'request-payload');
    expect(fullPayload.response?.body?.data, 'response-payload');
    expect(fullPayload.response?.headers, {
      'content-type': ['application/json'],
    });
  });
}

DiagnosticRecord record(String id, String message) => DiagnosticRecord(
  id: id,
  recordedAt: DateTime.utc(2026, 1, 1),
  recordMode: RecordMode.storeRaw,
  payload: LogPayload(message: message),
);
