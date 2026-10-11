---
title: CodeKit Public API
status: draft
created: 2026-10-11
updated: 2026-10-11
---

# CodeKit Public API

## Authority

This document owns approved entrypoint names, setup composition, receipts and storage interface direction. [Architecture](system-architecture.md) owns package boundaries, [record schema](record-schema.md) owns models/codec, and [lifecycle](diagnostic-data-lifecycle.md) owns recording, retention, disposal and export behavior. Signatures illustrate the approved surface; unresolved signatures are listed separately.

## Entrypoint and setup

`CodeKitDiagnostics` is the public entrypoint. The older proposed name `CodeKitRecorder` is superseded. Applications create an explicit instance and pass it as `diagnostics` to adapters and UI; there is no core default singleton.

Core exposes `DiagnosticStore` and `MemoryDiagnosticStore`. The optional `codekit_drift_diagnostic_store` package exposes `DriftDiagnosticStore`, replacing the proposed `CodeKitDriftStore` name. Older proposed package names `codekit_storage_drift` and `codekit_drift_storage` are superseded.

The top-level `createDriftDiagnostics()` factory belongs to the Drift package, not to the store class. It opens the store, composes diagnostics and releases opened resources if composition fails. The store class's `open()` creates only a store. Core never imports Drift.

```dart
// Memory default.
final diagnostics = CodeKitDiagnostics();

// Optional native persistent setup.
final diagnostics = await createDriftDiagnostics(
  databasePath: '...',
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
    ConsoleSink(),
    DiscordSink(
      webhookUrl: discordWebhook,
      transport: appTransport,
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

`LogInput.error` and stackTrace accept diagnostic inputs that are normalized into record data. `HttpInput` carries no client-library objects. Input model details belong to [record schema](record-schema.md#input-types-and-optional-fields). These examples describe the design and are not claimed to compile before production packages exist.

## HTTP client setup

Both client adapters expose `withDiagnostics()` from their independently installable packages. Their mutation/wrapping, deduplication and capture contracts are owned by [HTTP client adapters](http-client-adapters.md).

```dart
// Import the relevant adapter and client library in consumer code.
final dio = Dio().withDiagnostics(diagnostics);
final client = http.Client().withDiagnostics(diagnostics);
```

## Recording receipt

`log(DiagnosticInput input)` is the single LOG/HTTP entrypoint and returns `RecordReceipt` synchronously. `LogInput` and `HttpInput` identify the type without a redundant caller-supplied type flag. The earlier separate `recordHttp()` proposal is superseded. HTTP adapters use `createRecordId()` before dispatch; the same ID is submitted with the completed snapshot. Typical callers ignore the receipt.

| Member | Contract |
| --- | --- |
| `accepted` | Snapshot validation/policy and acceptance succeeded; not a durability guarantee. |
| `recordId` | Present for accepted records, null for dropped records. |
| `dropReason` | Present for dropped records: invalid input, redaction failure, queue full, disposed diagnostics, or storage acceptance failure where applicable. No byte-size rejection exists. |
| `persistedOrNull()` | Safe optional await: returns persistence confirmation with record ID on successful persistent write/retention; null for no persistence or unsuccessful persistence. Storage failures do not escape as unhandled errors. |

Receipt/result types for the core slice are implemented in codekit_core and summarized in the implementation baseline below. For memory, writing/retention completes before an accepted receipt returns. Persistent acceptance enqueues without waiting for disk. Only accepted IDs enter manual Trace capture.

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

Storage failures must remain distinguishable from missing IDs or empty queries. Adapters report I/O failures to core; core handles persistence receipts and exposes operation failures appropriately. SQL and transactions are not required by the public interface. Non-transactional implementations may partially change storage before reporting failure; failure is not proof that nothing was written. Drift should use a transaction for insertion and count eviction.

Batch lookup preserves requested ID order and deduplicates IDs; stores reject duplicate record IDs. Awaited storage operations propagate errors; export converts them into a failed ExportResult. Integration factory argument coverage remains adapter work.

## Query pagination

Query uses `RecordQuery` and returns `RecordPage` with `records` and nullable `nextCursor`. Default page size is 100. List order is newest to oldest by internal store order. Cursor is opaque; callers do not construct it. Search/filter changes or reload restart from the first page. New insertions must not duplicate records across ongoing pages; this does not promise a database snapshot across pages.

Main-screen search matches LOG message/source/error message and HTTP method/URI/source/error message; it does not scan headers, bodies or context. Text search is case-insensitive substring matching; regex input is validated and invalid syntax reported rather than treated as text. Query pagination is a list behavior, not an export count limit. Search/filter selections resolve to IDs for the shared export path. Exact filter model fields and cursor validation remain implementation design work.

## Implemented public surface

Core implements `log`, `createRecordId`, `shouldCaptureHttp`, get/query/delete/clear, manual and picker Trace operations, text exports, HTTP fragment formatting and dispose. Runtime changes use `recordMode`, `redactionPolicy` and `captureExcludeUriPatterns` setters; a separate DiagnosticsSettings/updateSettings abstraction is not needed for this slice. All these methods are available through the curated core library entrypoint.

`captureExcludeUriPatterns` is nullable (no exclusions). Adapters can check `shouldCaptureHttp(uri)` before collection; the log entrypoint also checks it before normalization and every output branch. Excluded HTTP inputs return an excluded receipt without emitting repeated warnings.

RecordReceipt, PersistenceConfirmation, ExportResult, DiagnosticWarning and RecordDecodeResult are implemented public results. ExportStatus distinguishes success/empty/failed; failed exports never include partial text. Platform clipboard/share and automatic sinks are integration responsibilities, not functions in core.

## Core implementation baseline

The first workspace member is codekit_core only. Its initial SDK minimum is Dart 3.13, matching the verified toolchain; lowering it requires later compatibility checks. It has no runtime package dependencies. Package publishing is disabled until release readiness.

Public log levels are trace/debug/info/warning/error/fatal. Record results distinguish excluded, invalidInput, redactionFailed, queueFull, disposed and storageFailed; persistence failures resolve to null. Explicit query/Trace/export failures report errors to their awaited callers, not successful empty results. Logging/storage/sink failures cannot escape the producer path. Warning callback failures are swallowed on the separate reporting path.

Query defaults: groups combine AND, members of a group OR; null/empty query filter sets are unrestricted. Time bounds are inclusive over recordedAt. HTTP groups use HttpStatusGroup; LOG and response-less HTTP use unknown. Duration thresholds default to 200/1000/3000 ms and may be supplied through RecordQuery.thresholds; absent duration is unknown. Cursor is opaque, scoped to the store and query (excluding page size), and resumes strictly below last returned internal order. No snapshot isolation is promised across pages.

Memory order is process-local, IDs are opaque random strings with a local sequence for within-instance uniqueness; persistent stores own stable order across restart. getByIds preserves requested ID order and deduplicates, skipping missing records. Duplicate record IDs are rejected by stores rather than overwritten. Export preserves selected ID order, returns readable text, and reports failure without returning partial output. Missing IDs are skipped. Query results and snapshots are deeply immutable.

Body media metadata uses MediaFileMetadata (fileName/contentType/sizeBytes/path, all nullable); the core never opens paths or reads file bytes. sizeBytes is optional file metadata, not retained-storage byte accounting. All captured body variants are explicit (text/json/media), including JSON null. Codec v1 uses payload type log/http, capture-state and representation labels, UTC timestamps and durationMicros. decode returns a safe success/invalid/unsupportedVersion result.

Runtime recordMode and redactionPolicy setters affect subsequent operations only. Retention is fixed at construction. Persistent queue capacity defaults to 1000 and excludes an active write. Disposal resolves pending/active receipts safely without waiting for a drain, stops sink submissions and closes owned stores/sinks. Running adapter work may finish while close executes according to that adapter; core does not claim rollback or later delivery.

These concrete defaults complete the core slice; native database openers, HTTP wrappers, remote transports, platform UI/share and visual defaults are outside this implementation. Their acceptance checks require their actual target environments rather than mock-only feasibility claims.

## Verification boundary

The first core implementation is verified with native Dart contract tests and an executable example. A controlled store in tests checks queue ordering and safe receipt completion, not real disk durability. A Dart-to-JavaScript compile checks dependency compatibility, not browser runtime behavior. Core has no Flutter, dart:io, Dio, HTTP or storage-engine runtime imports. Adapter/platform integration acceptance checks remain pending until those implementations and target environments exist.
