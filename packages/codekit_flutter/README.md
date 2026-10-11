# codekit_flutter

Optional Flutter framework and root-isolate exception capture for
`codekit_core`. Install after your app configures its own error callbacks:

```dart
final diagnostics = CodeKitDiagnostics();
final hooks = CodeKitFlutterErrorHooks.install(diagnostics);

// When your app's diagnostics lifecycle ends:
hooks.dispose();
await diagnostics.dispose();
```

Existing callbacks are called after CodeKit records the error. `dispose()`
restores callbacks only when CodeKit's wrapper is still installed. This package
does not depend on the viewer or a specific store.
