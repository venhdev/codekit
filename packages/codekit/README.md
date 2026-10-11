# codekit

Dart-first umbrella for `codekit_core` and `codekit_console`. It re-exports
their public APIs without creating a global diagnostics instance.

Version 0.1.0 is a redesign of the older 0.0.x `codekit` package. Its utility
functions are not re-exported; existing callers need an explicit migration.

```dart
import 'package:codekit/codekit.dart';

final diagnostics = CodeKitDiagnostics(sinks: [ColoredConsoleSink()]);
diagnostics.log(const LogInput(message: 'App started'));
```

Add optional adapters such as `codekit_dio`, `codekit_http`,
`codekit_drift_diagnostic_store`, `codekit_webhook`, `codekit_flutter` or
`codekit_ui` only where needed. The application owns the diagnostics lifecycle
and calls `await diagnostics.dispose()` when it ends.
