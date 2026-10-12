import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test(
    'get delegates to the inner method and returns its original response',
    () async {
      final diagnostics = CodeKitDiagnostics();
      final base = MethodClient();
      final client = base.withDiagnostics(diagnostics);
      final headers = {'x-test': 'value'};
      final response = await client.get(
        Uri.https('example.test', '/products'),
        headers: headers,
      );
      expect(response, same(base.response));
      expect(base.calledMethod, 'GET');
      expect(base.receivedHeaders, same(headers));
      expect(base.sendCount, 0);
      expect((await diagnostics.query(RecordQuery())).records, hasLength(1));
      client.close();
      await diagnostics.dispose();
    },
  );

  test('send returns the original response and records at headers without reading it', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = MethodClient();
    final client = base.withDiagnostics(diagnostics);
    final response = await client.send(
      http.Request('GET', Uri.https('example.test', '/stream')),
    );
    expect(response, same(base.streamed));
    expect(base.listenCount, 0);
    expect((await diagnostics.query(RecordQuery())).records, hasLength(1));
    await response.stream.drain<void>();
    expect(base.listenCount, 1);
    client.close();
    await diagnostics.dispose();
  });

  test(
    'captures complete JSON, text and read results larger than 1 MiB',
    () async {
      final diagnostics = CodeKitDiagnostics();
      final base = MethodClient();
      final client = base.withDiagnostics(diagnostics);
      final text = 'A' * (2 * 1024 * 1024);
      for (final contentType in ['text/plain', 'application/json']) {
        base.response = http.Response(
          contentType == 'text/plain' ? text : jsonEncode({'data': text}),
          200,
          headers: {'content-type': contentType},
        );
        expect(
          await client.get(Uri.https('example.test', '/large')),
          same(base.response),
        );
        final payload =
            (await diagnostics.query(RecordQuery())).records.first.payload
                as HttpPayload;
        expect(payload.response!.body!.state, BodyCaptureState.captured);
        expect(
          payload.response!.body!.data,
          contentType == 'text/plain' ? text : {'data': text},
        );
      }
      base.readResult = text;
      expect(await client.read(Uri.https('example.test', '/large')), text);
      final read =
          (await diagnostics.query(RecordQuery())).records.first.payload
              as HttpPayload;
      expect(read.response!.body!.data, text);
      client.close();
      await diagnostics.dispose();
    },
  );

  test('captures chunked JSON without changing bytes or URI query', () async {
    final diagnostics = CodeKitDiagnostics();
    final bytes = utf8.encode('{"title":"điện thoại"}');
    final uri = Uri.https('example.test', '/products', {
      'limit': '10',
      'skip': '0',
      'select': 'title,price',
    });
    final client = StreamingClient(
      Stream.fromIterable([bytes.sublist(0, 12), bytes.sublist(12)]),
    ).withDiagnostics(diagnostics);
    final response = await client.get(uri);
    expect(response.bodyBytes, bytes);
    final record = (await diagnostics.query(RecordQuery())).records.single;
    final payload = record.payload as HttpPayload;
    expect(payload.response!.body!.state, BodyCaptureState.captured);
    expect(payload.response!.body!.data, {'title': 'điện thoại'});
    final decoded = DiagnosticRecord.fromJson(record.toJson());
    expect((decoded.payload as HttpPayload).uri, uri);
    client.close();
    await diagnostics.dispose();
  });

  test(
    'preserves an available final response URL and redirect metadata',
    () async {
      final diagnostics = CodeKitDiagnostics();
      final finalUrl = Uri.https('example.test', '/redirected', {'q': 'a,b'});
      final client = StreamingClient(
        Stream.value(utf8.encode('{}')),
        responseUrl: finalUrl,
      ).withDiagnostics(diagnostics);
      final request = http.Request(
        'GET',
        Uri.https('example.test', '/original'),
      );
      final response = await client.send(request);
      expect(response, isA<http.BaseResponseWithUrl>());
      expect((response as http.BaseResponseWithUrl).url, finalUrl);
      expect(response.request, same(request));
      expect(response.contentLength, 2);
      expect(response.isRedirect, isTrue);
      await response.stream.drain<void>();
      client.close();
      await diagnostics.dispose();
    },
  );

  test(
    'request snapshot is detached before deferred response completion',
    () async {
      final diagnostics = CodeKitDiagnostics();
      final client = StreamingClient(Stream.value(utf8.encode('{}')))
          .withDiagnostics(diagnostics);
      final request = http.MultipartRequest(
        'POST',
        Uri.https('example.test', '/upload'),
      )..fields['description'] = 'original';
      final response = await client.send(request);
      request.fields['description'] = 'changed after dispatch';
      await response.stream.drain<void>();
      final payload =
          (await diagnostics.query(RecordQuery())).records.single.payload
              as HttpPayload;
      expect((payload.requestBody!.data as Map)['fields'], {
        'description': 'original',
      });
      client.close();
      await diagnostics.dispose();
    },
  );

  for (final verb in ['HEAD', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    test(
      '$verb preserves custom inner method, parameters, response and error stack',
      () async {
        final diagnostics = CodeKitDiagnostics();
        final base = MethodClient();
        final client = base.withDiagnostics(diagnostics);
        final url = Uri.https('example.test', '/products', {
          'select': 'title,price',
        });
        final headers = {'content-type': 'application/json', 'x-test': 'value'};
        final body = verb == 'HEAD' || verb == 'GET' ? null : '{"ok":true}';
        final encoding = body == null ? null : latin1;
        Future<http.Response> invoke() => switch (verb) {
          'HEAD' => client.head(url, headers: headers),
          'GET' => client.get(url, headers: headers),
          'POST' => client.post(
            url,
            headers: headers,
            body: body,
            encoding: encoding,
          ),
          'PUT' => client.put(
            url,
            headers: headers,
            body: body,
            encoding: encoding,
          ),
          'PATCH' => client.patch(
            url,
            headers: headers,
            body: body,
            encoding: encoding,
          ),
          _ => client.delete(
            url,
            headers: headers,
            body: body,
            encoding: encoding,
          ),
        };
        expect(await invoke(), same(base.response));
        expect(base.calledMethod, verb);
        expect(base.receivedUrl, same(url));
        expect(base.receivedHeaders, same(headers));
        expect(base.receivedBody, same(body));
        expect(base.receivedEncoding, same(encoding));
        expect(base.sendCount, 0);
        final saved =
            (await diagnostics.query(RecordQuery())).records.single.payload
                as HttpPayload;
        expect(saved.method, verb);
        expect(saved.uri, url);
        final error = http.ClientException('original transport failure');
        base.error = error;
        try {
          await invoke();
          fail('Expected original error');
        } catch (caught, stack) {
          expect(caught, same(error));
          expect(stack.toString(), contains('ORIGINAL_STACK'));
        }
        expect(base.methodCalls, 2);
        expect((await diagnostics.query(RecordQuery())).records, hasLength(2));
        client.close();
        await diagnostics.dispose();
      },
    );
  }

  test(
    'read and readBytes preserve custom overrides without fabricated metadata',
    () async {
      final diagnostics = CodeKitDiagnostics();
      final base = MethodClient();
      final client = base.withDiagnostics(diagnostics);
      final url = Uri.https('example.test', '/read');
      final headers = {'x-test': 'value'};
      expect(await client.read(url, headers: headers), base.readResult);
      expect(base.calledMethod, 'READ');
      expect(base.receivedHeaders, same(headers));
      expect(await client.readBytes(url, headers: headers), same(base.bytes));
      expect(base.calledMethod, 'READ_BYTES');
      expect(base.receivedHeaders, same(headers));
      expect(base.sendCount, 0);
      final saved = (await diagnostics.query(RecordQuery())).records;
      expect(saved, hasLength(2));
      for (final record in saved) {
        final response = (record.payload as HttpPayload).response!;
        expect(response.statusCode, isNull);
        expect(response.headers, isNull);
      }
      expect(
        (saved.last.payload as HttpPayload).response!.body!.data,
        base.readResult,
      );
      expect(
        (saved.first.payload as HttpPayload).response!.body!.state,
        BodyCaptureState.unsupported,
      );
      final error = StateError('read error');
      base.error = error;
      await expectLater(client.read(url), throwsA(same(error)));
      await expectLater(client.readBytes(url), throwsA(same(error)));
      client.close();
      await diagnostics.dispose();
    },
  );

  test(
    'snapshot and capture setup failures never replace results or repeat calls',
    () async {
      for (final stage in ['eligibility', 'id', 'log', 'request', 'response']) {
        final diagnostics = SetupFailingDiagnostics(stage);
        final base = MethodClient();
        final client = base.withDiagnostics(diagnostics);
        final url = Uri.https('example.test', '/failure');
        if (stage == 'response') base.response = UnsnapshotableResponse();
        final body = stage == 'request' ? Object() : 'text';
        expect(await client.post(url, body: body), same(base.response));
        expect(base.receivedBody, same(body));
        expect(base.methodCalls, 1);
        final error = StateError('original error');
        base.error = error;
        await expectLater(client.post(url, body: body), throwsA(same(error)));
        expect(base.methodCalls, 2);
        expect(base.sendCount, 0);
        client.close();
        await diagnostics.dispose();
      }
    },
  );

  test(
    'buffered response joins Trace only when the inner method completes',
    () async {
      final diagnostics = CodeKitDiagnostics();
      diagnostics.startTrace();
      final base = MethodClient()..pending = Completer<http.Response>();
      final client = base.withDiagnostics(diagnostics);
      final future = client.get(Uri.https('example.test', '/wait'));
      expect(diagnostics.activeTraceRecordCount, 0);
      expect((await diagnostics.query(RecordQuery())).records, isEmpty);
      base.pending!.complete(base.response);
      expect(await future, same(base.response));
      expect(diagnostics.activeTraceRecordCount, 1);
      final session = await diagnostics.stopTrace();
      expect(session!.recordIds, hasLength(1));
      client.close();
      await diagnostics.dispose();
    },
  );

  test('same diagnostics in the wrapper chain does not add a layer', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = TrackingClient();
    final first = base.withDiagnostics(diagnostics);
    final second = first.withDiagnostics(diagnostics);
    final otherDiagnostics = CodeKitDiagnostics();
    final nested = first.withDiagnostics(otherDiagnostics);
    final nestedAgain = nested.withDiagnostics(diagnostics);

    expect(identical(first, second), isTrue);
    expect(identical(nested, nestedAgain), isTrue);
    expect(identical(nested, first), isFalse);

    nested.close();
    nested.close();
    expect(base.closeCount, 1);
    await diagnostics.dispose();
    await otherDiagnostics.dispose();
  });

  test(
    'response stream is lazy and forwards pause, resume and metadata',
    () async {
      final diagnostics = CodeKitDiagnostics();
      var listened = false;
      var paused = false;
      var resumed = false;
      final source = StreamController<List<int>>(
        onListen: () => listened = true,
        onPause: () => paused = true,
        onResume: () => resumed = true,
      );
      final client = StreamingClient(source.stream)
          .withDiagnostics(diagnostics);
      final response = await client.send(
        http.Request('GET', Uri.https('example.test', '/stream')),
      );
      expect(listened, isFalse);
      expect((await diagnostics.query(RecordQuery())).records, hasLength(1));
      expect(response.reasonPhrase, 'OK');
      expect(response.persistentConnection, isFalse);
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );
      final done = Completer<void>();
      final subscription = response.stream.listen(
        (_) {},
        onDone: done.complete,
      );
      expect(listened, isTrue);
      subscription.pause();
      expect(paused, isTrue);
      subscription.resume();
      expect(resumed, isTrue);
      source.add(utf8.encode('{"ok":true}'));
      await source.close();
      await done.future;
      final payload =
          (await diagnostics.query(RecordQuery())).records.single.payload
              as HttpPayload;
      expect(payload.response!.body!.state, BodyCaptureState.unsupported);
      client.close();
      await diagnostics.dispose();
    },
  );

  test('stream errors preserve identity and subsequent data, without partial capture', () async {
    final diagnostics = CodeKitDiagnostics();
    final error = StateError('synthetic stream failure');
    final source = StreamController<List<int>>();
    final client = StreamingClient(source.stream).withDiagnostics(diagnostics);
    final response = await client.send(
      http.Request('GET', Uri.https('example.test', '/error')),
    );
    final chunks = <List<int>>[];
    final errors = <Object>[];
    final done = Completer<void>();
    response.stream.listen(
      chunks.add,
      onError: (Object e) => errors.add(e),
      onDone: done.complete,
    );
    source.add([1]);
    source.addError(error);
    source.add([2]);
    await source.close();
    await done.future;
    expect(chunks, [
      [1],
      [2],
    ]);
    expect(errors.single, same(error));
    final payload =
        (await diagnostics.query(RecordQuery())).records.single.payload
            as HttpPayload;
    expect(payload.response!.body!.state, BodyCaptureState.unsupported);
    expect(payload.error, isNull);
    client.close();
    await diagnostics.dispose();
  });

  test(
    'cancel forwards upstream and records once without a partial body',
    () async {
      final diagnostics = CodeKitDiagnostics();
      var cancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final client = StreamingClient(source.stream)
          .withDiagnostics(diagnostics);
      final response = await client.send(
        http.Request('GET', Uri.https('example.test', '/cancel')),
      );
      final subscription = response.stream.listen((_) {});
      await subscription.cancel();
      expect(cancelled, isTrue);
      await source.close();
      final payload =
          (await diagnostics.query(RecordQuery())).records.single.payload
              as HttpPayload;
      expect(payload.response!.body!.state, BodyCaptureState.unsupported);
      client.close();
      await diagnostics.dispose();
    },
  );

  test(
    'response capture handles text, charset, malformed JSON, empty and binary',
    () async {
      for (final fixture in <(List<int>, String, BodyCaptureState, Object?)>[
        ([], 'application/json', BodyCaptureState.absent, null),
        (
          utf8.encode('<h1>503</h1>'),
          'text/html',
          BodyCaptureState.captured,
          '<h1>503</h1>',
        ),
        (
          utf8.encode('{broken'),
          'application/json',
          BodyCaptureState.captured,
          '{broken',
        ),
        (
          utf8.encode('{"ok":true}'),
          'application/problem+json',
          BodyCaptureState.captured,
          {'ok': true},
        ),
        ([255], 'application/json', BodyCaptureState.unsupported, null),
        (
          [1, 2, 3],
          'application/octet-stream',
          BodyCaptureState.unsupported,
          null,
        ),
        (
          [233],
          'text/plain; charset=iso-8859-1',
          BodyCaptureState.captured,
          'é',
        ),
        (
          List.filled(1024 * 1024, 65),
          'text/plain',
          BodyCaptureState.captured,
          'A' * (1024 * 1024),
        ),
        (
          List.filled(1024 * 1024 + 1, 65),
          'text/plain',
          BodyCaptureState.captured,
          'A' * (1024 * 1024 + 1),
        ),
      ]) {
        final diagnostics = CodeKitDiagnostics();
        final client = StreamingClient(
          Stream.value(fixture.$1),
          contentType: fixture.$2,
        ).withDiagnostics(diagnostics);
        final response = await client.get(Uri.https('example.test', '/body'));
        expect(response.bodyBytes, fixture.$1);
        final payload =
            (await diagnostics.query(RecordQuery())).records.single.payload
                as HttpPayload;
        expect(payload.response!.body!.state, fixture.$3);
        expect(payload.response!.body!.data, fixture.$4);
        client.close();
        await diagnostics.dispose();
      }
    },
  );

  test(
    'captured response JSON respects recording and export redaction',
    () async {
      final diagnostics = CodeKitDiagnostics(
        recordMode: RecordMode.redactBeforeRecording,
        redactionPolicy: RedactionPolicy(
          rules: [
            BodyFieldRedactionRule(['password']),
          ],
        ),
      );
      final client = StreamingClient(
        Stream.value(utf8.encode('{"password":"synthetic"}')),
      ).withDiagnostics(diagnostics);
      await client.get(Uri.https('example.test', '/body'));
      final record = (await diagnostics.query(RecordQuery())).records.single;
      final payload = record.payload as HttpPayload;
      expect(payload.response!.body!.data, {'password': '[REDACTED]'});
      final exported = await diagnostics.exportRecords([record.id]);
      expect(exported.text, isNot(contains('synthetic')));
      client.close();
      await diagnostics.dispose();
    },
  );

  test('close forwards once and closed wrapper rejects later sends', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = TrackingClient();
    final client = base.withDiagnostics(diagnostics);

    client.close();
    client.close();

    expect(base.closeCount, 1);
    await expectLater(
      client.get(Uri.parse('https://example.com')),
      throwsA(isA<StateError>()),
    );
    await diagnostics.dispose();
  });

  test('network errors are recorded and rethrown unchanged', () async {
    final diagnostics = CodeKitDiagnostics();
    final expected = http.ClientException(
      'network unavailable',
      Uri.parse('https://example.com/fail'),
    );
    final client = ThrowingClient(expected).withDiagnostics(diagnostics);

    await expectLater(
      client.get(Uri.parse('https://example.com/fail')),
      throwsA(same(expected)),
    );
    final records = (await diagnostics.query(RecordQuery())).records;
    expect(records, hasLength(1));
    final payload = records.single.payload as HttpPayload;
    expect(payload.error?.message, expected.toString());

    client.close();
    await diagnostics.dispose();
  });

  test(
    'recording failures do not change successful or failed requests',
    () async {
      final diagnostics = ThrowingDiagnostics();
      final base = TrackingClient();
      final client = base.withDiagnostics(diagnostics);

      final response = await client.get(Uri.parse('https://example.com'));

      expect(response.statusCode, 200);
      client.close();

      final originalError = http.ClientException(
        'original network failure',
        Uri.parse('https://example.com/fail'),
      );
      final failingClient = ThrowingClient(originalError)
          .withDiagnostics(diagnostics);
      await expectLater(
        failingClient.get(Uri.parse('https://example.com/fail')),
        throwsA(same(originalError)),
      );
      failingClient.close();
      await diagnostics.dispose();
    },
  );

  test('disposed diagnostics leaves injected client usable', () async {
    final diagnostics = CodeKitDiagnostics();
    final base = TrackingClient();
    final client = base.withDiagnostics(diagnostics);
    await diagnostics.dispose();

    final response = await client.get(Uri.parse('https://example.com'));

    expect(response.statusCode, 200);
    expect(base.closeCount, 0);
    client.close();
  });
}

class StreamingClient extends http.BaseClient {
  final Stream<List<int>> stream;
  final String contentType;
  final Uri? responseUrl;
  StreamingClient(
    this.stream, {
    this.contentType = 'application/json; charset=utf-8',
    this.responseUrl,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (responseUrl != null) {
      return ResponseWithUrl(stream, request, responseUrl!);
    }
    return http.StreamedResponse(
      stream,
      200,
      headers: {'content-type': contentType},
      request: request,
      reasonPhrase: 'OK',
      persistentConnection: false,
    );
  }
}

class MethodClient extends http.BaseClient {
  http.Response response = http.Response(
    '{}',
    200,
    headers: {'content-type': 'application/json'},
  );
  String readResult = 'read result';
  final bytes = Uint8List.fromList([1, 2]);
  String? calledMethod;
  Map<String, String>? receivedHeaders;
  Uri? receivedUrl;
  Object? receivedBody;
  Encoding? receivedEncoding;
  Object? error;
  Completer<http.Response>? pending;
  int methodCalls = 0;
  int sendCount = 0;
  int listenCount = 0;
  late final http.StreamedResponse streamed = http.StreamedResponse(
    Stream<List<int>>.multi((controller) {
      listenCount++;
      controller.add([1]);
      controller.close();
    }),
    200,
  );

  Future<T> _resolve<T>(T value) => error == null
      ? Future.value(value)
      : Future.error(error!, StackTrace.fromString('ORIGINAL_STACK'));

  Future<http.Response> _respond(
    String method,
    Uri url,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  ) {
    methodCalls++;
    calledMethod = method;
    receivedUrl = url;
    receivedHeaders = headers;
    receivedBody = body;
    receivedEncoding = encoding;
    return pending?.future ?? _resolve(response);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _respond('GET', url, headers, null, null);
  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      _respond('HEAD', url, headers, null, null);
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _respond('POST', url, headers, body, encoding);
  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _respond('PUT', url, headers, body, encoding);
  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _respond('PATCH', url, headers, body, encoding);
  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _respond('DELETE', url, headers, body, encoding);
  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    calledMethod = 'READ';
    receivedHeaders = headers;
    return _resolve(readResult);
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    calledMethod = 'READ_BYTES';
    receivedHeaders = headers;
    return _resolve(bytes);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCount++;
    return streamed;
  }
}

class UnsnapshotableResponse extends http.Response {
  UnsnapshotableResponse() : super('', 200);
  @override
  Uint8List get bodyBytes => throw StateError('response snapshot failed');
}

class SetupFailingDiagnostics extends CodeKitDiagnostics {
  SetupFailingDiagnostics(this.stage);
  final String stage;
  @override
  bool shouldCaptureHttp(Uri uri) => stage == 'eligibility'
      ? throw StateError('eligibility failed')
      : super.shouldCaptureHttp(uri);
  @override
  String createRecordId() =>
      stage == 'id' ? throw StateError('ID failed') : super.createRecordId();
  @override
  RecordReceipt log(DiagnosticInput input) =>
      stage == 'log' ? throw StateError('record failed') : super.log(input);
}

class ResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  ResponseWithUrl(Stream<List<int>> stream, http.BaseRequest request, this.url)
    : super(
        stream,
        200,
        request: request,
        contentLength: 2,
        isRedirect: true,
        headers: {'content-type': 'application/json'},
      );

  @override
  final Uri url;
}

class TrackingClient extends http.BaseClient {
  int closeCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode('ok')),
        200,
        request: request,
      );

  @override
  void close() => closeCount++;
}

class ThrowingClient extends http.BaseClient {
  final http.ClientException error;

  ThrowingClient(this.error);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(error);
}

class ThrowingDiagnostics extends CodeKitDiagnostics {
  @override
  RecordReceipt log(DiagnosticInput input) =>
      throw StateError('simulated diagnostic failure');
}
