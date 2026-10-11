# Test Harness Anchor — CodeKit

## Governing contracts

- [Public API](../doc/specs/public-api.md): concrete core defaults and verification boundaries.
- [Lifecycle](../doc/specs/diagnostic-data-lifecycle.md): queue, receipts, retention, redaction and Trace behavior.
- [Record schema](../doc/specs/record-schema.md): snapshot and codec semantics.

## Core verification

Run from workspace root with the pinned SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_core
.fvm/flutter_sdk/bin/dart test packages/codekit_core/test
```

Contract tests control time and write completion explicitly, without timing sleeps.
Controlled persistent-shaped stores prove core behavior, not real database durability.
No external services are needed for these core tests.

| Primitive | Location |
| :--- | :--- |
| Deterministic clock | CodeKitDiagnostics.clock input in [diagnostics.dart](../packages/codekit_core/lib/src/recorder/diagnostics.dart) |
| Controlled writes and sink collector | [controlled_store.dart](../packages/codekit_core/test/support/controlled_store.dart) |
| Core contract suite | [core_test.dart](../packages/codekit_core/test/core_test.dart) |
| Executable example | [main.dart](../packages/codekit_core/example/main.dart) |

Disk storage, transport, adapter and platform acceptance checks require their real implementations/environments; do not treat these helpers as feasibility proof for them.
