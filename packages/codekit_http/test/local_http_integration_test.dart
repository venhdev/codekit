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
      if (request.uri.path == '/wait') {
        if (!waitStarted.isCompleted) waitStarted.complete();
        await finishWait.future;
      } else {
        await request.drain<void>();
      }
      try {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true, 'path': request.uri.path}))
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

  test(
    'convenience methods pass through send and preserve the response',
    () async {
      final response = await client.get(uri('/get'));

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {'ok': true, 'path': '/get'});
      final saved = await records();
      expect(saved, hasLength(1));
      final payload = saved.single.payload as HttpPayload;
      expect(payload.method, 'GET');
      expect(payload.uri.path, '/get');
      expect(payload.response?.statusCode, HttpStatus.ok);
      expect(payload.response?.body?.state, BodyCaptureState.unsupported);
    },
  );

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
    expect(payload.response?.body?.state, BodyCaptureState.unsupported);
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

  test('does not consume streamed request or response bodies', () async {
    final request = http.StreamedRequest('POST', uri('/stream'))
      ..contentLength = 3;
    request.sink.add([1, 2, 3]);
    unawaited(request.sink.close());

    final response = await client.send(request);
    final saved = await records();

    expect(saved, hasLength(1));
    final payload = saved.single.payload as HttpPayload;
    expect(payload.requestBody?.state, BodyCaptureState.unsupported);
    expect(payload.response?.body?.state, BodyCaptureState.unsupported);
    expect(await response.stream.bytesToString(), contains('/stream'));
  });

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
