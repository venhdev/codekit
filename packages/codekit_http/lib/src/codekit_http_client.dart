import 'package:codekit_core/codekit_core.dart';
import 'package:http/http.dart' as http;

import 'http_snapshot.dart';

/// A package:http wrapper that records completed request metadata.
class CodeKitHttpClient extends http.BaseClient {
  final http.Client _inner;
  final CodeKitDiagnostics diagnostics;
  bool _closed = false;

  CodeKitHttpClient(this._inner, {required this.diagnostics});

  bool _containsDiagnostics(CodeKitDiagnostics value) =>
      identical(diagnostics, value) ||
      (_inner is CodeKitHttpClient && _inner._containsDiagnostics(value));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw StateError('Client is closed');
    if (!diagnostics.shouldCaptureHttp(request.url)) {
      return _inner.send(request);
    }

    final String recordId;
    final DateTime requestStartedAt;
    final Stopwatch stopwatch;
    final Map<String, List<String>> requestHeaders;
    final BodySnapshot requestBody;
    try {
      recordId = diagnostics.createRecordId();
      requestStartedAt = DateTime.now();
      stopwatch = Stopwatch()..start();
      requestHeaders = snapshotRequestHeaders(request);
      requestBody = snapshotRequestBody(request);
    } catch (_) {
      // Capture setup must not prevent the original request from being sent.
      return _inner.send(request);
    }

    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (error, stackTrace) {
      stopwatch.stop();
      try {
        _record(
          HttpInput(
            recordId: recordId,
            requestStartedAt: requestStartedAt,
            duration: stopwatch.elapsed,
            method: request.method,
            uri: request.url,
            requestHeaders: requestHeaders,
            requestBody: requestBody,
            error: DiagnosticError(
              type: error.runtimeType.toString(),
              message: error.toString(),
              stackTrace: stackTrace.toString(),
            ),
          ),
        );
      } catch (_) {
        // Building the diagnostic input must not replace the HTTP error.
      }
      rethrow;
    }

    stopwatch.stop();
    try {
      _record(
        HttpInput(
          recordId: recordId,
          requestStartedAt: requestStartedAt,
          duration: stopwatch.elapsed,
          method: request.method,
          uri: request.url,
          requestHeaders: requestHeaders,
          requestBody: requestBody,
          response: HttpResponseSnapshot(
            statusCode: response.statusCode,
            headers: response.headersSplitValues,
            body: const BodySnapshot.unsupported(),
          ),
        ),
      );
    } catch (_) {
      // Building the diagnostic input must not replace the HTTP response.
    }
    return response;
  }

  void _record(HttpInput input) {
    try {
      diagnostics.log(input);
    } catch (_) {
      // Recording must not replace a response or the original HTTP error.
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inner.close();
  }
}

extension HttpClientDiagnosticsExtension on http.Client {
  /// Wraps this client with diagnostics and returns the client to use.
  CodeKitHttpClient withDiagnostics(CodeKitDiagnostics diagnostics) {
    if (this is CodeKitHttpClient) {
      final current = this as CodeKitHttpClient;
      if (current._containsDiagnostics(diagnostics)) return current;
    }
    return CodeKitHttpClient(this, diagnostics: diagnostics);
  }
}
