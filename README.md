# CodeKit

**Capture the context around a problem. Inspect it in your app. Share a useful
report.**

CodeKit is a modular diagnostics toolkit for Dart and Flutter applications. It
records application logs and HTTP activity in one queryable timeline, then lets
you inspect, filter, and export that data. Add only the integrations your app
uses: CodeKit's core is platform-neutral Dart, while Flutter UI, HTTP clients,
persistent storage, and outbound sinks are separate packages.

> Current workspace package versions are not published to pub.dev. The `codekit`
> umbrella has a historical 0.0.x release line; the current workspace is a
> redesigned package set. See [publishing status](doc/runbooks/pub-workspace-publishing.md).

## What you can build

- **Capture:** application logs, errors, stack traces, context, and requests
  made through selected Dio or `package:http` clients.
- **Keep:** in-memory records by default, or persistent native SQLite storage
  through the optional Drift adapter.
- **Inspect:** search and filter records, review HTTP request/response details,
  and group record IDs into Trace sessions in the optional Flutter viewer.
- **Share:** copy or share selected records and HTTP fragments, choosing a
  redacted export or the representation as stored.
- **Route:** send selected LOG/HTTP events to colored console output, Discord,
  or Telegram using independently configured sinks.
- **Integrate with Flutter:** optionally capture framework and root-isolate
  errors, or add the in-app diagnostics viewer.

The overall flow is:

```text
app logs / HTTP clients / Flutter hooks
                  │
                  ▼
          codekit_core recorder
           ┌──────┼──────────┐
           ▼      ▼          ▼
         store   sinks    query/export
                            │
                            ▼
                       codekit_ui
```

Adapters and UI depend on the core contracts; the core does not depend on
Flutter, Dio, `package:http`, Drift, or a webhook provider. You can use the
public core APIs with a custom store, sink, or UI as well.

## Choose features for your app

Copy this block, check the features you want, and give it to your coding agent.
Options in a `choose one` group are alternatives; `choose independently` groups
can include multiple items. The [implementation guide](doc/guides/codekit-implementation-guide.md)
contains the setup sequence, integration constraints, and a full agent prompt.

```text
HTTP capture (choose independently)
[ ] Dio
[ ] package:http

Storage (choose one)
[ ] In-memory (default)
[ ] SQLite with Drift (native platforms)

Diagnostic sinks (choose independently)
[ ] Colored console
[ ] Discord webhook
[ ] Telegram bot

Flutter integrations (choose independently)
[ ] In-app diagnostics viewer
[ ] Flutter framework and root-isolate error capture

Record mode (choose one)
[ ] Redact before recording
[ ] Store raw

Full setup guide and agent prompt (raw Markdown):
https://raw.githubusercontent.com/venhdev/codekit/main/doc/guides/codekit-implementation-guide.md
```

## Quick start

The `codekit` umbrella re-exports `codekit_core` and `codekit_console`. This
minimal example records an application event, queries the timeline, and disposes
the diagnostics instance:

```dart
import 'package:codekit/codekit.dart';

Future<void> main() async {
  final diagnostics = CodeKitDiagnostics(
    sinks: [ColoredConsoleSink()],
    retention: RetentionPolicy(maxRecords: 1000),
  );

  diagnostics.log(
    const LogInput(message: 'Application started', tags: {'startup'}),
  );

  final page = await diagnostics.query(RecordQuery(limit: 100));
  print('Loaded ${page.records.length} diagnostic records');

  await diagnostics.dispose();
}
```

HTTP capture is added to the app's existing client with a separate package. For
example, `codekit_dio` attaches to the same configured Dio instance:

```dart
final dio = existingDio.withDiagnostics(diagnostics);
```

The extension returns that same Dio instance. The `package:http` integration
wraps a client instead, so use and close the returned wrapper. See each package
README for its setup and capture boundaries.

## Packages

| Package | What it provides | Target |
| --- | --- | --- |
| [`codekit`](packages/codekit/README.md) | Convenience umbrella re-exporting core and colored console | Dart |
| [`codekit_core`](packages/codekit_core/README.md) | Records, recorder, memory store, redaction, retention, Trace sessions, queries, export, and extension contracts | Dart |
| [`codekit_console`](packages/codekit_console/README.md) | Colored console diagnostic sink | Dart; plain-text fallback on Web |
| [`codekit_dio`](packages/codekit_dio/README.md) | Dio interceptor and `withDiagnostics()` extension | Dart + Dio |
| [`codekit_http`](packages/codekit_http/README.md) | `package:http` client wrapper and `withDiagnostics()` extension | Dart + `package:http` |
| [`codekit_drift_diagnostic_store`](packages/codekit_drift_diagnostic_store/README.md) | Persistent SQLite store and setup factory | Android, iOS, desktop; not Web in this MVP |
| [`codekit_webhook`](packages/codekit_webhook/README.md) | Discord and Telegram diagnostic sinks | Dart + network access |
| [`codekit_flutter`](packages/codekit_flutter/README.md) | Opt-in Flutter framework and root-isolate error hooks | Flutter |
| [`codekit_ui`](packages/codekit_ui/README.md) | Flutter bubble, viewer, Trace management, settings, and export UI | Flutter |
| [`colored_logger`](packages/colored_logger/README.md) | Reusable colored terminal formatting used by the console sink | Dart |

All packages are independently selectable except that integrations build on
`codekit_core`. The `codekit` umbrella does not pull in HTTP adapters, Drift,
webhooks, Flutter hooks, or the UI.

## Data and privacy

CodeKit separates what is stored from what is exported:

- The default storage is in-memory and has no record-count limit unless one is
  configured. Persistent storage is opt-in.
- The default record mode is **Store raw**. Configure **Redact before
  recording** if matching values must not enter the store.
- Export defaults to **Redacted**, and can also be explicitly exported **As
  stored**. Redaction applies to a copy and does not rewrite stored records.
- Redaction rules cover common cases; they do not guarantee discovery of every
  secret or personal value. Review policies and exported data for your use case.
- HTTP capture does not consume streams or read file bytes. Some bodies are
  intentionally unavailable or marked unsupported rather than buffering or
  changing the app's network behavior.
- Webhook delivery is best-effort and not retried. Treat endpoint URLs and bot
  tokens as secrets, and consider the destination before sending diagnostic
  content.

The authoritative contracts are in [diagnostic data lifecycle](doc/specs/diagnostic-data-lifecycle.md),
[record schema](doc/specs/record-schema.md),
[HTTP adapters](doc/specs/http-client-adapters.md), and
[diagnostic sinks](doc/specs/diagnostic-sinks.md).

## Documentation and development

- [Documentation index](doc/README.md) — where each project contract lives.
- [Implementation guide](doc/guides/codekit-implementation-guide.md) — setup guidance and copyable coding-agent prompt.
- [System architecture](doc/specs/system-architecture.md) — package boundaries and dependency direction.
- [Public API](doc/specs/public-api.md) — setup, lifecycle, query, and storage contracts.
- [Diagnostics UI](doc/specs/diagnostics-ui.md) — viewer workflows and interaction behavior.
- [Roadmap](doc/roadmap.md) — product direction and milestone status.
- [Publishing runbook](doc/runbooks/pub-workspace-publishing.md) — per-package release preflight and publishing.
- [Harness anchor](.agents/harness-anchor.md) — workspace verification commands.

This repository is a Pub workspace. Use its pinned SDK and workspace commands
when developing packages; do not assume the current versions can be added from
pub.dev. The package READMEs document focused analyzer and test commands.
