# codekit_dio

Dio interceptor integration for `codekit_core`. Attach diagnostics to the
application's existing configured Dio instance with `withDiagnostics()`:

```dart
final diagnostics = CodeKitDiagnostics();
final dio = Dio().withDiagnostics(diagnostics);

await dio.get('https://example.com/users/42');
final records = await diagnostics.query(RecordQuery());
```

The extension returns the same Dio instance and avoids attaching the same
diagnostics instance twice. Each interceptor keeps its request state privately;
each retry attempt that enters the interceptor creates its own record. Redirects
handled internally by Dio's adapter remain part of the logical request.

Request and response streams are not consumed by CodeKit. Text and JSON snapshots
are captured when already available, multipart requests retain fields and file
metadata without reading file bytes, and typed byte arrays/stream bodies are
marked unsupported. Request IDs stay inside the process and are not added to
headers. Capture exclusions can be configured on `CodeKitDiagnostics` and
prevent excluded requests from entering diagnostic processing.

`CodeKitDiagnostics.dispose()` does not close the application's Dio instance.
The application owns and closes Dio according to its own lifecycle. Do not
create a parallel client or change request behavior to make a snapshot more
complete. For exact completion and retry semantics, see the
[HTTP adapter specification](../../doc/specs/http-client-adapters.md).

This workspace package is not currently published. Run its local integration
suite with the pinned workspace SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_dio
.fvm/flutter_sdk/bin/dart test packages/codekit_dio/test
```

See the [implementation guide](../../doc/guides/codekit-implementation-guide.md)
for package availability and integration workflow.
