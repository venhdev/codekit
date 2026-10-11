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

Each interceptor allocates the request/record ID before dispatch, records timing in private request metadata, and submits one completed HttpInput through diagnostics.log after response or error. It does not inject an ID network header. Capture processing must not prevent Dio handler continuation or alter application results. Retry/redirect and metadata ownership require the spike below before implementation is finalized.

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

The wrapper's send() tracks a logical request, delegates to inner.send(), and submits normalized input. Calls directly through the inner client or top-level http functions bypass the wrapper. Client-internal retries/redirects are not promised as separately captured attempts.

Request bodies already available for safe snapshotting may be captured. Multipart capture uses available fields/media metadata without reading file bytes. Streamed request bodies are not read ahead. At the approved response-headers boundary, response bodies are unsupported, including get()/post() calls that are subsequently buffered by BaseClient: the wrapper does not see that later buffering. It returns the original response stream and does not consume it to improve diagnostics.

Capture exclusions apply before diagnostic processing. Cancellation/network failures retain the application error and produce a completed diagnostic error snapshot where possible. Snapshot models contain no live client types.

The wrapper close()/inner-client ownership rule and repeated wrapping behavior still require clarification; do not silently borrow a sink transport ownership rule for application clients. Closing diagnostics does not itself imply closing a developer's Dio/client instance.

## Required scratch verification

- Dio: extension idempotence, manual attachment detection, multiple diagnostics metadata isolation, response/error single submission, retries and handler continuation on capture failure.
- HTTP: convenience-method routing through send(), body-safe Request/MultipartRequest capture, untouched request/response streams, cancellation/error propagation and wrapper resource ownership after that rule is selected.
- Both: detached nested snapshots, internal ID correlation, no network header injection, exclusion and non-recursive webhook delivery.

These are planned proofs, not claims of completed verification. No production adapter package has been created by this documentation update.
