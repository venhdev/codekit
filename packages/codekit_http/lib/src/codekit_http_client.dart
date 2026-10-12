import 'dart:convert';
import 'dart:typed_data';

import 'package:codekit_core/codekit_core.dart';
import 'package:http/http.dart' as http;

import 'http_snapshot.dart';

/// Records available HTTP snapshots while the inner client owns networking.
/// Buffered methods preserve the original Response; send preserves its stream.
class CodeKitHttpClient extends http.BaseClient {
  CodeKitHttpClient(this._inner, {required this.diagnostics});

  final http.Client _inner;
  final CodeKitDiagnostics diagnostics;
  bool _closed = false;

  bool _containsDiagnostics(CodeKitDiagnostics value) =>
      identical(diagnostics, value) ||
      (_inner is CodeKitHttpClient && _inner._containsDiagnostics(value));

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      _observe(
        'HEAD',
        url,
        headers,
        null,
        null,
        () => _inner.head(url, headers: headers),
      );
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _observe(
        'GET',
        url,
        headers,
        null,
        null,
        () => _inner.get(url, headers: headers),
      );
  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _observe(
    'POST',
    url,
    headers,
    body,
    encoding,
    () => _inner.post(url, headers: headers, body: body, encoding: encoding),
  );
  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _observe(
    'PUT',
    url,
    headers,
    body,
    encoding,
    () => _inner.put(url, headers: headers, body: body, encoding: encoding),
  );
  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _observe(
    'PATCH',
    url,
    headers,
    body,
    encoding,
    () => _inner.patch(url, headers: headers, body: body, encoding: encoding),
  );
  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _observe(
    'DELETE',
    url,
    headers,
    body,
    encoding,
    () => _inner.delete(url, headers: headers, body: body, encoding: encoding),
  );
  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) => _observe(
    'GET',
    url,
    headers,
    null,
    null,
    () => _inner.read(url, headers: headers),
  );
  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) =>
      _observe(
        'GET',
        url,
        headers,
        null,
        null,
        () => _inner.readBytes(url, headers: headers),
      );
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _observe(
    request.method,
    request.url,
    request.headers,
    null,
    null,
    () => _inner.send(request),
    request: request,
  );

  Future<T> _observe<T>(
    String method,
    Uri url,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Future<T> Function() invoke, {
    http.BaseRequest? request,
  }) async {
    if (_closed) throw StateError('Client is closed');
    String? id;
    Map<String, List<String>>? capturedHeaders;
    BodySnapshot? capturedRequest;
    final started = DateTime.now();
    final stopwatch = Stopwatch()..start();
    try {
      if (diagnostics.shouldCaptureHttp(url)) {
        id = diagnostics.createRecordId();
        final preview =
            request ?? _preview(method, url, headers, body, encoding);
        capturedHeaders = snapshotRequestHeaders(preview);
        capturedRequest = snapshotRequestBody(preview).detached();
      }
    } catch (_) {
      // A custom inner client may accept inputs standard http.Request rejects.
      // Snapshot failures discard the preview, never change the invocation.
      capturedRequest = const BodySnapshot.unsupported();
    }

    void record({T? result, Object? error, StackTrace? stack}) {
      if (id == null) return;
      try {
        HttpResponseSnapshot? response;
        if (result is http.Response) {
          response = HttpResponseSnapshot(
            statusCode: result.statusCode,
            headers: result.headersSplitValues,
            body: snapshotResponseBody(result),
          );
        } else if (result is http.StreamedResponse) {
          response = HttpResponseSnapshot(
            statusCode: result.statusCode,
            headers: result.headersSplitValues,
            body: const BodySnapshot.unsupported(),
          );
        } else if (result is String) {
          // read() hides status/headers; don't fabricate either field.
          response = HttpResponseSnapshot(body: BodySnapshot.text(result));
        } else if (result is Uint8List) {
          // readBytes() provides no media type; bytes remain unsupported.
          response = const HttpResponseSnapshot(
            body: BodySnapshot.unsupported(),
          );
        }
        diagnostics.log(
          HttpInput(
            recordId: id,
            requestStartedAt: started,
            duration: stopwatch.elapsed,
            method: method,
            uri: url,
            requestHeaders: capturedHeaders,
            requestBody: capturedRequest,
            response: response,
            error: error == null
                ? null
                : DiagnosticError(
                    type: error.runtimeType.toString(),
                    message: error.toString(),
                    stackTrace: stack?.toString(),
                  ),
          ),
        );
      } catch (_) {
        // Snapshot and recorder failures never escape to the caller.
      }
    }

    final T result;
    try {
      result = await invoke();
    } catch (error, stack) {
      stopwatch.stop();
      record(error: error, stack: stack);
      rethrow;
    }
    stopwatch.stop();
    record(result: result);
    return result;
  }

  http.Request _preview(
    String method,
    Uri url,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  ) {
    final request = http.Request(method, url);
    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body is String) {
      request.body = body;
    } else if (body is List) {
      request.bodyBytes = body.cast<int>();
    } else if (body is Map) {
      request.bodyFields = body.cast<String, String>();
    } else if (body != null) {
      throw ArgumentError('Unsupported preview');
    }
    return request;
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
