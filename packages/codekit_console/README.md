# codekit_console

Optional colored console output for CodeKit diagnostic records. The sink
receives the dispatch representation prepared by core, including the current
redaction policy. By default it accepts both LOG and HTTP records; use dispatch
policies to narrow output.

```dart
final diagnostics = CodeKitDiagnostics(sinks: [
  ColoredConsoleSink(
    logDispatchPolicy: LogDispatchPolicy(
      levels: {LogLevel.warning, LogLevel.error, LogLevel.fatal},
    ),
  ),
]);
```

`colored_logger` detects terminal ANSI support; on Web its default output is
plain text. A custom `writer` can route formatted lines elsewhere. Console
output is synchronous and is not persistent storage.

The package is part of the unpublished workspace. For integration and package
availability guidance, see the
[CodeKit implementation guide](../../doc/guides/codekit-implementation-guide.md).
