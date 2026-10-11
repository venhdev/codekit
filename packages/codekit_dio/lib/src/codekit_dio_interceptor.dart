import 'package:codekit_core/codekit_core.dart';
import 'package:dio/dio.dart';

import 'http_snapshot.dart';

/// Captures completed Dio requests without changing request or response flow.
class CodeKitDioInterceptor extends Interceptor {
  final CodeKitDiagnostics diagnostics;
  final Expando<_RequestCapture> _captures = Expando<_RequestCapture>();

  CodeKitDioInterceptor({required this.diagnostics});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      if (diagnostics.shouldCaptureHttp(options.uri)) {
        final capture = _RequestCapture(
          recordId: diagnostics.createRecordId(),
          requestStartedAt: DateTime.now(),
          stopwatch: Stopwatch()..start(),
          method: options.method,
          uri: options.uri,
          requestHeaders: snapshotHeaders(options.headers),
          requestBody: snapshotBody(options.data),
        );
        _captures[options] = capture;
      }
    } catch (_) {
      // Diagnostics capture must not interfere with the application request.
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    try {
      final capture = _captures[response.requestOptions];
      if (capture != null) {
        capture.stopwatch.stop();
        diagnostics.log(
          HttpInput(
            recordId: capture.recordId,
            requestStartedAt: capture.requestStartedAt,
            duration: capture.stopwatch.elapsed,
            method: capture.method,
            uri: capture.uri,
            requestHeaders: capture.requestHeaders,
            requestBody: capture.requestBody,
            response: HttpResponseSnapshot(
              statusCode: response.statusCode,
              headers: snapshotHeaders(response.headers.map),
              body: snapshotResponseBody(response),
            ),
          ),
        );
        _captures[response.requestOptions] = null;
      }
    } catch (_) {
      // A diagnostics failure must not change the successful response.
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      final options = err.requestOptions;
      final capture = _captures[options];
      if (capture != null) {
        capture.stopwatch.stop();
        final response = err.response;
        diagnostics.log(
          HttpInput(
            recordId: capture.recordId,
            requestStartedAt: capture.requestStartedAt,
            duration: capture.stopwatch.elapsed,
            method: capture.method,
            uri: capture.uri,
            requestHeaders: capture.requestHeaders,
            requestBody: capture.requestBody,
            response: response == null
                ? null
                : HttpResponseSnapshot(
                    statusCode: response.statusCode,
                    headers: snapshotHeaders(response.headers.map),
                    body: snapshotResponseBody(response),
                  ),
            error: DiagnosticError(
              type: err.type.name,
              message: err.message ?? err.type.name,
              stackTrace: err.stackTrace.toString(),
            ),
          ),
        );
        _captures[options] = null;
      }
    } catch (_) {
      // A diagnostics failure must not replace the original Dio exception.
    }
    handler.next(err);
  }
}

final class _RequestCapture {
  final String recordId;
  final DateTime requestStartedAt;
  final Stopwatch stopwatch;
  final String method;
  final Uri uri;
  final Map<String, List<String>> requestHeaders;
  final BodySnapshot requestBody;

  const _RequestCapture({
    required this.recordId,
    required this.requestStartedAt,
    required this.stopwatch,
    required this.method,
    required this.uri,
    required this.requestHeaders,
    required this.requestBody,
  });
}
