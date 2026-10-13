---
title: CodeKit HTTP Client Adapters
status: active
created: 2026-10-11
updated: 2026-10-13
---

# CodeKit HTTP Client Adapters

## Authority and scope

This document owns client capture integration and extension behavior. [Architecture](system-architecture.md) owns package boundaries, [public API](public-api.md) owns the unified log entrypoint, and [lifecycle](diagnostic-data-lifecycle.md) owns completion, snapshot acceptance and storage.

Both `codekit_dio` and `codekit_http` are independently installable and do not depend on the umbrella. Capture of application requests is separate from network sinks sending diagnostics; webhook use of package:http does not itself instrument application HTTP requests.

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

Each interceptor allocates the request/record ID before dispatch, records timing in private per-interceptor request metadata, and submits one completed HttpInput through diagnostics.log after response or error. Each retry attempt that re-enters the interceptor is recorded separately; redirects handled inside the Dio adapter remain part of one logical request. It does not inject an ID network header. Capture processing must not prevent Dio handler continuation or alter application results. Snapshot only supported request data and multipart file metadata; byte arrays and streamed response bodies are unsupported.

## package:http

`codekit_http` depends on codekit_core and package:http. It exposes `CodeKitHttpClient extends http.BaseClient` and `http.Client.withDiagnostics()`. The extension returns a wrapper, not the same client, and the consumer must use that returned value. Each public request method forwards to the corresponding inner-client method; convenience methods do not route through the wrapper's send().

```dart
import 'package:http/http.dart' as http;
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';

final diagnostics = CodeKitDiagnostics();
final client = http.Client().withDiagnostics(diagnostics);
await client.get(Uri.parse('https://example.com/users/42'));
```

The wrapper tracks one logical request per invoked method, delegates that method exactly once, and submits normalized input. It forwards the original URI, headers, body and encoding without replacing or mutating them. Calls directly through the inner client or top-level `http` functions bypass the wrapper. Retry visibility follows wrapper order: a wrapper around `RetryClient` records its final result, while a `RetryClient` around the CodeKit wrapper can submit each attempt through send(). Redirects handled inside the underlying client are not exposed as separate attempts.

Request bodies already available for safe snapshotting may be captured. Multipart capture uses available fields/media metadata without reading file bytes. Streamed request bodies are not read ahead. Multipart `Content-Type` is recorded as `multipart/form-data`; the boundary added later by `package:http` finalization is not captured.

For head/get/post/put/patch/delete, the inner client owns networking and buffering. The wrapper receives an already-completed Response, snapshots its available data, and returns that same instance, including any custom subclass and final-URL interface. It does not rebuild the response or change the inner method's status/error behavior. Request metadata is a best-effort preview of the caller's arguments, not a claim to observe additional transport headers or custom-client transformations. An unsupported preview must not reject input accepted by the inner client.

Buffered body capture has no size limit and never truncates data. JSON (`application/json` or `application/*+json`) uses strict UTF-8 and is stored as structured JSON; malformed JSON with valid UTF-8 falls back to text. Text (`text/*`, `application/xml` or `*+xml`) uses the response's charset behavior. Empty buffered bodies are absent; binary/unknown content types or decode failures are unsupported. Large bodies incur proportional snapshot, redaction and storage costs; diagnostics cannot promise zero CPU/memory overhead.

send() returns the original StreamedResponse and stream without creating a subscription, wrapping, draining or rebuilding them. It records status/headers at response headers, with body unsupported, even if the application never consumes the stream. Subsequent body errors, pause/resume and cancellation belong entirely to the original application stream; they do not update the completed record.

read()/readBytes() forward to the exact inner methods, preserving custom overrides and original error behavior. read() captures the returned text without a size limit; readBytes() returns the original bytes but records body unsupported because no media type is exposed. These APIs expose no response status/headers; diagnostics must leave those fields unknown rather than fabricate them or issue another request.

One completed record is submitted per method invocation when its inner Future completes or throws. For buffered methods this includes the inner client's body buffering; for send() it ends at headers. Duration stops before response snapshot processing. Record/Trace acceptance follows completion and snapshot preparation, not later application consumption. Snapshot/setup/recorder failures must not replace results or original errors, nor cause a second client invocation. Persistence and sink delivery are not awaited on the client path. Redaction applies to the snapshot through the core recorder/export pipeline.

Capture exclusions apply before diagnostic processing. Cancellation/network failures retain the application error and produce a completed diagnostic error snapshot where possible. Snapshot models contain no live client types.

The app chooses when to close the returned wrapper. `CodeKitHttpClient.close()` closes the wrapper and forwards close to its inner client exactly once; callers should use and close the returned wrapper instead of continuing to use the original client reference. Wrapping the same diagnostics instance again anywhere in a wrapper chain returns the current wrapper; a distinct diagnostics instance creates another layer. Closing diagnostics does not close a developer's HTTP client.

## Dev proxy tooling and turnkey client factories

Both `codekit_dio` and `codekit_http` support optional runtime HTTP proxying for developer traffic inspection tools (Proxyman, Charles, Mitmproxy).

### Core domain model

`DevProxyConfig` is an immutable, pure-Dart value object defined in `codekit_core`. It sanitizes raw host inputs (stripping schemes, paths, and extraneous ports), validates port boundaries (1–65535), and produces standard PAC directives (`PROXY host:port` or `DIRECT`).

### SSL validation priority chain

Transport options (`DevProxyDioOptions` and `DevProxyHttpOptions`) guard certificate evaluation with the following priority order:
1. **Custom developer callback**: `badCertificateCallback` is invoked if supplied.
2. **Built-in MITM bypass**: Returns `true` if `proxy.isEnabled && proxy.isValid`, `allowBadCertificates` is `true`, and `isDebug` is `true`.
3. **Default secure reject**: Rejects invalid certificates.

The `isDebug` gate defaults to `!bool.fromEnvironment('dart.vm.product')` (or `kDebugMode` in Flutter apps), but callers can inject any custom runtime or compile-time condition (such as `const bool.fromEnvironment('ENABLE_DEV_PROXY')`).

### Turnkey client factories

Callers can instantiate fully wired clients in a single call:

```dart
// Dio
final dio = createCodeKitDio(
  options: BaseOptions(baseUrl: 'https://api.example.com'),
  diagnostics: diagnostics,
  proxyProvider: () => devProxyState,
  devProxyOptions: const DevProxyDioOptions.permissiveDebug(),
  interceptors: [AuthInterceptor()],
);

// package:http
final client = createCodeKitHttpClient(
  diagnostics: diagnostics,
  proxyProvider: () => devProxyState,
  devProxyOptions: const DevProxyHttpOptions.permissiveDebug(),
);
```

