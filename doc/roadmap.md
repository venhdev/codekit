---
title: CodeKit Roadmap
description: Approved direction and milestone status for the CodeKit package ecosystem.
status: active
created: 2026-10-10
updated: 2026-10-11
---

# CodeKit Roadmap

This document is the single source of truth for CodeKit's product direction and milestone status. Detailed package contracts and architecture belong in their own specifications and should be linked here when established. See the [documentation index](README.md) for documentation ownership.

## Approved direction

CodeKit is a Dart developer-tool ecosystem with a general-purpose Dart diagnostics core that can be adopted from the start of a project and remain useful during operation. The `codekit` package is intended to provide a convenient umbrella over independently usable packages. Flutter-specific capabilities remain optional integrations; the core must not require Flutter.

The product should help developers capture useful diagnostic context, inspect problems quickly, and share a focused report with a person or an AI agent. Operational integrations such as outbound webhooks are also in scope. An MCP adapter is a later, optional interface for agents to query CodeKit diagnostic data; it builds on stable diagnostics and export contracts rather than being a core dependency.

The ecosystem will include CodeKit-maintained optional adapter packages with minimal setup, including persistent storage. Package boundaries and supported backend/platform scope are defined by the [system architecture](specs/system-architecture.md#ready-to-use-storage-packages).

The approved package map and workspace layout are owned by the [system architecture](specs/system-architecture.md#package-boundaries-and-workspace-layout). The `codekit` umbrella re-exports core and console; selected backend and platform scope are owned by that architecture.

## Milestones

| Order | Milestone | Status | Exit condition |
| :--- | :--- | :--- | :--- |
| 1 | Define package boundaries and diagnostic event contracts | Implemented | Package responsibilities, dependency direction, and a platform-neutral event contract are documented. |
| 2 | Establish the Dart diagnostics foundation | Core implemented | A Dart-level API records and correlates logs, errors, stack traces, and diagnostic context without requiring Flutter or a specific storage adapter. |
| 3 | Enable inspection and user-controlled export | Implemented; mobile OS share QA pending | Developers can inspect/filter records, inspect HTTP/JSON, manage Trace sessions and copy/export records or HTTP fragments. VM and Chrome widget tests pass; a Chrome runtime test downloaded and checked a `.txt` record export. Native file creation/plugin invocation is covered by a mock-platform test; an Android/iOS share sheet still needs device QA. |
| 4 | Add development and operational integrations | Implemented | Native Drift persistence, Flutter error hooks, Dio and package:http capture, colored terminal output and outbound webhooks are independent packages with passing suites. |
| 5 | Add an optional MCP adapter | Deferred beyond MVP | An MCP server may expose narrowly scoped access to stable diagnostic data for compatible agents without becoming a core or runtime dependency. |
| 6 | Prepare the umbrella package and publishing flow | Prepared; unpublished | The `codekit` umbrella, compatibility policy, package metadata and per-package release runbook exist. All ten packages pass `dart pub publish --dry-run` with zero warnings on a clean tree. `publish_to: none` remains until a separately approved release. |

These milestones carry no publication dates. Update this roadmap when direction or milestone status changes; keep implementation contracts in their designated specifications.

## Open decisions

- Whether `type_caster` has a concrete integration use case. It is not required for diagnostics MVP.
- The MCP adapter's data source and local transport, after diagnostic export and storage contracts stabilize.
