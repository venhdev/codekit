# Test Harness Anchor — CodeKit

## Governing contracts

- [Engineering Standards](../doc/standards/engineering-standards.md): cross-cutting implementation, Dart formatting and verification practices.
- [Public API](../doc/specs/public-api.md): concrete core defaults and verification boundaries.
- [Lifecycle](../doc/specs/diagnostic-data-lifecycle.md): queue, receipts, retention, redaction and Trace behavior.
- [Record schema](../doc/specs/record-schema.md): snapshot and codec semantics.

## Core verification

Run from workspace root with the pinned SDK:

```sh
.fvm/flutter_sdk/bin/dart analyze packages/codekit_core
.fvm/flutter_sdk/bin/dart test packages/codekit_core/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_dio
.fvm/flutter_sdk/bin/dart test packages/codekit_dio/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_http
.fvm/flutter_sdk/bin/dart test packages/codekit_http/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_webhook
.fvm/flutter_sdk/bin/dart test packages/codekit_webhook/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_drift_diagnostic_store
(cd packages/codekit_drift_diagnostic_store && ../../.fvm/flutter_sdk/bin/dart test)
.fvm/flutter_sdk/bin/flutter analyze packages/codekit_ui
.fvm/flutter_sdk/bin/flutter test packages/codekit_ui/test
.fvm/flutter_sdk/bin/flutter test packages/codekit_ui/test_native
.fvm/flutter_sdk/bin/flutter analyze packages/codekit_flutter
.fvm/flutter_sdk/bin/flutter test packages/codekit_flutter/test
.fvm/flutter_sdk/bin/dart analyze packages/colored_logger
.fvm/flutter_sdk/bin/dart test packages/colored_logger/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_console
.fvm/flutter_sdk/bin/dart test packages/codekit_console/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit
```

With Chrome installed, run the Web widget suite from the UI package directory
(Flutter's Web test loader resolves that package's local `test/` path):

```sh
cd packages/codekit_ui
CHROME_EXECUTABLE=/path/to/chrome ../../.fvm/flutter_sdk/bin/flutter test --platform chrome test
cd ../codekit_flutter
CHROME_EXECUTABLE=/path/to/chrome ../../.fvm/flutter_sdk/bin/flutter test --platform chrome test
cd ../codekit_console
CHROME_EXECUTABLE=/path/to/chrome ../../.fvm/flutter_sdk/bin/dart test --platform chrome test
cd ../colored_logger
CHROME_EXECUTABLE=/path/to/chrome ../../.fvm/flutter_sdk/bin/dart test --platform chrome test
```

Contract tests control time and write completion explicitly, without timing sleeps.
The Drift test command runs from its package so Dart executes the sqlite3 native
asset build hook for the selected host platform. No external services are needed.

| Primitive | Location |
| :--- | :--- |
| Deterministic clock | CodeKitDiagnostics.clock input in [diagnostics.dart](../packages/codekit_core/lib/src/recorder/diagnostics.dart) |
| Controlled writes and sink collector | [controlled_store.dart](../packages/codekit_core/test/support/controlled_store.dart) |
| Core contract suite | [core_test.dart](../packages/codekit_core/test/core_test.dart) |
| Executable example | [main.dart](../packages/codekit_core/example/main.dart) |
| Dio adapter integration suite | [local_http_integration_test.dart](../packages/codekit_dio/test/local_http_integration_test.dart) |
| Dio extension/interceptor tests | [interceptor_test.dart](../packages/codekit_dio/test/interceptor_test.dart) |
| package:http wrapper tests | [client_wrapper_test.dart](../packages/codekit_http/test/client_wrapper_test.dart) |
| package:http adapter integration suite | [local_http_integration_test.dart](../packages/codekit_http/test/local_http_integration_test.dart) |
| Webhook transport and sink suite | [webhook_sinks_test.dart](../packages/codekit_webhook/test/webhook_sinks_test.dart) |

The Drift suite uses real temporary SQLite files and verifies close/reopen durability, count eviction, query pagination and persisted Trace sessions. The default webhook client is exercised against a local loopback server; remote service acceptance requires its target environment. UI Web widget tests run in Chrome; a manual Chrome runtime check verified the downloaded text file. Native file creation and share plugin invocation are covered by a mock-platform test, while the Android/iOS share sheet still requires device QA. Dio and package:http adapter integration tests use their real client packages and a loopback HTTP server.
