---
title: CodeKit Public API
status: active
created: 2026-10-11
updated: 2026-10-16
---

# CodeKit Public API

## Authority

This document owns approved entrypoint names, setup composition, receipts, query API and storage interface direction. [Architecture](system-architecture.md) owns package boundaries, [record schema](record-schema.md) owns models/codec, and [lifecycle](diagnostic-data-lifecycle.md) owns recording, retention, disposal and export behavior.

## Entrypoint and setup

`CodeKitDiagnostics` is the public entrypoint. Applications create an explicit instance and pass it as `diagnostics` to adapters and UI; there is no core default singleton.

The optional `codekit` umbrella re-exports `codekit_core` and `codekit_console` only. It adds no singleton or alternative recorder API. Flutter, client, Drift and webhook integrations remain separately installed.

Core exposes `DiagnosticStore` and `MemoryDiagnosticStore`. The optional `codekit_drift_diagnostic_store` package exposes `DriftDiagnosticStore`.

The top-level `createDriftDiagnostics()` factory belongs to the Drift package, not to the store class. It opens the store, composes diagnostics and releases opened resources if composition fails. The store class's `open()` creates only a store. Core never imports Drift.

```dart
// Memory default.
final diagnostics = CodeKitDiagnostics();

// Optional native persistent setup.
final diagnostics = await createDriftDiagnostics(
  databasePath: '/application/chosen/path/codekit.sqlite',
  retention: RetentionPolicy(maxRecords: 1000),
);

// Developer chooses when to stop and release resources.
await diagnostics.dispose();
```

Diagnostics always owns its store, including one supplied through `CodeKitDiagnostics(store: store)`. There is no `ownsStore` flag. The developer decides when to initialize/dispose according to their application lifecycle. Resource shutdown and pending-write semantics are owned by [disposal](diagnostic-data-lifecycle.md#record-deletion-and-disposal).

## Unified input and constructor examples

Optional metadata/configuration is nullable where absence is meaningful. Required LOG message and HTTP method/URI/start time/adapter ID stay required; stored ID/time/mode/payload are not nullable. LOG level may be omitted at construction and defaults to info. Missing response/duration/error are not synthesized. Optional context/tags/source remain absent when not supplied; tags are detached immutable metadata.

The constructor centralizes `store`, `retention`, `redactionPolicy` and `sinks`. Omitted store selects memory; optional sink lists may be null (no sinks). Diagnostics owns stores and sink lifecycles, but does not own developer-injected transport clients. Policy/default semantics belong to the [sink spec](diagnostic-sinks.md).

```dart
// Illustrative API: declarations and some setup values are omitted.
final diagnostics = CodeKitDiagnostics(
  store: store,
  retention: RetentionPolicy(maxRecords: 1000),
  redactionPolicy: RedactionPolicy(),
  sinks: [
    DiscordSink(
      webhookUrl: discordWebhook,
      // Optional; omit to use the sink-owned package:http client.
      logDispatchPolicy: LogDispatchPolicy(
        includeTags: {'paymentSucceeded', 'appCrash'},
      ),
      httpDispatchPolicy: HttpDispatchPolicy(
        statusGroups: {HttpStatusGroup.serverError},
      ),
    ),
  ],
);

diagnostics.log(LogInput(message: 'App started'));

diagnostics.log(LogInput(
  message: 'Payment completed',
  tags: {'paymentSucceeded'},
  context: {'orderId': '123'},
));

diagnostics.log(LogInput(
  message: 'Unhandled app error',
  level: LogLevel.error,
  tags: {'appCrash'},
  error: error,
  stackTrace: stackTrace,
));

// Adapter allocates ID before sending; submits once after response/error.
final requestId = diagnostics.createRecordId();
// ... request lifecycle, with requestId retained in internal metadata ...
final receipt = diagnostics.log(HttpInput(
  recordId: requestId,
  requestStartedAt: startedAt,
  duration: elapsed,
  method: 'POST',
  uri: requestUri,
  requestHeaders: requestHeaders,
  requestBody: requestBody,
  response: responseSnapshot,
  error: httpError,
));

// Optional persistence confirmation; ordinary callers ignore it.
final confirmation = await receipt.persistedOrNull();
final page = await diagnostics.query(RecordQuery(limit: 100));
await diagnostics.dispose();
```

`LogInput.error` and `stackTrace` accept diagnostic inputs that are normalized into record data. `HttpInput` carries no client-library objects. Input model details belong to [record schema](record-schema.md#input-types-and-optional-fields). Snippets with omitted imports and application values illustrate the API; they are not standalone programs.

## HTTP client setup

Both client adapters expose `withDiagnostics()` from their independently installable packages. Their mutation/wrapping, deduplication and capture contracts are owned by [HTTP client adapters](http-client-adapters.md).

```dart
// Import the relevant adapter and client library in consumer code.
final dio = Dio().withDiagnostics(diagnostics);
final client = http.Client().withDiagnostics(diagnostics);
```

## Recording receipt

`log(DiagnosticInput input)` is the single LOG/HTTP entrypoint and returns `RecordReceipt` synchronously. `LogInput` and `HttpInput` identify the type without a redundant caller-supplied type flag. HTTP adapters use `createRecordId()` before dispatch; the same ID is submitted with the completed snapshot. Typical callers ignore the receipt.

| Member | Contract |
| --- | --- |
| `accepted` | Snapshot validation/policy and acceptance succeeded; not a durability guarantee. |
| `recordId` | Present for accepted records, null for dropped records. |
| `dropReason` | Present for dropped records: invalid input, redaction failure, queue full, disposed diagnostics, or storage acceptance failure where applicable. No byte-size rejection exists. |
| `persistedOrNull()` | Safe optional await: returns persistence confirmation with record ID on successful persistent write/retention; null for no persistence or unsuccessful persistence. Storage failures do not escape as unhandled errors. |

Persistence timing and Trace capture behavior are defined by the [record lifecycle](diagnostic-data-lifecycle.md#acceptance-persistence-and-query-visibility).

## Retention configuration

`RetentionPolicy.maxRecords` is configured only at initialization. Its behavior is owned by [retention](diagnostic-data-lifecycle.md#retention-and-eviction). The public field documentation must state:

```dart
/// Maximum number of retained records.
///
/// `null` means unlimited (default).
/// Values below 100 are normalized to 100.
/// When exceeded, removes the oldest records in batches of at least
/// 5% of this limit, rounded up, or more if needed to meet the limit.
final int? maxRecords;
```

## Storage interface

Every backend implements the public `DiagnosticStore` interface rather than extending a mandatory base class. The approved contract direction is:

```dart
abstract interface class DiagnosticStore {
  StorageKind get kind;

  FutureOr<void> appendAndRetain(
    DiagnosticRecord record, {
    required RetentionPolicy retention,
  });

  Future<DiagnosticRecord?> getById(String id);
  Future<List<DiagnosticRecord>> getByIds(List<String> ids);
  Future<RecordPage> query(RecordQuery query);
  Future<int> deleteByIds(List<String> ids);
  Future<int> clearRecords();

  Future<void> saveTraceSession(TraceSession session);
  Future<List<TraceSession>> listTraceSessions();
  Future<bool> deleteTraceSession(String id);
  Future<void> close();
}

enum StorageKind { memory, persistent }
```

Memory implementations complete `appendAndRetain` synchronously; persistent implementations return a Future and run behind the core queue. The queue belongs to core, not the adapter. The adapter owns backend schema, resource opening, migrations and actual storage operations. A store instance has one diagnostics writer in MVP.

Storage failures must remain distinguishable from missing IDs or empty queries. Adapters report I/O failures to core; core handles persistence receipts and exposes operation failures appropriately. SQL and transactions are not required by the public interface. Non-transactional implementations may partially change storage before reporting failure; failure is not proof that nothing was written. Backend-specific schema, transaction, migration, and platform behavior are owned by [Ready-to-use storage packages](system-architecture.md#ready-to-use-storage-packages).

Batch lookup preserves requested ID order and deduplicates IDs; stores reject duplicate record IDs. Awaited storage operations propagate errors; export converts them into a failed ExportResult.

## Query pagination

Query uses `RecordQuery` and returns `RecordPage` with `records` and nullable `nextCursor`. Default page size is 100. List order is newest to oldest by internal store order. Cursor is opaque; callers do not construct it. It is scoped to the store and query (excluding page size) and resumes strictly below the last returned internal order. Search/filter changes or reload restart from the first page. New insertions must not duplicate records across ongoing pages; this does not promise a database snapshot across pages.

Query filter groups combine with AND; members within a group combine with OR. Null or empty filter sets mean unrestricted. Time bounds are inclusive over `recordedAt`. HTTP status filters use `HttpStatusGroup`; LOG and response-less HTTP records are in the unknown group. HTTP method filters use case-insensitive matching against uppercase method strings in `methods`; LOG records do not match when method filters are specified. Duration thresholds default to 200/1000/3000 ms and can be supplied through `RecordQuery.thresholds`; missing duration is unknown.

Main-screen search matches LOG message/source/error message and HTTP method/URI/source/error message; it does not scan headers, bodies or context. Text search is case-insensitive substring matching; regex input is validated and invalid syntax reported rather than treated as text. Persistent Drift queries scan internal order in bounded chunks and apply the complete `RecordQuery` predicate in Dart, so regex pagination does not rely on SQLite regex support. Filtered rows between pages may be scanned again, but matching records must not be skipped. Query pagination is a list behavior, not an export count limit. Search/filter selections resolve to IDs for the shared export path.

## Additional public operations

The curated core library entrypoint exposes `log`, `createRecordId`, `shouldCaptureHttp`, get/query/delete/clear, manual and picker Trace operations, `isTraceActive`, `activeTraceRecordCount`, text exports, HTTP fragment formatting and dispose. `activeTraceRecordCount` is zero while no manual Trace capture is active and otherwise reports IDs accepted into that active capture; it does not promise that every ID remains queryable. Runtime changes use `recordMode`, `redactionPolicy` and `captureExcludeUriPatterns` setters; configuration does not require a separate settings/updateSettings abstraction.

`captureExcludeUriPatterns` is nullable (no exclusions). Adapters can check `shouldCaptureHttp(uri)` before collection; the log entrypoint also checks it before normalization and every output branch. Excluded HTTP inputs return an excluded receipt without emitting repeated warnings.

Platform clipboard/share and automatic sinks are integration responsibilities, not functions in core.
