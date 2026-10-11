# Documentation Index & Placement Matrix

| Topic / Scope | Authoritative SSOT | Responsibility |
| :--- | :--- | :--- |
| **Tasks & Execution** | Defined in [`.agents/task-tracker.md`](../.agents/task-tracker.md) | Decomposed task units and progress tracking |
| **Testing Governance** | Defined in [`.agents/harness-anchor.md`](../.agents/harness-anchor.md) | Test harness infrastructure and invariant testing |
| **CodeKit Roadmap** | [`roadmap.md`](roadmap.md) | Product direction, milestones, and roadmap status |
| **Dependency Versions** | [`techstack.md`](techstack.md) | Proposed direct dependency versions and conditional candidates; version tables only |
| **Dependency & Engineering Scout** | [`research/dependencies-and-engineering-scout.md`](research/dependencies-and-engineering-scout.md) | Compatibility evidence and recommendations for selective reuse of Memozen standards; not normative design contracts |
| **System Architecture** | [`specs/system-architecture.md`](specs/system-architecture.md) | System boundaries, dependency direction, and diagnostic flow |
| **Public API** | [`specs/public-api.md`](specs/public-api.md) | Entrypoint naming, setup, receipts and storage interface; proposals are identified separately |
| **Record Schema** | [`specs/record-schema.md`](specs/record-schema.md) | Shared models, supported values, body representation, and serialization boundaries |
| **Diagnostic Data Lifecycle** | [`specs/diagnostic-data-lifecycle.md`](specs/diagnostic-data-lifecycle.md) | Acceptance, persistence queue, retention, Trace sessions, export, disposal, and sink behavior |
| **HTTP Client Adapters** | [`specs/http-client-adapters.md`](specs/http-client-adapters.md) | Independently installable Dio/http capture, extensions and remaining verification |
| **Diagnostic Sinks** | [`specs/diagnostic-sinks.md`](specs/diagnostic-sinks.md) | HTTP/LOG routing, transport, circuit guards, content selection and service-specific options |
| **Diagnostics UI** | [`specs/diagnostics-ui.md`](specs/diagnostics-ui.md) | Records inspection, Trace session management, export actions, and search history |
| **Package Publishing** | [`runbooks/pub-workspace-publishing.md`](runbooks/pub-workspace-publishing.md) | Release preflight and per-package publishing from a Pub workspace |
| **Documentation Governance** | `doc/` | Governed via `/ssot` |

Each durable specification has one authoritative owner. Other documents should link to that owner instead of copying its rules or contracts.
