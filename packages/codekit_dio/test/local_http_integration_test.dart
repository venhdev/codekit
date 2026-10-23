import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late CodeKitDiagnostics diagnostics;
  final waitStarted = Completer<void>();
  final finishWait = Completer<void>();
  var retryAttempts = 0;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/retry') {
        retryAttempts++;
        request.response
          ..statusCode = retryAttempts == 1
              ? HttpStatus.serviceUnavailable
              : HttpStatus.ok
          ..write('{}')
          ..close();
        return;
      }
      if (request.uri.path == '/redirect') {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/ok')
          ..close();
        return;
      }
      if (request.uri.path == '/wait') {
        if (!waitStarted.isCompleted) waitStarted.complete();
        await finishWait.future;
      }
      if (request.uri.path == '/error') {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'unavailable'}))
          ..close();
        return;
      }
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': true, 'path': request.uri.path}))
        ..close();
    });
    diagnostics = CodeKitDiagnostics();
    retryAttempts = 0;
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'))
      ..withDiagnostics(diagnostics);
  });

  tearDown(() async {
    if (!finishWait.isCompleted) finishWait.complete();
    dio.close(force: true);
    await diagnostics.dispose();
    await server.close(force: true);
  });

  Future<List<DiagnosticRecord>> recordsFor(CodeKitDiagnostics target) async {
    return (await target.query(RecordQuery())).records;
  }

  test(
    'captures a completed request and detaches request/response data',
    () async {
      final requestBody = <String, Object?>{
        'user': <String, Object?>{'id': 42},
      };
      await dio.post('/ok', data: requestBody);
      requestBody['later'] = true;

      final records = await recordsFor(diagnostics);
      expect(records, hasLength(1));
      final payload = records.single.payload as HttpPayload;
      expect(payload.method, 'POST');
      expect(payload.uri.path, '/ok');
      expect(payload.duration, isNotNull);
      expect(payload.requestBody?.data, {
        'user': {'id': 42},
      });
      expect(payload.response?.statusCode, HttpStatus.ok);
      expect(payload.response?.body?.data, {'ok': true, 'path': '/ok'});
      expect(payload.requestHeaders, contains('content-type'));
    },
  );

  test('captures HTTP error response and preserves Dio exception', () async {
    await expectLater(dio.get('/error'), throwsA(isA<DioException>()));

    final records = await recordsFor(diagnostics);
    expect(records, hasLength(1));
    final payload = records.single.payload as HttpPayload;
    expect(payload.error?.type, DioExceptionType.badResponse.name);
    expect(payload.response?.statusCode, HttpStatus.internalServerError);
    expect(payload.response?.body?.data, {'error': 'unavailable'});
  });

  test('redirect is captured as one logical Dio request', () async {
    final response = await dio.get('/redirect');

    expect(response.statusCode, HttpStatus.ok);
    final records = await recordsFor(diagnostics);
    expect(records, hasLength(1));
    final payload = records.single.payload as HttpPayload;
    expect(payload.uri.path, '/redirect');
    expect(payload.response?.statusCode, HttpStatus.ok);
  });

  test('each retry attempt receives its own completed record', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.requestOptions.uri.path == '/retry' &&
              error.requestOptions.extra['testRetry'] != true) {
            error.requestOptions.extra['testRetry'] = true;
            try {
              handler.resolve(await dio.fetch(error.requestOptions));
            } catch (_) {
              handler.next(error);
            }
          } else {
            handler.next(error);
          }
        },
      ),
    );

    final response = await dio.get('/retry');

    expect(response.statusCode, HttpStatus.ok);
    final records = await recordsFor(diagnostics);
    expect(records, hasLength(2));
    final payloads = records.map((r) => r.payload as HttpPayload).toList();
    expect(payloads.map((p) => p.response?.statusCode).toSet(), {
      HttpStatus.serviceUnavailable,
      HttpStatus.ok,
    });
    expect(
      payloads
          .where((p) => p.response?.statusCode == HttpStatus.serviceUnavailable)
          .single
          .error,
      isNotNull,
    );
    expect(
      payloads
          .where((p) => p.response?.statusCode == HttpStatus.ok)
          .single
          .error,
      isNull,
    );
    expect(records[0].id, isNot(records[1].id));
  });

  test('capture exclusion does not block the application request', () async {
    diagnostics.captureExcludeUriPatterns = [RegExp(r'/ok$')];

    final response = await dio.get('/ok');

    expect(response.statusCode, HttpStatus.ok);
    expect(await recordsFor(diagnostics), isEmpty);
  });

  test(
    'disposed diagnostics does not prevent the application request',
    () async {
      await diagnostics.dispose();

      final response = await dio.get('/ok');

      expect(response.statusCode, HttpStatus.ok);
    },
  );

  test(
    'multiple diagnostics instances keep independent request metadata',
    () async {
      final other = CodeKitDiagnostics();
      dio.withDiagnostics(other);
      await dio.get('/ok');

      final firstRecords = await recordsFor(diagnostics);
      final secondRecords = await recordsFor(other);
      expect(firstRecords, hasLength(1));
      expect(secondRecords, hasLength(1));
      expect(firstRecords.single.id, isNot(secondRecords.single.id));
      expect((firstRecords.single.payload as HttpPayload).uri.path, '/ok');
      expect((secondRecords.single.payload as HttpPayload).uri.path, '/ok');
      await other.dispose();
    },
  );

  test('cancellation remains a Dio error and is captured once', () async {
    final token = CancelToken();
    final request = dio.get('/wait', cancelToken: token);
    await waitStarted.future.timeout(const Duration(seconds: 5));
    token.cancel('test cancellation');

    await expectLater(request, throwsA(isA<DioException>()));
    final records = await recordsFor(diagnostics);
    expect(records, hasLength(1));
    expect((records.single.payload as HttpPayload).error, isNotNull);
  });

  test(
    'maxBodyCaptureBytes caps oversized request and response bodies in Dio',
    () async {
      final cappedDio = Dio(
        BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'),
      )..withDiagnostics(diagnostics, maxBodyCaptureBytes: 100);

      final largeData = {'items': List.filled(50, 'long-element-text-sample')};
      await cappedDio.post('/upload', data: largeData);

      final records = await recordsFor(diagnostics);
      expect(records, hasLength(1));
      final payload = records.single.payload as HttpPayload;
      expect(payload.requestBody!.state, BodyCaptureState.overflow);
      expect((payload.requestBody!.data as Map)['sizeBytes'], greaterThan(100));
      cappedDio.close(force: true);
    },
  );
}
