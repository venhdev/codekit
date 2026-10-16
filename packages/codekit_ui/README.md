# codekit_ui

Optional Flutter viewer and export UI for `codekit_core`. It provides a
floating bubble, paged/searchable/filterable records, HTTP request/response
details, Trace sessions, read-only viewer settings, and explicit copy/share
actions.

Place `CodeKitBubble` in `MaterialApp.builder` and pass the same navigator key
used by `MaterialApp`:

```dart
final diagnostics = CodeKitDiagnostics();
final navigatorKey = GlobalKey<NavigatorState>();

MaterialApp(
  navigatorKey: navigatorKey,
  builder: (context, child) => CodeKitBubble(
    diagnostics: diagnostics,
    navigatorKey: navigatorKey,
    child: child!,
  ),
  home: const MyAppHome(),
);
```

The bubble is enabled in Debug and Profile builds by default (`enabled: !kReleaseMode`)
and automatically hidden in Release builds to protect production environments.
Pass custom conditions (e.g., `enabled: kDebugMode` for debug-only, `enabled: false`
to rely solely on secret trigger gestures, or role/flavor checks). The caller
owns `diagnostics` and closes it at the appropriate application lifecycle point.
The screen is also usable directly as `CodeKitDiagnosticsScreen(diagnostics: diagnostics)`
when the app wants to control navigation itself.

The viewer can show the active `RedactionPolicy` and factual setup as read-only
settings. Runtime record-mode switching is opt-in and affects new records
only. Copy/share asks whether to export a redacted copy or data as stored.
Redacted export applies the current policy but does not guarantee discovery of
every sensitive value; As-stored export can expose raw data. Review that choice
with users and do not treat viewer access as an authorization boundary.

Headers and bodies are displayed only when their captured representation is
available; adapters may report data as absent, disabled, or unsupported. The
viewer cannot make unsupported streams or byte payloads capturable. Native
platforms can share a text file; Web uses a download flow for file export.
Interaction and layout contracts are in the
[diagnostics UI specification](../../doc/specs/diagnostics-ui.md).

Run from the workspace root:

```sh
.fvm/flutter_sdk/bin/flutter analyze packages/codekit_ui
.fvm/flutter_sdk/bin/flutter test packages/codekit_ui/test
```

This workspace package is not currently published. For app-level package
selection and setup, see the
[CodeKit implementation guide](../../doc/guides/codekit-implementation-guide.md).
