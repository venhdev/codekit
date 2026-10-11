# codekit_http

`package:http` wrapper for `codekit_core`. Pass in the HTTP client configured by
your app, then use the returned wrapper:

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

The app chooses the client implementation and controls when its wrapped client
is closed. `close()` on the wrapper forwards to the inner client. Reapplying the
same diagnostics instance anywhere in the wrapper chain does not add another
capture layer; a different diagnostics instance adds a layer.

The wrapper captures at `send()`, which covers `Client` convenience methods. It
does not consume request or response streams. Available text/JSON request bodies
and multipart fields/file metadata can be recorded; multipart file bytes,
streamed bodies and response bodies are not captured. HTTP response records are
completed when response headers arrive. Multipart content type is recorded
without the boundary that the inner client adds during request finalization.

This package is not published. Run checks from the workspace root with its
pinned Dart SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_http
.fvm/flutter_sdk/bin/dart test packages/codekit_http/test
```
