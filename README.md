# CodeKit

Dart diagnostics with an optional ecosystem of client adapters, storage and UI.
The first implemented package is [codekit_core](packages/codekit_core/README.md).
Other integrations are designed but not implemented yet.

Start with the [documentation index](doc/README.md), [public API](doc/specs/public-api.md)
and [roadmap](doc/roadmap.md).

The private Pub workspace currently has one member. Use the repository's pinned
SDK to resolve dependencies, run the core example and verify the implementation:

```sh
.fvm/flutter_sdk/bin/dart pub get
.fvm/flutter_sdk/bin/dart run packages/codekit_core/example/main.dart
.fvm/flutter_sdk/bin/dart analyze packages/codekit_core
.fvm/flutter_sdk/bin/dart test packages/codekit_core/test
```

Packages are not ready for publication. Release workflow is documented separately
in the [publishing runbook](doc/runbooks/pub-workspace-publishing.md).
