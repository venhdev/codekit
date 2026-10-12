# codekit

Dart-first CodeKit umbrella. It re-exports `codekit_core` and `codekit_console`
for a minimal diagnostics setup; it does not create a global diagnostics
instance.

Version 0.1.0 is a redesign of the older 0.0.x `codekit` package. Its utility
functions are not re-exported; existing callers need an explicit migration.

```dart
import 'package:codekit/codekit.dart';

final diagnostics = CodeKitDiagnostics(sinks: [ColoredConsoleSink()]);
diagnostics.log(const LogInput(message: 'App started'));
```

Add only the optional packages your app needs: `codekit_dio` or `codekit_http`
for request capture, `codekit_drift_diagnostic_store` for native persistence,
`codekit_webhook` for Discord/Telegram delivery, `codekit_flutter` for Flutter
error hooks, or `codekit_ui` for an in-app viewer. These packages are not pulled
in by this umbrella.

The application creates and owns the `CodeKitDiagnostics` lifecycle, passes
the same instance to its selected integrations, and calls
`await diagnostics.dispose()` at its chosen shutdown boundary. Disposal closes
the diagnostics-owned store; it does not close the application's HTTP clients
or guarantee that pending writes are flushed.

The packages in this workspace are not currently published. See the repository
[implementation guide](../../doc/guides/codekit-implementation-guide.md) for
integration planning and package availability notes.
