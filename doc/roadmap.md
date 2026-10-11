---
title: CodeKit Roadmap
description: Draft direction and milestones for the CodeKit package ecosystem.
status: draft
created: 2026-10-10
updated: 2026-10-11
---

# CodeKit Roadmap

This document is the single source of truth for CodeKit's product direction and milestone status. Detailed package contracts and architecture belong in their own specifications and should be linked here when established. See the [documentation index](README.md) for documentation ownership.

## Approved direction

CodeKit is a Dart developer-tool ecosystem with a general-purpose Dart diagnostics core that can be adopted from the start of a project and remain useful during operation. The `codekit` package is intended to provide a convenient umbrella over independently usable packages. Flutter-specific capabilities remain optional integrations; the core must not require Flutter.

The product should help developers capture useful diagnostic context, inspect problems quickly, and share a focused report with a person or an AI agent. Operational integrations such as outbound webhooks are also in scope. An MCP adapter is a later, optional interface for agents to query CodeKit diagnostic data; it builds on stable diagnostics and export contracts rather than being a core dependency.

The ecosystem will include CodeKit-maintained optional adapter packages with minimal setup, including persistent storage. Package boundaries and supported backend/platform scope are defined by the [system architecture](specs/system-architecture.md#ready-to-use-storage-packages).

The approved package map and workspace layout are owned by the [system architecture](specs/system-architecture.md#package-boundaries-and-workspace-layout). Public default exports remain open; selected backend and platform scope are owned by that architecture.

## Candidate milestones

| Order | Milestone | Status | Exit condition |
| :--- | :--- | :--- | :--- |
| 1 | Define package boundaries and diagnostic event contracts | Proposed | Package responsibilities, dependency direction, and a platform-neutral event contract are documented. |
| 2 | Establish the Dart diagnostics foundation | Core implemented | A Dart-level API records and correlates logs, errors, stack traces, and diagnostic context without requiring Flutter or a specific storage adapter. |
| 3 | Enable inspection and user-controlled export | Proposed | Developers can inspect and filter records, use HTTP/JSON details, manage Trace sessions, and copy/export records or HTTP fragments through the agreed disclosure workflow. |
| 4 | Add development and operational integrations | In progress | Optional integrations such as native Drift persistence, Flutter error hooks, Dio and package:http capture, colored terminal output, and outbound webhooks can be adopted independently. The `codekit_dio`, `codekit_http`, `codekit_drift_diagnostic_store` and `codekit_webhook` packages are implemented; Flutter error hooks, CodeKit console integration and remaining integrations are pending. |
| 5 | Add an optional MCP adapter | Proposed | An MCP server exposes narrowly scoped access to stable diagnostic data for compatible agents, without becoming a dependency of the core or application runtime. |
| 6 | Prepare the umbrella package and publishing flow | Proposed | The supported package set, public exports, compatibility policy, and release process are documented. |

These milestones describe a candidate sequence, not committed delivery dates or finalized package names. Update this roadmap when direction or milestone status changes; keep implementation contracts in their designated specifications.

## Open decisions

- Existing package migration and compatibility details, including colored console Web support and whether `type_caster` has a concrete integration use case.
- Which components the `codekit` umbrella package includes by default while keeping platform-specific integrations optional.
- The MCP adapter's data source and local transport, after diagnostic export and storage contracts stabilize.
