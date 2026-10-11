# codekit_ui

Optional Flutter viewer for `codekit_core`: a floating bubble, paged records,
filters, HTTP details, Trace sessions, search history and explicit copy/share.

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

The bubble is visible in all builds by default. Pass `debugOnly: true` to
restrict it to debug builds. The caller owns `diagnostics` and closes it at the
appropriate application lifecycle point. The screen is also usable directly
as `CodeKitDiagnosticsScreen(diagnostics: diagnostics)`.

Run from the workspace root:

```sh
.fvm/flutter_sdk/bin/flutter analyze packages/codekit_ui
.fvm/flutter_sdk/bin/flutter test packages/codekit_ui/test
```
