import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late CodeKitDiagnostics diagnostics;
  late http.Client client;
  late Completer<void> waitStarted;
  late Completer<void> finishWait;

  setUp(() async {
    waitStarted = Completer<void>();
    finishWait = Completer<void>();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      String? body;
      if (request.uri.path == '/wait') {
        if (!waitStarted.isCompleted) waitStarted.complete();
        await finishWait.future;
      } else if (request.uri.path == '/echo') {
        body = await utf8.decoder.bind(request).join();
      } else {
        await request.drain<void>();
      }
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = request.uri.queryParameters['status'] == '503'
              ? 503
              : 200
          ..write(
            jsonEncode(
              request.uri.path == '/echo'
                  ? {
                      'method': request.method,
                      'query': request.uri.queryParameters,
                      'header': request.headers.value('x-test'),
                      'body': body,
                    }
                  : {'ok': true, 'path': request.uri.path},
            ),
          )
          ..close();
      } catch (_) {
        // The cancellation integration case closes the client request first.
      }
    });
    diagnostics = CodeKitDiagnostics();
    client = http.Client().withDiagnostics(diagnostics);
  });

  tearDown(() async {
    if (!finishWait.isCompleted) finishWait.complete();
    client.close();
    await diagnostics.dispose();
    await server.close(force: true);
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<List<DiagnosticRecord>> records() async =>
      (await diagnostics.query(RecordQuery())).records;

  for (final method in ['HEAD', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    test(
      '$method preserves real HTTP parameters and captures one complete response',
      () async {
        final requestUri = uri('/echo')
            .replace(queryParameters: {'select': 'title,price', 'limit': '10'});
        final headers = {'content-type': 'application/json', 'x-test': 'value'};
        const body = '{"title":"điện thoại"}';
        final response = await switch (method) {
          'HEAD' => client.head(requestUri, headers: headers),
          'GET' => client.get(requestUri, headers: headers),
          'POST' => client.post(requestUri, headers: headers, body: body),
          'PUT' => client.put(requestUri, headers: headers, body: body),
          'PATCH' => client.patch(requestUri, headers: headers, body: body),
          _ => client.delete(requestUri, headers: headers, body: body),
        };
        expect(response.statusCode, 200);
        final payload = (await records()).single.payload as HttpPayload;
        expect(payload.method, method);
        expect(payload.uri, requestUri);
        if (method == 'HEAD') {
          expect(response.bodyBytes, isEmpty);
          expect(payload.response!.body!.state, BodyCaptureState.absent);
        } else {
          final decoded = jsonDecode(response.body) as Map;
          expect(decoded['method'], method);
          expect(decoded['query'], requestUri.queryParameters);
          expect(decoded['header'], 'value');
          expect(decoded['body'], method == 'GET' ? '' : body);
          expect(payload.response!.body!.data, decoded);
        }
      },
    );
  }

  test('HTTP 503 body is captured while read preserves its original failure behavior', () async {
    final requestUri = uri('/echo').replace(queryParameters: {'status': '503'});
    final response = await client.get(requestUri);
    expect(response.statusCode, 503);
    final saved = (await records()).single.payload as HttpPayload;
    expect(saved.response!.body!.data, jsonDecode(response.body));
    await expectLater(
      client.read(requestUri),
      throwsA(isA<http.ClientException>()),
    );
    final read = (await records()).first.payload as HttpPayload;
    expect(read.error!.type, 'ClientException');
    expect(read.response, isNull);
  });

  test('convenience methods capture the completed inner response', () async {
    final response = await client.get(uri('/get'));

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(response.body), {'ok': true, 'path': '/get'});
    final saved = await records();
    expect(saved, hasLength(1));
    final payload = saved.single.payload as HttpPayload;
    expect(payload.method, 'GET');
    expect(payload.uri.path, '/get');
    expect(payload.response?.statusCode, HttpStatus.ok);
    expect(payload.response?.body?.data, {'ok': true, 'path': '/get'});
  });

  test('captures an available JSON request body without changing it', () async {
    final response = await client.post(
      uri('/json'),
      headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
      body: jsonEncode({
        'user': {'id': 42},
      }),
    );

    expect(response.statusCode, HttpStatus.ok);
    final saved = await records();
    expect(saved, hasLength(1));
    final payload = saved.single.payload as HttpPayload;
    expect(payload.requestBody?.data, {
      'user': {'id': 42},
    });
    expect(payload.response?.body?.data, {'ok': true, 'path': '/json'});
  });

  test(
    'captures multipart fields and file metadata without reading bytes',
    () async {
      final request = http.MultipartRequest('POST', uri('/multipart'))
        ..fields['description'] = 'profile photo'
        ..files.add(
          http.MultipartFile.fromBytes('upload', [
            1,
            2,
            3,
          ], filename: 'photo.png'),
        );

      final response = await client.send(request);
      await response.stream.drain<void>();

      final saved = await records();
      expect(saved, hasLength(1));
      final body =
          (saved.single.payload as HttpPayload).requestBody!.data
              as Map<String, Object?>;
      final payload = saved.single.payload as HttpPayload;
      expect(payload.requestHeaders?['content-type'], ['multipart/form-data']);
      expect(body['fields'], {'description': 'profile photo'});
      expect(body['files'], [
        {
          'fieldName': 'upload',
          'fileName': 'photo.png',
          'contentType': 'application/octet-stream',
          'sizeBytes': 3,
        },
      ]);
    },
  );

  test('send records at headers and leaves both streams untouched', () async {
    final request = http.StreamedRequest('POST', uri('/stream'))
      ..contentLength = 3;
    request.sink.add([1, 2, 3]);
    unawaited(request.sink.close());

    final response = await client.send(request);
    final saved = await records();

    expect(saved, hasLength(1));
    expect(await response.stream.bytesToString(), contains('/stream'));
    final payload = (await records()).single.payload as HttpPayload;
    expect(payload.requestBody?.state, BodyCaptureState.unsupported);
    expect(payload.response?.body?.state, BodyCaptureState.unsupported);
  });

  test(
    'send joins Trace at headers even if its body has not been consumed',
    () async {
      diagnostics.startTrace();
      final requestUri = uri('/products').replace(
        queryParameters: {'limit': '10', 'skip': '0', 'select': 'title,price'},
      );
      final response = await client.send(http.Request('GET', requestUri));
      expect(diagnostics.activeTraceRecordCount, 1);
      final saved = (await records()).single;
      expect((saved.payload as HttpPayload).uri, requestUri);
      final session = await diagnostics.stopTrace();
      expect(session!.recordIds, [saved.id]);
      await response.stream.drain<void>();
      expect(await records(), hasLength(1));
    },
  );

  test(
    'URI exclusion bypasses capture but leaves the request operational',
    () async {
      diagnostics.captureExcludeUriPatterns = [RegExp(r'/excluded$')];

      final response = await client.get(uri('/excluded'));

      expect(response.statusCode, HttpStatus.ok);
      expect(await records(), isEmpty);
    },
  );

  test(
    'aborted request is recorded and its original error is rethrown',
    () async {
      final abort = Completer<void>();
      final request = http.AbortableRequest(
        'GET',
        uri('/wait'),
        abortTrigger: abort.future,
      );
      final pending = client.send(request);
      await waitStarted.future.timeout(const Duration(seconds: 5));
      abort.complete();

      await expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
      final saved = await records();
      expect(saved, hasLength(1));
      expect((saved.single.payload as HttpPayload).error, isNotNull);
    },
  );
}
