# codekit_dio

Dio interceptor integration for `codekit_core`. Add diagnostics to an existing
Dio instance with `withDiagnostics()`:

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
headers.

`CodeKitDiagnostics.dispose()` does not close the application's Dio instance.
The application owns and closes Dio according to its own lifecycle.

This package is not published. Run its local integration suite with the pinned
workspace SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_dio
.fvm/flutter_sdk/bin/dart test packages/codekit_dio/test
```
