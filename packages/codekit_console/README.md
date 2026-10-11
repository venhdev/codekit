# codekit_console

Optional colored console output for CodeKit diagnostic records. The sink
receives the core's redacted dispatch representation. Its default policies
print all LOG and HTTP records; pass policies to narrow them.

```dart
final diagnostics = CodeKitDiagnostics(sinks: [
  ColoredConsoleSink(
    logDispatchPolicy: LogDispatchPolicy(levels: {LogLevel.error, LogLevel.fatal}),
  ),
]);
```

`colored_logger` detects terminal ANSI support; on Web its default output is
plain text. A custom `writer` may route lines elsewhere.
