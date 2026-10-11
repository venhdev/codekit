# codekit_core

Pure Dart diagnostics with one typed `log()` entrypoint, an unlimited memory
store by default, optional count retention, redaction, paged queries, Trace
sessions and text export. Persistent adapters and platform sinks implement the
public contracts without making core depend on Flutter, Dio, HTTP or a database.

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

Record mode defaults to Store raw; export defaults to Redacted. Configured
redaction rules do not certify that all sensitive data has been removed.
Injected stores and sinks are owned by diagnostics. Pending persistence is
best-effort and is not drained on dispose. This initial package is not published.

The canonical contracts live in the repository's doc/specs/ directory. Run the
example and tests from the workspace root using its pinned Dart SDK:

```sh
.fvm/flutter_sdk/bin/dart run packages/codekit_core/example/main.dart
.fvm/flutter_sdk/bin/dart analyze packages/codekit_core
.fvm/flutter_sdk/bin/dart test packages/codekit_core/test
```
