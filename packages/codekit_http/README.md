# codekit_http

`package:http` wrapper for `codekit_core`. Wrap the HTTP client configured by
your app, then use the returned wrapper for requests:

```dart
final appClient = createConfiguredClient();
final client = appClient.withDiagnostics(diagnostics);

try {
  final response = await client.get(uri);
  print(response.statusCode);
} finally {
  client.close();
}
```

The extension returns a wrapper, not the original client. Keep using and close
the returned wrapper; its `close()` forwards to the inner client exactly once.
The app chooses the client implementation and owns its lifecycle. Reapplying the
same diagnostics instance anywhere in the wrapper chain does not add another
capture layer; a different diagnostics instance adds a layer.

The wrapper captures at `send()`, which covers `Client` convenience methods. It
does not consume request or response streams. Available text/JSON request bodies
and multipart fields/file metadata can be recorded; multipart file bytes,
streamed bodies and response bodies are not captured. HTTP response records are
completed when response headers arrive. Multipart content type is recorded
without the boundary that the inner client adds during request finalization.
Requests made through the original inner client or top-level `http` helpers
bypass this wrapper. Wrapper order determines whether retries appear as
individual attempts or as a final result.

This workspace package is not currently published. Run checks from the
workspace root with its pinned Dart SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_http
.fvm/flutter_sdk/bin/dart test packages/codekit_http/test
```

For capture boundaries and retry behavior, read the
[HTTP adapter specification](../../doc/specs/http-client-adapters.md). The
[implementation guide](../../doc/guides/codekit-implementation-guide.md)
describes selection and setup in an existing app.
