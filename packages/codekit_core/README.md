# codekit_core

Platform-neutral Dart diagnostics: one typed `log()` entrypoint, an in-memory
store by default, optional count retention, redaction, paged queries, Trace
sessions and text export. Persistent stores, HTTP adapters, sinks and Flutter UI
implement public contracts without making core depend on Flutter, Dio,
`package:http`, or a database.

```dart
final diagnostics = CodeKitDiagnostics(
  retention: RetentionPolicy(maxRecords: 1000),
);

final receipt = diagnostics.log(
  LogInput(message: 'App started', tags: {'startup'}),
);
final page = await diagnostics.query(RecordQuery(limit: 100));
final exported = await diagnostics.exportRecords([receipt.recordId!]);
await diagnostics.dispose();
```

`CodeKitDiagnostics` owns its configured store and sink lifecycles, including an
injected store; it does not own developer-injected transport clients. The
default record mode is Store raw, while export defaults to Redacted. Redaction
is configurable but does not certify that all sensitive data has been found.
Raw-mode records may retain secrets on disk. Persistent writes are asynchronous
and best-effort; disposal does not flush pending writes.

Memory storage is unlimited unless `RetentionPolicy` sets a count limit.
Persistent storage requires an optional adapter such as
`codekit_drift_diagnostic_store`. Core itself has no Flutter, HTTP-client, or
database setup. This workspace package is not currently published; see the
[implementation guide](../../doc/guides/codekit-implementation-guide.md).

The canonical contracts live in the repository's `doc/specs/` directory. Run
the example, analyzer and tests from the workspace root using its pinned Dart
SDK:

```sh
.fvm/flutter_sdk/bin/dart run packages/codekit_core/example/main.dart
.fvm/flutter_sdk/bin/dart analyze packages/codekit_core
.fvm/flutter_sdk/bin/dart test packages/codekit_core/test
```
