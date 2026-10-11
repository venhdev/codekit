# CodeKit

CodeKit is a Dart-first diagnostics workspace. The [codekit](packages/codekit/README.md)
umbrella exports the platform-neutral recorder and colored console sink. HTTP
capture, native persistence, webhooks, Flutter error hooks and the Flutter viewer
are independently installable packages.

```dart
import 'package:codekit/codekit.dart';

final diagnostics = CodeKitDiagnostics(sinks: [ColoredConsoleSink()]);
diagnostics.log(const LogInput(message: 'App started'));
```

The [documentation index](doc/README.md) links to the authoritative
[architecture](doc/specs/system-architecture.md),
[public API](doc/specs/public-api.md) and [roadmap](doc/roadmap.md).
The [harness anchor](.agents/harness-anchor.md) lists verification commands.

No package has been published from this workspace. Release preparation and
per-package publication are described in the
[publishing runbook](doc/runbooks/pub-workspace-publishing.md).
