# codekit_flutter

Optional Flutter framework and root-isolate exception capture for
`codekit_core`. Install after the app configures its own error callbacks:

```dart
final diagnostics = CodeKitDiagnostics();
final hooks = CodeKitFlutterErrorHooks.install(diagnostics);

// When your app's diagnostics lifecycle ends:
hooks.dispose();
await diagnostics.dispose();
```

Existing callbacks are called after CodeKit records the error. `dispose()`
restores callbacks only when CodeKit's wrapper is still installed. This package
does not depend on the viewer or a specific store. Hook installation is
explicit; it does not happen automatically when diagnostics is constructed.

Keep the returned hooks handle for the same lifecycle scope as the global
callbacks. Dispose it before disposing diagnostics when capture should stop. If
another library replaces a callback after CodeKit installs its wrapper,
disposal leaves that newer callback in place instead of overwriting it. These
hooks supplement rather than replace the app's error-reporting policy.

This workspace package is not currently published. See the
[implementation guide](../../doc/guides/codekit-implementation-guide.md) for
integration workflow.
