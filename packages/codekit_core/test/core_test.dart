import 'dart:convert';
import 'dart:async';

import 'package:codekit_core/codekit_core.dart';
import 'package:test/test.dart';

import 'support/controlled_store.dart';

HttpInput request(
  String id, {
  BodySnapshot? body,
  int? status = 200,
  Map<String, List<String>>? headers,
  Duration? duration,
}) => HttpInput(
  recordId: id,
  requestStartedAt: DateTime.utc(2026),
  method: 'POST',
  uri: Uri.parse('https://example.com/payments?token=secret&token=second'),
  duration: duration,
  requestHeaders: headers,
  requestBody: body,
  response: status == null ? null : HttpResponseSnapshot(statusCode: status),
);
void main() {
  test(
    'base64 image preset masks body values, preserving other fields',
    () async {
      const image = 'iVBORw0KGgo=';
      final d = CodeKitDiagnostics(
        recordMode: RecordMode.redactBeforeRecording,
      );
      addTearDown(d.dispose);
      final receipt = d.log(
        HttpInput(
          recordId: 'image',
          requestStartedAt: DateTime.utc(2026),
          method: 'POST',
          uri: Uri.parse('https://example.com/?image=$image'),
          context: const {'image': image},
          requestHeaders: const {
            'image': [image],
          },
          requestBody: const BodySnapshot.json({
            'items': [
              {'image': image, 'keep': 'test'},
            ],
            image: 42,
          }),
          response: HttpResponseSnapshot(
            body: BodySnapshot.text(' {"image":"$image"} '),
          ),
        ),
      );
      expect(receipt.accepted, isTrue);
      final record = (await d.getById('image'))!;
      final payload = record.payload as HttpPayload;
      expect(payload.requestBody!.data, {
        'items': [
          {'image': redactionMarker, 'keep': 'test'},
        ],
        image: 42,
      });
      expect(payload.requestBody!.representation, BodyRepresentation.json);
      expect(jsonDecode(payload.response!.body!.data as String), {
        'image': redactionMarker,
      });
      expect(record.context!['image'], image);
      expect(payload.requestHeaders!['image'], [image]);
      expect(payload.uri.queryParameters['image'], image);
      expect(d.redactionPolicy.apply(record).toJson(), record.toJson());
      for (final text in [
        image,
        'data:image/png;base64,$image',
        jsonEncode(image),
      ]) {
        final id = d.createRecordId();
        d.log(request(id, body: BodySnapshot.text(text)));
        final body =
            ((await d.getById(id))!.payload as HttpPayload).requestBody!;
        expect(body.representation, BodyRepresentation.text);
        expect(
          body.data,
          text.startsWith('"') ? jsonEncode(redactionMarker) : redactionMarker,
        );
      }
      for (final text in [
        '  {"keep": "test"}  ',
        'ordinary text',
        'iVBORw0KGgo=!',
      ]) {
        final id = d.createRecordId();
        d.log(request(id, body: BodySnapshot.text(text)));
        expect(
          ((await d.getById(id))!.payload as HttpPayload).requestBody!.data,
          text,
        );
      }
    },
  );
  test(
    'base64 preset honors raw storage, export, dispatch and opt-out',
    () async {
      const image = 'iVBORw0KGgo=';
      final sink = CollectingSink(httpDispatchPolicy: HttpDispatchPolicy());
      final d = CodeKitDiagnostics(sinks: [sink]);
      addTearDown(d.dispose);
      d.log(request('raw-image', body: const BodySnapshot.text(image)));
      await Future<void>.value();
      expect(
        ((await d.getById('raw-image'))!.payload as HttpPayload)
            .requestBody!
            .data,
        image,
      );
      expect(
        (sink.records.single.payload as HttpPayload).requestBody!.data,
        redactionMarker,
      );
      expect(
        (await d.exportRecords(['raw-image'])).text,
        isNot(contains(image)),
      );
      expect(
        (await d.exportRecords([
          'raw-image',
        ], representation: ExportRepresentation.asStored)).text,
        contains(image),
      );
      d.redactionPolicy = RedactionPolicy(base64Images: false);
      d.recordMode = RecordMode.redactBeforeRecording;
      d.log(request('opt-out', body: const BodySnapshot.text(image)));
      await Future<void>.value();
      expect(
        ((await d.getById('opt-out'))!.payload as HttpPayload)
            .requestBody!
            .data,
        image,
      );
      expect(
        (sink.records.last.payload as HttpPayload).requestBody!.data,
        image,
      );
      expect((await d.exportRecords(['raw-image'])).text, contains(image));
    },
  );
  test(
    'memory receipt is immediate and snapshots detach nested input',
    () async {
      final d = CodeKitDiagnostics();
      addTearDown(d.dispose);
      final child = <String, Object?>{'email': 'before'};
      final context = <String, Object?>{'user': child};
      final tags = {'event'};
      final receipt = d.log(
        LogInput(message: 'hello', context: context, tags: tags),
      );
      expect(receipt.accepted, isTrue);
      child['email'] = 'after';
      tags.add('new');
      final r = (await d.getById(receipt.recordId!))!;
      expect((r.context!['user'] as Map)['email'], 'before');
      expect((r.payload as LogPayload).tags, {'event'});
      expect(
        () => (r.context!['user'] as Map)['email'] = 'mutate',
        throwsUnsupportedError,
      );
      expect(await receipt.persistedOrNull(), isNull);
    },
  );
  test(
    'invalid JSON context is dropped and warning errors cannot escape logging',
    () async {
      final d = CodeKitDiagnostics(
        onWarning: (_) => throw StateError('warning listener'),
      );
      addTearDown(d.dispose);
      final cycle = <String, Object?>{};
      cycle['self'] = cycle;
      for (final context in [
        {'bad': Object()},
        {'bad': double.nan},
        cycle,
      ]) {
        final r = d.log(LogInput(message: 'bad', context: context));
        expect(r.dropReason, RecordDropReason.invalidInput);
        expect(r.recordId, isNull);
        expect(await r.persistedOrNull(), isNull);
      }
      expect((await d.query(RecordQuery())).records, isEmpty);
    },
  );
  test('HTTP body and repeated headers detach without client types', () async {
    final d = CodeKitDiagnostics();
    addTearDown(d.dispose);
    final headers = {
      'X-Test': ['one', 'two'],
    };
    final body = {
      'users': [
        {'name': 'before'},
      ],
    };
    final id = d.createRecordId();
    d.log(request(id, headers: headers, body: BodySnapshot.json(body)));
    headers['X-Test']!.clear();
    body['users']!.first['name'] = 'after';
    final p = (await d.getById(id))!.payload as HttpPayload;
    expect(p.requestHeaders!['X-Test'], ['one', 'two']);
    expect(
      ((p.requestBody!.data as Map)['users'] as List).first['name'],
      'before',
    );
  });
  test('retention clamps to 100 and evicts five oldest in one batch; Trace remains', () async {
    final d = CodeKitDiagnostics(retention: RetentionPolicy(maxRecords: 1));
    addTearDown(d.dispose);
    d.startTrace();
    expect(d.activeTraceRecordCount, 0);
    final ids = <String>[];
    for (var i = 0; i < 101; i++) {
      ids.add(d.log(LogInput(message: '$i')).recordId!);
    }
    expect(d.activeTraceRecordCount, 101);
    final session = (await d.stopTrace())!;
    expect(d.activeTraceRecordCount, 0);
    expect(d.retention.maxRecords, 100);
    expect(session.recordIds.length, 101);
    expect((await d.query(RecordQuery())).records.length, 96);
    expect(await d.getByIds(ids.take(5).toList()), isEmpty);
    expect((await d.exportTraceSession(session.id)).recordCount, 96);
    await d.clearRecords();
    expect((await d.listTraceSessions()).single.id, session.id);
    expect((await d.exportTraceSession(session.id)).status, ExportStatus.empty);
  });
  test('unlimited is default and 101 limit evicts six', () async {
    final d = CodeKitDiagnostics();
    final limited = CodeKitDiagnostics(
      retention: RetentionPolicy(maxRecords: 101),
    );
    addTearDown(d.dispose);
    addTearDown(limited.dispose);
    for (var i = 0; i < 102; i++) {
      d.log(LogInput(message: '$i'));
      limited.log(LogInput(message: '$i'));
    }
    expect((await d.query(RecordQuery(limit: 200))).records.length, 102);
    expect((await limited.query(RecordQuery(limit: 200))).records.length, 96);
  });
  test(
    'regex pagination does not miss sparse matches; deleted cursor still works',
    () async {
      final d = CodeKitDiagnostics();
      addTearDown(d.dispose);
      final matching = <String>[];
      for (var i = 0; i < 310; i++) {
        final r = d.log(LogInput(message: i % 101 == 0 ? 'match-$i' : 'other'));
        if (i % 101 == 0) matching.add(r.recordId!);
      }
      final regex = RegExp(r'^match-');
      final first = await d.query(RecordQuery(regex: regex, limit: 2));
      expect(first.records.map((r) => r.id), matching.reversed.take(2));
      await d.deleteByIds([first.records.last.id]);
      d.log(const LogInput(message: 'match-new'));
      final second = await d.query(
        RecordQuery(regex: regex, limit: 10, cursor: first.nextCursor),
      );
      expect(second.records.map((r) => r.id), matching.reversed.skip(2));
      expect(second.nextCursor, isNull);
      await expectLater(
        d.query(RecordQuery(text: 'other', cursor: first.nextCursor)),
        throwsArgumentError,
      );
    },
  );
  test('query AND filters, inclusive range, unknown status and independent body search', () async {
    var now = DateTime.utc(2026);
    final d = CodeKitDiagnostics(clock: () => now);
    addTearDown(d.dispose);
    d.log(
      request(
        'http-1',
        status: 500,
        duration: const Duration(seconds: 2),
        body: const BodySnapshot.text('body-secret'),
      ),
    );
    now = now.add(const Duration(seconds: 1));
    d.log(const LogInput(message: 'App failed'));
    final page = await d.query(
      RecordQuery(
        types: {DiagnosticRecordType.http},
        statusGroups: {HttpStatusGroup.serverError},
        durationLevels: {DurationLevel.warn},
        from: DateTime.utc(2026),
        to: DateTime.utc(2026),
      ),
    );
    expect(page.records.single.id, 'http-1');
    expect((await d.query(RecordQuery(text: 'body-secret'))).records, isEmpty);
    expect(
      (await d.query(RecordQuery(statusGroups: {HttpStatusGroup.unknown})))
          .records
          .single
          .payload,
      isA<LogPayload>(),
    );
  });
  test(
    'preset and body redaction preserve keys; raw export remains raw',
    () async {
      final d = CodeKitDiagnostics(
        redactionPolicy: RedactionPolicy(
          rules: [
            QueryRedactionRule(['token']),
            BodyFieldRedactionRule(['user.email', 'files']),
          ],
        ),
      );
      addTearDown(d.dispose);
      d.log(
        request(
          'http',
          headers: {
            'Authorization': ['secret', 'second'],
            'Keep': ['visible'],
          },
          body: const BodySnapshot.text(
            '{"user":{"email":"secret","name":"visible"},"files":[1,2]}',
          ),
        ),
      );
      final stored = (await d.getById('http'))!.payload as HttpPayload;
      expect(stored.requestHeaders!['Authorization'], ['secret', 'second']);
      final exported = await d.exportRecords(['http']);
      final json = jsonDecode(exported.text!);
      final p = json['payload'];
      expect(p['requestHeaders']['Authorization'], [
        redactionMarker,
        redactionMarker,
      ]);
      expect(
        jsonDecode(p['requestBody']['data'])['user']['email'],
        redactionMarker,
      );
      expect(jsonDecode(p['requestBody']['data'])['user']['name'], 'visible');
      expect(Uri.parse(p['uri']).queryParametersAll['token'], [
        redactionMarker,
        redactionMarker,
      ]);
      expect(
        (await d.exportRecords([
          'http',
        ], representation: ExportRepresentation.asStored)).text,
        contains('secret'),
      );
    },
  );
  test('record mode/policy changes affect future operations only', () async {
    final d = CodeKitDiagnostics(recordMode: RecordMode.redactBeforeRecording);
    addTearDown(d.dispose);
    d.log(
      request(
        'redacted',
        headers: {
          'Authorization': ['secret'],
        },
      ),
    );
    d.recordMode = RecordMode.storeRaw;
    d.log(
      request(
        'raw',
        headers: {
          'Authorization': ['secret'],
        },
      ),
    );
    expect(
      ((await d.getById('redacted'))!.payload as HttpPayload)
          .requestHeaders!['Authorization'],
      [redactionMarker],
    );
    expect(
      ((await d.getById('raw'))!.payload as HttpPayload)
          .requestHeaders!['Authorization'],
      ['secret'],
    );
    d.redactionPolicy = RedactionPolicy(authorization: false);
    expect((await d.exportRecords(['raw'])).text, contains('secret'));
    expect(
      (await d.exportRecords([
        'redacted',
      ], representation: ExportRepresentation.asStored)).text,
      contains(redactionMarker),
    );
  });
  test(
    'simple body paths reject wildcard/index and do not traverse arrays',
    () async {
      expect(
        () => BodyFieldRedactionRule(['users.*.email']),
        throwsArgumentError,
      );
      expect(
        () => BodyFieldRedactionRule(['users[0].email']),
        throwsArgumentError,
      );
      final d = CodeKitDiagnostics(
        recordMode: RecordMode.redactBeforeRecording,
        redactionPolicy: RedactionPolicy(
          rules: [
            BodyFieldRedactionRule(['users.email', 'missing']),
          ],
        ),
      );
      addTearDown(d.dispose);
      d.log(
        request(
          'array',
          body: const BodySnapshot.json({
            'users': [
              {'email': 'unchanged'},
            ],
          }),
        ),
      );
      expect(
        ((await d.getById('array'))!.payload as HttpPayload).requestBody!.data,
        {
          'users': [
            {'email': 'unchanged'},
          ],
        },
      );
    },
  );
  test(
    'text rule protects keys/tags/source and marker on repeated processing',
    () async {
      final d = CodeKitDiagnostics(
        recordMode: RecordMode.redactBeforeRecording,
        redactionPolicy: RedactionPolicy(
          rules: [TextRedactionRule(RegExp('secret|REDACTED'))],
        ),
      );
      addTearDown(d.dispose);
      final receipt = d.log(
        const LogInput(
          message: 'secret',
          source: 'secret',
          tags: {'secret'},
          context: {'secret': 'secret'},
        ),
      );
      final record = (await d.getById(receipt.recordId!))!;
      expect((record.payload as LogPayload).message, redactionMarker);
      expect(record.source, 'secret');
      expect(record.context, {'secret': redactionMarker});
      expect((record.payload as LogPayload).tags, {'secret'});
      expect(
        (await d.exportRecords([record.id])).text,
        contains(redactionMarker),
      );
    },
  );
  test('codec round trips null JSON bodies, schema fields and invalid versions safely', () async {
    final d = CodeKitDiagnostics();
    addTearDown(d.dispose);
    d.log(
      request(
        'codec',
        body: const BodySnapshot.json(null),
        duration: const Duration(microseconds: 123),
      ),
    );
    final record = (await d.getById('codec'))!;
    const codec = DiagnosticRecordCodec();
    final bytes = codec.encode(record);
    final m = jsonDecode(utf8.decode(bytes));
    expect(m['schemaVersion'], 1);
    expect(m['payload']['durationMicros'], 123);
    expect(m['payload']['requestBody'], {
      'state': 'captured',
      'representation': 'json',
      'data': null,
    });
    expect(codec.decode(bytes).record!.toJson(), record.toJson());
    m['schemaVersion'] = 2;
    expect(
      codec.decode(utf8.encode(jsonEncode(m))).status,
      RecordDecodeStatus.unsupportedVersion,
    );
    expect(codec.decode([255]).status, RecordDecodeStatus.invalid);
    m['schemaVersion'] = 1;
    m['payload']['durationMicros'] = -1;
    expect(
      codec.decode(utf8.encode(jsonEncode(m))).status,
      RecordDecodeStatus.invalid,
    );
  });
  test('sink policy tags/status exclusions and null/empty semantics', () {
    final log = LogPayload(message: 'paid', tags: {'paid', 'test'});
    expect(
      LogDispatchPolicy(
        includeTags: {'paid'},
        excludeTags: {'test'},
      ).matches(log),
      isFalse,
    );
    expect(LogDispatchPolicy().matches(log), isTrue);
    expect(LogDispatchPolicy(levels: {}).matches(log), isFalse);
    final http = HttpPayload(
      requestStartedAt: DateTime.utc(2026),
      method: 'POST',
      uri: Uri.parse('https://a/payments/test'),
      response: const HttpResponseSnapshot(statusCode: 500),
    );
    expect(
      HttpDispatchPolicy(
        includeUriPatterns: [RegExp('payments')],
        excludeUriPatterns: [RegExp('test')],
      ).matches(http),
      isFalse,
    );
    expect(HttpDispatchPolicy(statusGroups: {}).matches(http), isFalse);
  });
  test(
    'raw store and redacted sinks are independent; sink failure isolated',
    () async {
      final failed = CollectingSink(logDispatchPolicy: LogDispatchPolicy())
        ..fail = true;
      final ok = CollectingSink(
        logDispatchPolicy: LogDispatchPolicy(includeTags: {'crash'}),
      );
      final d = CodeKitDiagnostics(
        sinks: [failed, ok],
        redactionPolicy: RedactionPolicy(
          rules: [TextRedactionRule(RegExp('secret'))],
        ),
      );
      addTearDown(d.dispose);
      final receipt = d.log(const LogInput(message: 'secret', tags: {'crash'}));
      expect((await d.getById(receipt.recordId!))!.payload, isA<LogPayload>());
      await Future<void>.value();
      expect(ok.records.single.payload, isA<LogPayload>());
      expect(
        (ok.records.single.payload as LogPayload).message,
        redactionMarker,
      );
      expect(
        ((await d.getById(receipt.recordId!))!.payload as LogPayload).message,
        'secret',
      );
    },
  );
  test(
    'persistent queue preserves FIFO; pending hidden, newest overflow dropped',
    () async {
      final store = ControlledStore();
      final sink = CollectingSink(logDispatchPolicy: LogDispatchPolicy());
      final d = CodeKitDiagnostics(
        store: store,
        pendingRecordLimit: 1,
        sinks: [sink],
      );
      addTearDown(d.dispose);
      d.startTrace();
      final a = d.log(const LogInput(message: 'a'));
      final b = d.log(const LogInput(message: 'b'));
      final c = d.log(const LogInput(message: 'c'));
      expect(a.accepted, isTrue);
      expect(b.accepted, isTrue);
      expect(c.dropReason, RecordDropReason.queueFull);
      expect((await d.query(RecordQuery())).records, isEmpty);
      final trace = (await d.stopTrace())!;
      expect(trace.recordIds, [a.recordId, b.recordId]);
      expect((await d.exportTraceSession(trace.id)).status, ExportStatus.empty);
      expect(
        sink.records.length,
        3,
      ); // storage rejection does not gate dispatch.
      store.release(0);
      expect((await a.persistedOrNull())!.recordId, a.recordId);
      expect(store.started, [a.recordId, b.recordId]);
      store.release(1);
      expect((await b.persistedOrNull())!.recordId, b.recordId);
      expect((await d.exportTraceSession(trace.id)).recordCount, 2);
    },
  );
  test('write failure is safe and does not stop later writes or fake query success', () async {
    final store = ControlledStore()..failNext = true;
    final warnings = <DiagnosticWarning>[];
    final d = CodeKitDiagnostics(store: store, onWarning: warnings.add);
    addTearDown(d.dispose);
    final a = d.log(const LogInput(message: 'bad'));
    final b = d.log(const LogInput(message: 'good'));
    store.release(0);
    expect(await a.persistedOrNull(), isNull);
    store.release(1);
    expect(await b.persistedOrNull(), isNotNull);
    expect(warnings.any((w) => w.code == 'persistenceFailed'), isTrue);
    store.failReads = true;
    expect((await d.exportRecords([b.recordId!])).status, ExportStatus.failed);
  });
  test('Clear has no pending barrier; dispose safely settles pending and active receipts', () async {
    final store = ControlledStore();
    final d = CodeKitDiagnostics(store: store);
    final a = d.log(const LogInput(message: 'a'));
    await d.clearRecords();
    store.release(0);
    await a.persistedOrNull();
    expect(await d.getById(a.recordId!), isNotNull);
    final b = d.log(const LogInput(message: 'b'));
    final c = d.log(const LogInput(message: 'c'));
    final closing = d.dispose();
    expect(identical(closing, d.dispose()), isTrue);
    await closing;
    expect(await b.persistedOrNull(), isNull);
    expect(await c.persistedOrNull(), isNull);
    expect(
      d.log(const LogInput(message: 'late')).dropReason,
      RecordDropReason.disposed,
    );
    store.release(1);
    await Future<void>.value();
  });
  test(
    'picker Trace is inclusive and missing IDs do not delete session',
    () async {
      var now = DateTime.utc(2026);
      final d = CodeKitDiagnostics(clock: () => now);
      addTearDown(d.dispose);
      final a = d.log(const LogInput(message: 'a'));
      now = now.add(const Duration(seconds: 1));
      d.log(const LogInput(message: 'b'));
      final session = (await d.createTraceSession(
        from: DateTime.utc(2026),
        to: DateTime.utc(2026),
      ))!;
      expect(session.recordIds, [a.recordId]);
      await d.deleteByIds([a.recordId!]);
      expect(
        (await d.exportTraceSession(session.id)).status,
        ExportStatus.empty,
      );
      expect((await d.listTraceSessions()).length, 1);
      expect(
        await d.createTraceSession(
          from: DateTime.utc(2000),
          to: DateTime.utc(2001),
        ),
        isNull,
      );
    },
  );
  test('duplicate HTTP ID does not overwrite memory record', () async {
    final d = CodeKitDiagnostics();
    addTearDown(d.dispose);
    expect(d.log(request('same', status: 200)).accepted, isTrue);
    expect(
      d.log(request('same', status: 500)).dropReason,
      RecordDropReason.storageFailed,
    );
    expect(
      ((await d.getById('same'))!.payload as HttpPayload).response!.statusCode,
      200,
    );
  });
  test('global capture exclusion prevents storage and every sink before normalization', () async {
    final sink = CollectingSink(httpDispatchPolicy: HttpDispatchPolicy());
    final d = CodeKitDiagnostics(
      sinks: [sink],
      captureExcludeUriPatterns: [RegExp('payments')],
    );
    addTearDown(d.dispose);
    expect(d.shouldCaptureHttp(Uri.parse('https://a/payments')), isFalse);
    final receipt = d.log(
      request('excluded', body: BodySnapshot.json(Object())),
    );
    expect(receipt.dropReason, RecordDropReason.excluded);
    await Future<void>.value();
    expect(sink.records, isEmpty);
    expect((await d.query(RecordQuery())).records, isEmpty);
    d.captureExcludeUriPatterns = null;
    expect(d.log(request('allowed')).accepted, isTrue);
  });
  test(
    'export captures policy before async read and never mutates stored data',
    () async {
      final store = ControlledStore();
      final d = CodeKitDiagnostics(
        store: store,
        redactionPolicy: RedactionPolicy(
          rules: [TextRedactionRule(RegExp('secret'))],
        ),
      );
      addTearDown(d.dispose);
      final receipt = d.log(const LogInput(message: 'secret'));
      store.release(0);
      await receipt.persistedOrNull();
      store.readGate = Completer<void>();
      final exporting = d.exportRecords([receipt.recordId!]);
      d.redactionPolicy = RedactionPolicy();
      store.readGate!.complete();
      expect((await exporting).text, contains(redactionMarker));
      expect(
        ((await d.getById(receipt.recordId!))!.payload as LogPayload).message,
        'secret',
      );
    },
  );
  test('text rule with no match preserves captured JSON whitespace', () async {
    final d = CodeKitDiagnostics(
      recordMode: RecordMode.redactBeforeRecording,
      redactionPolicy: RedactionPolicy(
        rules: [TextRedactionRule(RegExp('missing'))],
      ),
    );
    addTearDown(d.dispose);
    const raw = '{ "value": "visible" }';
    d.log(request('spacing', body: const BodySnapshot.text(raw)));
    expect(
      ((await d.getById('spacing'))!.payload as HttpPayload).requestBody!.data,
      raw,
    );
  });
  test('body copy uses full captured text; curl quotes apostrophes without execution', () async {
    final d = CodeKitDiagnostics();
    addTearDown(d.dispose);
    const body = "O'Reilly";
    d.log(request('fragment', body: const BodySnapshot.text(body)));
    final copied = await d.formatHttpFragment(
      'fragment',
      HttpFragment.body,
      target: HeaderTarget.request,
      representation: ExportRepresentation.asStored,
    );
    expect(copied.text, body);
    final curl = await d.formatHttpFragment(
      'fragment',
      HttpFragment.curl,
      representation: ExportRepresentation.asStored,
    );
    expect(curl.text, contains("--data-raw"));
    expect(curl.text, contains(r"'O'\''Reilly'"));
    expect(curl.status, ExportStatus.success);
  });
  test('empty manual trace is not saved and explicit lifecycle misuse reports errors', () async {
    final d = CodeKitDiagnostics();
    addTearDown(d.dispose);
    d.startTrace();
    expect(d.startTrace, throwsStateError);
    expect(await d.stopTrace(), isNull);
    expect(await d.listTraceSessions(), isEmpty);
    await expectLater(d.stopTrace(), throwsStateError);
  });
  test(
    'media body exposes metadata only and survives codec/redaction',
    () async {
      final d = CodeKitDiagnostics(
        redactionPolicy: RedactionPolicy(
          rules: [TextRedactionRule(RegExp('private'))],
        ),
      );
      addTearDown(d.dispose);
      d.log(
        request(
          'media',
          body: BodySnapshot.media([
            const MediaFileMetadata(
              fileName: 'photo.jpg',
              contentType: 'image/jpeg',
              sizeBytes: 42,
              path: '/private/photo.jpg',
            ),
          ]),
        ),
      );
      final record = (await d.getById('media'))!;
      const codec = DiagnosticRecordCodec();
      expect(
        codec.decode(codec.encode(record)).record!.toJson(),
        record.toJson(),
      );
      final exported = await d.exportRecords(['media']);
      expect(exported.text, contains(redactionMarker));
      expect(exported.text, contains('photo.jpg'));
      expect(exported.text, isNot(contains('fileBytes')));
      final curl = await d.formatHttpFragment(
        'media',
        HttpFragment.curl,
        representation: ExportRepresentation.asStored,
      );
      expect(curl.text, contains('replay may be incomplete'));
      expect(curl.text, isNot(contains('--data-raw')));
    },
  );
  test(
    'memory store returning failing Future drops record with storageFailed and warns',
    () async {
      final warnings = <DiagnosticWarning>[];
      final fakeMemoryStore = _AsyncFailingMemoryStore();
      final d = CodeKitDiagnostics(
        store: fakeMemoryStore,
        onWarning: warnings.add,
      );
      addTearDown(d.dispose);
      final receipt = d.log(const LogInput(message: 'test'));
      expect(receipt.accepted, isFalse);
      expect(receipt.dropReason, RecordDropReason.storageFailed);
      await pumpEventQueue();
      expect(
        warnings.any((w) => w.code == 'storage_async_violation'),
        isTrue,
      );
    },
  );
}

class _AsyncFailingMemoryStore implements DiagnosticStore {
  @override
  StorageKind get kind => StorageKind.memory;

  @override
  Future<void> appendAndRetain(
    DiagnosticRecord record, {
    required RetentionPolicy retention,
  }) async {
    throw StateError('Asynchronous memory store error');
  }

  @override
  Future<DiagnosticRecord?> getById(String id) async => null;

  @override
  Future<List<DiagnosticRecord>> getByIds(List<String> ids) async => const [];

  @override
  Future<RecordPage> query(RecordQuery query) async =>
      RecordPage(const [], null);

  @override
  Future<int> deleteByIds(List<String> ids) async => 0;

  @override
  Future<int> clearRecords() async => 0;

  @override
  Future<void> saveTraceSession(TraceSession session) async {}

  @override
  Future<List<TraceSession>> listTraceSessions() async => const [];

  @override
  Future<bool> deleteTraceSession(String id) async => false;

  @override
  Future<void> close() async {}
}
