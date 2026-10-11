---
title: CodeKit HTTP Client Adapters
status: draft
created: 2026-10-11
updated: 2026-10-11
---

# CodeKit HTTP Client Adapters

## Authority and scope

This document owns client capture integration, extension behavior and its remaining verification. [Architecture](system-architecture.md) owns package boundaries, [public API](public-api.md) owns the unified log entrypoint, and [lifecycle](diagnostic-data-lifecycle.md) owns completion, snapshot acceptance and storage.

Both `codekit_dio` and `codekit_http` are selected for implementation and independently installable. Neither depends on the umbrella. The umbrella's final dependency/re-export set is not selected yet. Capture of application requests is separate from network sinks sending diagnostics; webhook use of package:http does not itself instrument application HTTP requests.

## Dio

`codekit_dio` depends on codekit_core and Dio. It exposes `CodeKitDioInterceptor extends Interceptor` and a Dio extension `withDiagnostics()`. The extension mutates the existing Dio's interceptor list and returns the same Dio instance. Developer can still insert the public interceptor manually to control its position.

```dart
import 'package:dio/dio.dart';
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';

final diagnostics = CodeKitDiagnostics();
final dio = Dio().withDiagnostics(diagnostics);
await dio.get('https://example.com/users/42');
```

The extension checks existing CodeKitDioInterceptor instances using `identical(interceptor.diagnostics, diagnostics)`; a repeated call with the same diagnostics instance is a no-op. It also recognizes an interceptor added manually. Different diagnostics instances may attach separate interceptors; each must retain independent request tracking metadata so they cannot overwrite or remove another interceptor's capture.

```dart
extension DioDiagnosticsExtension on Dio {
  Dio withDiagnostics(CodeKitDiagnostics diagnostics) {
    final exists = interceptors
        .whereType<CodeKitDioInterceptor>()
        .any((i) => identical(i.diagnostics, diagnostics));
    if (!exists) {
      interceptors.add(CodeKitDioInterceptor(diagnostics: diagnostics));
    }
    return this;
  }
}
```

Each interceptor allocates the request/record ID before dispatch, records timing in private per-interceptor request metadata, and submits one completed HttpInput through diagnostics.log after response or error. Each retry attempt that re-enters the interceptor is recorded separately; redirects handled inside the Dio adapter remain part of one logical request. It does not inject an ID network header. Capture processing must not prevent Dio handler continuation or alter application results.

## package:http

`codekit_http` depends on codekit_core and package:http. It exposes `CodeKitHttpClient extends http.BaseClient` and `http.Client.withDiagnostics()`. BaseClient convenience methods route through send(); overriding every verb is unnecessary. The extension returns a wrapper, not the same client, and the consumer must use that returned value.

```dart
import 'package:http/http.dart' as http;
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';

final diagnostics = CodeKitDiagnostics();
final client = http.Client().withDiagnostics(diagnostics);
await client.get(Uri.parse('https://example.com/users/42'));
```

The wrapper's `send()` tracks a logical request, delegates to inner `send()`, and submits normalized input. Calls directly through the inner client or top-level `http` functions bypass the wrapper. Retry visibility follows wrapper order: a wrapper around `RetryClient` records its final result, while a `RetryClient` around the CodeKit wrapper can submit each attempt through it. Redirects handled inside the underlying client are not exposed as separate attempts.

Request bodies already available for safe snapshotting may be captured. Multipart capture uses available fields/media metadata without reading file bytes. Streamed request bodies are not read ahead. At the approved response-headers boundary, response bodies are unsupported, including get()/post() calls that are subsequently buffered by BaseClient: the wrapper does not see that later buffering. It returns the original response stream and does not consume it to improve diagnostics.

Capture exclusions apply before diagnostic processing. Cancellation/network failures retain the application error and produce a completed diagnostic error snapshot where possible. Snapshot models contain no live client types.

The app chooses when to close the returned wrapper. `CodeKitHttpClient.close()` closes the wrapper and forwards close to its inner client exactly once; callers should use and close the returned wrapper instead of continuing to use the original client reference. Wrapping the same diagnostics instance again anywhere in a wrapper chain returns the current wrapper; a distinct diagnostics instance creates another layer. Closing diagnostics does not close a developer's HTTP client.

## Dio implementation and verification

The `codekit_dio` member implements the extension, public interceptor, detached snapshot conversion, multipart file metadata capture, and integration tests against a loopback HTTP server. Verified behaviors include deduplication, manual attachment detection, response/error capture, redirect handling, retry attempts, cancellation, global URI exclusion, disposed diagnostics, and independent metadata for multiple diagnostics instances. The interceptor captures only data already available at its boundary; byte arrays and streamed response bodies are unsupported.

## HTTP implementation and verification

The `codekit_http` member implements `http.Client.withDiagnostics()` and `CodeKitHttpClient extends http.BaseClient`. It records at the `send()` boundary, captures available text/JSON request bodies and multipart fields/file metadata without reading file streams, and returns the original `StreamedResponse` without consuming its body. Multipart `Content-Type` is recorded as `multipart/form-data`; the boundary added later by `package:http` finalization is not captured. Response records complete at the headers boundary, so response body capture remains unsupported for convenience methods too.

Tests use the actual `http` package and a loopback server. They verify convenience-method routing, request snapshotting, multipart metadata, stream preservation, URI exclusion, cancellation/error propagation, wrapper close forwarding, repeated wrapping and continued HTTP operation after `diagnostics.dispose()`. They do not claim remote-network or webhook integration coverage. Webhook request exclusion from this pipeline remains to be verified with the webhook transport implementation.
