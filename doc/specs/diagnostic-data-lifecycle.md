---
title: CodeKit Diagnostic Data Lifecycle
description: Event recording, retention, Trace session, export, and sink behavior for CodeKit.
status: active
created: 2026-10-10
updated: 2026-10-11
---

# CodeKit Diagnostic Data Lifecycle

## Authority and scope

This document owns the lifecycle and flow of diagnostic events, including retention, Trace sessions, and export. The [system architecture](system-architecture.md) owns component boundaries and dependency direction. The [diagnostic sinks](diagnostic-sinks.md) specification owns dispatch behavior and delivery guarantees. The [roadmap](../roadmap.md) owns product direction and milestones.

This is a behavioral contract, not a storage-engine or serialization implementation design. Storage setup and count retention are settled below; persistent queue count and timeout behavior are specified below.

## Event flow

Diagnostic producers submit `LogInput` or completed `HttpInput` through the single `CodeKitDiagnostics.log()` entrypoint. LOG input covers messages, errors, stack traces, tags, breadcrumbs and context. The recorder makes accepted records available to inspection, Trace session selection, and export. After validation and immutable snapshot preparation, diagnostics fans out into separate store and sink branches. Recording mode transforms the store copy. Sink processing follows the [diagnostic sinks contract](diagnostic-sinks.md).

The [record schema](record-schema.md) owns shared models, supported values, body representation and serialization. Core context is supplied explicitly on each input; there is no ambient/Zone propagation feature in MVP. Concrete core signatures are defined by the public API and implementation. Each stored record retains the record mode used when it was accepted.

## Storage and record modes

Storage mode and record mode are independent:

| Concern | Choice | Behavior |
| --- | --- | --- |
| Storage mode | Memory | Records are available during the current process and are lost when it ends. This is the default backend. |
| Storage mode | Persistent | An explicitly configured adapter stores records across process restarts, subject to configured retention. |
| Record mode | Redact before recording | Apply configured redaction before the recorder stores the record. Redacted values cannot be recovered by a later export choice. |
| Record mode | Store raw | Store record data as captured without applying the redaction policy. This is the default record mode. |

The former third record mode is removed. A project chooses the export representation separately for each export.

Changing record mode affects newly accepted records only. Existing records retain the representation captured when they were recorded.

Persistent recording is intended to make retained records available after a process restart. It does not promise survival through every device, filesystem, or power failure. Recording normally does not wait for persistent storage. The recorder returns a receipt with an optional safe-to-await persistence result. CodeKit handles persistence failures and reports warnings through a separate path, never by writing a warning into the same failing recorder or store.

## Acceptance, persistence and query visibility

Logging does not wait for disk persistence. After snapshot validation and any required policy processing, an accepted record receives a receipt immediately. Memory recording makes accepted records available to query/export immediately, subject to retention. Persistent recording uses a count-bounded, process-local write queue, defaulting to 1,000 pending records (excluding the active write), configurable at initialization, and makes a record queryable only after its store write and retention operation succeed. Pending payloads are not merged into query results and are not a second retained memory store.

Persistent writes are processed in acceptance order. Queue overflow rejects the new record with a dropped-record indication instead of blocking the producer. Write failure completes the persistence result safely and warns through the separate failure path; there is no automatic retry or implicit memory fallback. Only explicitly accepted records contribute IDs to manual Trace capture. The optional `persistedOrNull` operation lets callers await confirmation safely; ordinary logging ignores that result. Receipt fields are specified by the [public API](public-api.md); the pending-count limit is specified above. Core does not impose a write timeout or start another write while an earlier one is still running; adapters must complete or report failure. A stalled adapter can fill the queue.

A successful write means the adapter's declared storage operation succeeded; it is not a guarantee against every device failure. Pending records can be lost if the process ends. Network sink behavior is specified by [diagnostic sinks](diagnostic-sinks.md#delivery-guards-and-failures).

## Record deletion and disposal

Delete and Clear affect records currently present in the active store. Clear does not cancel pending writes or create an acceptance barrier; earlier pending writes may appear afterward. Selected deletion acts on the selected stored IDs. No record removal cascades into Trace session deletion.

MVP disposal stops accepting new records and discards queued writes without a flush/drain wait. There is no public flush/drain API in the initial scope. Discarded-write receipts complete safely without success; outstanding receipts must not remain unresolved. An already-running write finishes or is cancelled according to the adapter's resource-close behavior, with its result resolved safely. Disposal must not claim that all accepted records were persisted. `CodeKitDiagnostics` owns its store, including injected stores, and closes it on disposal. A store instance belongs to one diagnostics instance. Repeated disposal is safe; reopening requires fresh instances. The developer chooses when to initialize and dispose; CodeKit does not attach these operations to app lifecycle events.

## Redaction policy

Redaction policy is a separate developer-configurable contract shared by recording and export. Its initial scope covers common debugging and sharing cases, not comprehensive sensitive-data discovery. Selecting Redacted means applying configured rules; it does not certify that all sensitive information has been removed.

### Presets and supported rules

`RedactionPolicy` exposes constructor parameters `authorization`, `cookie`, and `setCookie`, all enabled by default. These presets redact matching values in both request and response headers. Developers can disable individual presets and add built-in rules through the policy's rules list. Additional default presets are not selected.

| Rule naming direction | Supported selection | Behavior |
| --- | --- | --- |
| `HeaderRedactionRule` | Exact header names, matched case-insensitively | Preserve names and replace matching values; target request headers, response headers, or both. |
| `QueryRedactionRule` | Exact query parameter names | Replace values for matching parameters, including repeated occurrences. |
| `BodyFieldRedactionRule` | A list of simple dotted object paths, such as `email`, `password`, and `user.email` | Traverse the specified object keys and replace the selected value; preserve keys and surrounding structure. |
| `TextRedactionRule` | Developer-configured regex | Replace matches within the supported text scope. |

These names establish a naming direction; exact constructor signatures remain implementation design work. `RedactionRule` is the common built-in rule contract, not an initial extension point for arbitrary user implementations. Custom callbacks are excluded from the initial API.

Body paths support object traversal only. Wildcards (`*` or `.*`), array traversal/index selection, typed paths, `RedactionPath`, `RedactionSegment`, and a `.paths` constructor are excluded. Literal keys containing dots or wildcard characters are not addressable by this syntax. Unsupported or malformed path syntax is rejected during configuration. A missing field is a no-op. Array contents are not traversed; selecting an entire field whose value is an array replaces that value as a whole.

Body representations and transient JSON parsing follow the [record schema](record-schema.md#body-representation). Field rules do not interpret plain text as an object. Field rules that cannot inspect a body leave it unchanged; this is not proof of successful masking.

Preset rules run before additional rules, which run in declaration order. There is no custom callback stage. The replacement marker is `[REDACTED]`. Text rules transform message/error/stack trace, header/query values, body text and recursively string values in structured body/context/media metadata; they do not change keys, IDs, timestamps, method, source or tags. The marker is protected on repeated application. A field rule with no match or non-JSON text body is a no-op, not a failure.

### Application and failures

| Operation | Policy application |
| --- | --- |
| Accept a record in Redact before recording mode | Apply the currently configured policy before storing it. |
| Accept a record in Store raw mode | Do not apply redaction. |
| Copy/export as Redacted | Always apply the currently configured policy to an export copy, including records previously redacted before storage. |
| Copy/export As stored | Do not apply additional redaction. |

Each recording or export operation uses one consistent policy configuration captured at its start. Configuration changes affect subsequent operations and never rewrite existing records. Values removed by an earlier policy cannot be restored by changing policy or choosing As stored.

Header rules preserve header names and replace matching values. Header-name matching is case-insensitive; rules must specify request headers, response headers, or both. There is no separate always-redact header list overriding record mode. Endpoint URI regex exclusion remains separate from redaction because it prevents capture altogether; the endpoint exclusion list is empty by default.

No policy revision or redacted-state shortcut is used to skip processing. Redaction must tolerate previously redacted data and preserve structure outside the selected values. Package-generated replacement markers are protected from repeated masking. Arbitrary text regex is supported without an idempotence guarantee: applying the current policy again may mask additional content, but must not mutate stored records.

If policy processing fails during Redact before recording, reject that record, expose a dropped-record indication, and warn through a separate diagnostic path. Do not store a minimal substitute or fall back to raw. If policy processing fails during Redacted copy/export, cancel the operation and report failure without emitting partial output or falling back to As stored. Core export returns ExportResult.failed with no partial output; recording returns a dropped receipt.

## Retention and eviction

Retention is count-only and configured at initialization through `RetentionPolicy.maxRecords`. The default `null` means unlimited. Every non-null value below 100, including zero or negative values, is normalized to 100 without throwing. Runtime retention changes are excluded from MVP.

When a write makes count exceed the limit, remove the oldest records by store order. The eviction batch is `ceil(maxRecords * 0.05)`; delete `max(currentCount - maxRecords, batchSize)` records so a larger overage is also corrected. For a limit of 100, adding record 101 removes five oldest records, leaving 96. This is one batch operation, not one deletion per subsequent insert.

MVP has no age retention, byte accounting, total-size limit, oversized-record rejection or background expiration timer. Unlimited count does not bound RAM or disk consumption. Stored records remain queryable until explicit deletion or count eviction.

Eviction removes records only. Trace sessions retain their original ID lists; there is no reverse reference tracking, session completeness check or cascade deletion. Missing IDs are handled only when export queries the session.

## Trace sessions

A Trace session is a manageable selection of diagnostic event IDs, not a separate event stream and not a copy of event payloads. It can be created in either of two ways:

1. A user starts and stops a capture session through `codekit_ui` or a project-specific UI using the public diagnostics API. The capture collects IDs of records accepted in that interval, including pending persistent writes. While active, `activeTraceRecordCount` reports the number of accepted IDs and is zero otherwise. Stop saves the collected IDs immediately without waiting for those writes. At most one manual capture may be active per recorder.
2. A user selects start and end times A–B in a picker. The resulting session references the IDs returned by querying the active store in the inclusive interval `[A, B]`. Pending persistent writes are not included.

`codekit_ui` provides a list for managing and quickly exporting sessions. Custom UI can invoke the same session operations without depending on `codekit_ui`. Trace sessions contain record IDs, not duplicate payloads. Sessions remain until explicitly deleted by the user within the lifetime of their session storage; record deletion, eviction and write failure do not remove them. Memory sessions are lost when the process ends; an optional persistent adapter can retain sessions across restarts independently of referenced record retention.

When a user exports a session, query its saved IDs and skip IDs that currently resolve to no record, including unfinished or failed writes and deleted/evicted records. Do not wait for pending writes, retry missing IDs, or rewrite the session ID list. Export the available records. If none resolve, do not produce an empty export; the UI offers explicit session deletion without deleting automatically. A storage query failure is not equivalent to a missing ID.

Empty sessions are not saved; stop/picker creation returns null when no IDs are selected. Session name is optional; UI falls back to its time interval. Repeated Start while active and Stop while inactive report StateError to the explicit caller.

## Export and data disclosure

Export resolves a selected ID list to records available in the active store. Search/filter and select-all produce that ID selection before export; no separate export scheduler or database snapshot is required. Trace export resolves saved IDs with the [missing-ID behavior](#trace-sessions). The user chooses one of two representations for each export:

- **Redacted:** create an export copy using the [current redaction policy](#redaction-policy). Stored records remain unchanged.
- **As stored:** export each record exactly as it is stored. Data redacted before recording cannot be restored.

Export does not mutate stored records or saved reports. The same disclosure choices apply to complete records and HTTP record fragments such as bodies, headers and cURL. The UI owns the selection and confirmation workflow; the core export contract owns representation and redaction.

The default record mode is Store raw; users choose Redacted or As stored at export. Core exports readable indented record JSON text and exposes body/header/cURL formatters; clipboard/share are UI responsibilities. The initial UI contract adds no record-count or byte-size limit for selected or matching records.

HTTP adapters create one completed HTTP record when the request lifecycle reaches the adapter's declared completion boundary. The record carries a local correlation ID, `requestStartedAt`, measured duration, and `recordedAt` assigned when the recorder accepts it. The adapter allocates one ID before sending the request and retains it in internal request metadata; the completed record uses that same ID. Allocating an ID does not accept a record or add it to Trace capture. The correlation ID is internal metadata and is not added to the network request as a header. In MVP, streamed responses complete capture at response headers, mark body unsupported, and measure duration to headers; adapters do not wrap, buffer or consume the stream. Normal HTTP completes when its response or error snapshot is available. HTTP body capture is toggleable. Media/file bytes are not captured; a separate option selects metadata-only capture or inclusion of the raw local path.

cURL is generated on demand from the structured HTTP data after the requested disclosure transformation, rather than stored as an independent canonical payload. As stored cURL reflects available stored fields; it cannot recover redacted values or uncaptured body/file bytes. Incomplete representations are identified as insufficient for replay. Generating or copying cURL does not send a request.

## Later MCP integration

An optional MCP adapter may expose narrowly scoped access to stable diagnostic and export capabilities. It is deferred until event, retention, and export contracts are stable. MCP does not change the event source of truth or retention behavior.
