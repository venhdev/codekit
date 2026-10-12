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

Each `head/get/post/put/patch/delete` call forwards to the same method on the
inner client with the original parameters. The wrapper snapshots the completed
`Response` and returns that exact instance, including custom subclasses.
Supported JSON/text bodies are captured completely, without a size limit.
Empty buffered bodies are absent; binary/unknown types and decode failures
are unsupported. `read/readBytes` also preserve custom inner overrides: read
captures the returned text; readBytes has no media type and remains unsupported.
Neither method exposes response status/headers, so diagnostics leave those
fields unknown.

`send()` returns the original `StreamedResponse` without subscribing to,
wrapping or consuming its stream. It records metadata at headers, with body
unsupported, even when the app never reads the stream. Later stream errors and
cancellation stay on the application stream and do not update that record.
Duration ends when the inner method completes, before snapshot processing;
record/Trace acceptance follows that boundary. Capture has CPU/memory overhead,
but does not await persistence or sink delivery.

Available request data may be snapshotted; streamed request bodies and multipart
file bytes are not read. Multipart content type is recorded
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
