# codekit_drift_diagnostic_store

Native SQLite persistence for CodeKit diagnostics, implemented with Drift.

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_drift_diagnostic_store/codekit_drift_diagnostic_store.dart';

final diagnostics = await createDriftDiagnostics(
  databasePath: '/path/chosen/by/the/application/codekit.sqlite',
  retention: RetentionPolicy(maxRecords: 1000),
);

diagnostics.log(const LogInput(message: 'Application started'));

// The application decides when its diagnostics lifecycle ends.
await diagnostics.dispose();
```

The application supplies a native filesystem path. The adapter creates its
parent directory, opens the database, and is closed by `diagnostics.dispose()`.
The adapter targets Android, iOS and desktop native runtimes. Web should use
the core `MemoryDiagnosticStore` in this MVP. SQLite schema migrations are
explicit; the initial database schema is version 1 and unknown upgrade paths
fail without deleting the existing database.

`DriftDiagnosticStore.open()` can be used when composing `CodeKitDiagnostics`
manually. In that case, the diagnostics instance owns and closes the injected
store on disposal. Malformed persisted records and Trace sessions are skipped
with a warning; provide `onStoreWarning` to customize that reporting path.

## Development

Run `dart run build_runner build` after changing the Drift schema. The generated
database file is checked in with the package. Run `dart test` to verify actual
SQLite persistence, reopen behavior, retention, queries and Trace sessions.
