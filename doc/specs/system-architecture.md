---
title: CodeKit System Architecture
description: System boundaries and dependency direction for the CodeKit diagnostics ecosystem.
status: draft
created: 2026-10-10
updated: 2026-10-11
---

# CodeKit System Architecture

## Purpose

CodeKit provides diagnostics that Dart projects can adopt early and keep using during operation. It captures useful context, supports inspection and sharing, and allows optional integrations without making the general-purpose core depend on Flutter or a specific storage backend.

The [CodeKit roadmap](../roadmap.md) owns product direction and milestones. This document owns system boundaries and dependency direction. The [diagnostic data lifecycle](diagnostic-data-lifecycle.md) owns event retention, Trace sessions, export, and sink delivery guarantees. The [diagnostics UI specification](diagnostics-ui.md) owns records inspection and UI workflows.

## System boundaries

### Dart diagnostics core

The core defines the platform-neutral diagnostic concepts and APIs used by producers and consumers. It accepts logs, errors, stack traces, breadcrumbs, and context from Dart code. It coordinates recording and access to diagnostic events without requiring Flutter, `dart:io`, a UI, a network service, or a concrete persistent store.

The core's default recorder is memory-only with unlimited retained count by default; an optional count limit follows the lifecycle contract. Persistent recording is provided by an optional adapter. The core exposes capabilities needed by built-in and custom interfaces so applications do not need `codekit_ui` to use diagnostics or manage Trace sessions.

### Optional adapters and sinks

Adapters connect platform or library-specific signals to the core. Examples include Flutter error hooks and Dio collection. They depend on the core contract; the core does not depend on them.

Sinks implement `DiagnosticSink` and consume prepared diagnostic representations for a destination or presentation. Examples include colored terminal output and outbound webhooks. A sink is optional and does not own the canonical event model or recorder. Policies, transport, presentation options and fire-and-forget delivery guards are owned by [diagnostic sinks](diagnostic-sinks.md).

### Ready-to-use storage packages

CodeKit will maintain optional storage adapter packages that applications can add as dependencies and initialize with minimal setup. An adapter owns its backend schema, migrations, persistence and queries, and implements the shared retention contract from the [diagnostic data lifecycle](diagnostic-data-lifecycle.md#retention-and-eviction). Applications configure storage location and retention limits through the adapter's supported setup API. Backends must not define competing retention semantics.

These packages depend on core contracts; the core does not import their implementations. Drift is the sole CodeKit-maintained persistent backend selected for MVP. `codekit_drift_diagnostic_store` exposes `DriftDiagnosticStore` and `createDriftDiagnostics()`. The adapter targets Android, iOS and desktop native platforms; Web uses memory in MVP. Developers may implement the public `DiagnosticStore` contract for other backends. Encryption support and key management are not selected by this decision.

### User interfaces and export

`codekit_ui` is an optional presentation package. It can inspect diagnostics and manage Trace sessions through public diagnostics APIs. A project-specific UI can use the same APIs without depending on `codekit_ui`.

Export produces a shareable representation from selected diagnostic event IDs or an explicitly selected matching result set. The caller chooses whether to redact a copy or export the data as stored; export does not mutate stored records. Platform-specific file delivery belongs in an optional UI/platform adapter: native platforms may share a temporary text file, while Web may download a generated `.txt` file. This is a data access/output capability, not a separate logging pipeline.

Redaction is a platform-neutral data transformation shared by recording and export. Its policy behavior is owned by the [diagnostic data lifecycle](diagnostic-data-lifecycle.md#redaction-policy). Storage adapters persist the representation prepared by the recorder; the built-in UI and custom interfaces use public data access/export APIs. HTTP inspection and JSON presentation belong in the optional UI, not the core.

### MCP adapter

An MCP adapter is a later, optional integration for compatible agents. It consumes stable diagnostic and export contracts; it is not a dependency of the diagnostics core or application runtime.

The [public API](public-api.md) owns entrypoint names, setup composition, receipt shape and storage interface. `CodeKitDiagnostics` is created explicitly and passed to adapters/UI; core has no default global singleton.

## Package boundaries and workspace layout

| Package | Responsibility | Dependency boundary |
| --- | --- | --- |
| `codekit_core` | Shared models, recorder, memory store, retention, redaction, sessions, query/export and sink contracts | General-purpose Dart; no Flutter or concrete storage dependency. |
| `codekit` | Umbrella, convenient configuration and selected Dart defaults | Core and explicitly selected platform-compatible defaults. |
| `codekit_ui` | Bubble, viewer, HTTP/JSON details and platform share/download | Core and Flutter. Initial Flutter helpers can remain here. |
| `codekit_dio` | Dio capture, interceptor and withDiagnostics extension | Core and Dio. |
| `codekit_http` | package:http capture, BaseClient wrapper and withDiagnostics extension | Core and package:http; independent of webhook delivery. |
| `codekit_drift_diagnostic_store` | Native Drift persistence, schema, migrations and platform openers | Core and Drift; optional and not pulled into the umbrella. |
| `codekit_webhook` | Webhook payload formatting and delivery | Core contracts and injected `WebhookTransport`; no Dio/http client types required by the interface. |
| `colored_logger` | Independently usable console formatting/output | Existing library moved into the workspace; native/Web boundary requires adjustment before default umbrella inclusion. |

Models, redaction and sessions stay in core instead of separate publishable packages. `codekit_http` is now selected for implementation alongside `codekit_dio`; both support installation independently of the umbrella. Their adapter contracts are owned by [HTTP client adapters](http-client-adapters.md). `type_caster` is not a required core dependency. MCP remains later work. Existing published library API compatibility and migration details must be addressed before moving library code.

The repository uses a private Pub workspace root with explicitly listed members. Each member declares `resolution: workspace`; internal dependencies use compatible version constraints rather than development-only path dependencies. One root lockfile resolves members together. Publishing remains per package through the [publishing runbook](../runbooks/pub-workspace-publishing.md).

```text
codekit/
├── pubspec.yaml                 # private workspace root
├── pubspec.lock
├── analysis_options.yaml
├── .fvmrc
├── doc/
├── packages/
│   ├── codekit/
│   ├── codekit_core/
│   ├── codekit_ui/
│   ├── codekit_dio/
│   ├── codekit_http/
│   ├── codekit_drift_diagnostic_store/
│   ├── codekit_webhook/
│   └── colored_logger/
├── examples/
│   ├── dart_console/
│   └── flutter_diagnostics/
└── tool/
```

Examples with manifests must have explicit workspace membership or a deliberate independent resolution. The private workspace root and codekit_core member now exist. Other entries remain the target layout and must not be created as empty placeholder packages.

Each package has a curated `lib/<package>.dart` entrypoint, private implementation under `lib/src/`, and `test/` and `example/` where applicable. Other packages must not import its `src` files. Core implementation groups follow actual responsibilities: `models`, `recorder`, `storage`, `retention`, `redaction`, `sessions`, `query`, `export`, and `sinks`. Additional service/repository/manager layers are not required merely for directory symmetry.

## Store and sink composition

`CodeKitDiagnostics` is the explicit instance entrypoint; its constructor composes one store, retention/redaction configuration and multiple sinks. LOG and HTTP both enter through `log()` with typed input. A store remains distinct from sinks because it owns queryable data and persistence receipts; console and remote outputs do not become alternative query stores. Diagnostics owns its store and sinks, while developer-injected transport clients remain developer-owned. Discord/Telegram configurations remain in optional integrations; their exact package split is not selected yet.

## Dependency direction

```text
Dart application and optional producers
                 │
                 ▼
       Dart diagnostics core
          │      │       │
          ▼      ▼       ▼
 optional store  sinks  session/export APIs
 adapter         │       │
                 │       ├── codekit_ui (optional)
                 │       └── custom application UI
                 └── webhook (fire-and-forget)

Later: MCP adapter consumes stable diagnostic/export APIs
```

Adapters may depend on the core contracts. The core must not import a platform adapter or depend on a UI, webhook client, or MCP implementation.

## Supported environment boundary

The diagnostics core targets Dart generally. Platform-specific behavior belongs behind optional adapters. Flutter-specific functionality is not part of the core contract. A package that uses platform APIs must isolate them so a consumer only needs the implementation for its target environment.

## Non-goals for the core

- Requiring a Flutter application or Flutter UI.
- Requiring persistent storage or one storage technology.
- Requiring webhook delivery or an MCP server.
- Making a Trace session a second event-capture system separate from diagnostics.

## Open design points

- Exact default umbrella composition and public exports, including colored console Web compatibility.
- Remaining API signatures and codec details in the [record schema](record-schema.md); lifecycle behavior is owned by the [diagnostic data lifecycle](diagnostic-data-lifecycle.md).
- Native Drift opener details and schema/migration implementation.
- Existing package migration, compatibility, SDK constraints and examples membership details.
