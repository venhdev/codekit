---
title: CodeKit Record Schema
description: Platform-neutral diagnostic models, body representation, and serialization boundaries.
status: active
created: 2026-10-11
updated: 2026-10-16
---

# CodeKit Record Schema

## Authority and scope

This document owns the shared diagnostic model and representation rules. The [system architecture](system-architecture.md) owns packages and dependencies; the [diagnostic data lifecycle](diagnostic-data-lifecycle.md) owns acceptance, visibility, retention, redaction and export.

## Input types and optional fields

`DiagnosticInput` is the common typed input family for `CodeKitDiagnostics.log()`: `LogInput` or `HttpInput`. Core derives the record kind from the input, not an independently supplied type flag. Inputs are not stored records: diagnostics creates the immutable envelope and assigns recordedAt/mode.

| Input | Required / defaulted | Nullable data |
| --- | --- | --- |
| `LogInput` | Message; level defaults to info | Source, context, tags, error, stack trace. ID is allocated by diagnostics. |
| `HttpInput` | Adapter-allocated recordId, requestStartedAt, method, URI | Source, context, duration, request headers/body, response, error. Body normalization preserves explicit capture states. |

Optional fields may be absent; required validity fields remain non-nullable. Tags are exact case-sensitive event labels, detached at acceptance and retained in LOG payloads. They do not refer to sink destinations. A missing input body alone must not erase the distinction between absent/disabled/unsupported/captured; adapters provide capture-state information when appropriate.

## Shared models

| Model | Content |
| --- | --- |
| `DiagnosticRecord` | Stable ID, recorder-assigned `recordedAt`, accepted record mode, optional source, context and typed payload. |
| `LogPayload` | Log level, message, optional tags, error and stack trace. Application errors and breadcrumbs use log records rather than separate initial record kinds. |
| `HttpPayload` | Request start time, measured duration, method, URI, request headers/body, optional response and HTTP error. |
| `HttpResponseSnapshot` | Status, response headers and body when a response is available. |
| `DiagnosticError` | Error type, message and optional stack trace, represented as diagnostic data rather than a live exception object. |
| `BodySnapshot` | One captured representation and explicit capture state. |
| `TraceSession` | Session ID and metadata, capture interval and record IDs, never duplicated record payloads. Session lifecycle is defined by the [Trace contract](diagnostic-data-lifecycle.md#trace-sessions). |

HTTP headers preserve multiple values as `Map<String, List<String>>`. Missing response/status is represented as absence, not status `0` or `-1`. Unknown duration is absent, not zero. HTTP correlation is local metadata as defined by the lifecycle; the request uses the same opaque ID as its completed record. Trace session IDs are not distributed-tracing trace IDs.

The recorder assigns acceptance time; adapters supply HTTP request start and measured duration. Ordering follows recorder acceptance rather than timestamps alone, because timestamps can coincide. Stores keep an internal increasing order: a counter in memory, a persistent sequence across restarts in persistent storage. It need not be contiguous. It drives list ordering and oldest-first count eviction, is not a public record field and is not exported. `recordedAt` supports time selection rather than breaking ordering ties. MVP has one recorder writer per store.

## Snapshot and supported values

Accepted payloads are detached, immutable snapshots. `final` fields alone do not make nested Maps/Lists immutable. Models do not contain Dio, Flutter, Drift or Hive types.

Context supports JSON-compatible values only: null, booleans, finite numbers, strings, lists, and maps with string keys. These containers must be acyclic and recursively contain supported values. Arbitrary application objects are not implicitly converted with `toString()`. Errors and stack traces have dedicated inputs; adapters convert other body types into supported text or metadata before submission. Invalid input is rejected with a dropped-record indication through the separate failure path; it must not fail the application's operation.

## Body representation

A body stores one representation: captured text, structured JSON, or supported file/media metadata. Text retains its captured contents in Store raw mode. Already-decoded JSON retains structured data and does not promise reconstruction of original whitespace or formatting.

Text containing valid JSON can be parsed transiently for field redaction and inspection; a second parsed body is not stored alongside its raw representation. Redact before recording must not retain an unredacted text copy. Policy behavior is owned by the [redaction contract](diagnostic-data-lifecycle.md#redaction-policy).

| Capture state | Meaning |
| --- | --- |
| `absent` | No body exists. |
| `captured` | A supported representation was captured. |
| `disabled` | Capture was disabled by configuration. |
| `unsupported` | The adapter could not capture a supported representation. |

File metadata is captured content, not an unsupported-state error. Media/file bytes are excluded according to the lifecycle. Capture state is separate from record mode and is not a redacted/safe flag.

## Serialization boundary

`DiagnosticRecordCodec` owns JSON UTF-8 serialization with lowerCamelCase fields and `schemaVersion`, starting at version 1. Timestamps are UTC ISO 8601 and durations are integer microseconds. Optional absent fields are omitted; explicit nulls in context/body are preserved. Unsupported versions and malformed records are skipped during queries and reported through a separate warning path, not decoded by guessing. Schema version is independent of package version; incompatible interpretation changes require a new version. No multi-version migration framework is required for MVP. Serialization serves persistence and shared interchange, not byte accounting; memory storage need not encode records for retention. Storage adapters may use backend-specific rows and migrations internally, but backend rows do not become public record models. Human-readable export formatting is a separate representation of the shared model.

## Codec v1 fields

Envelope fields are schemaVersion (integer 1), id (string), recordedAt (UTC ISO8601), recordMode (redactBeforeRecording/storeRaw), optional source/context, and payload. Log payload fields are type=log, message, level (trace/debug/info/warning/error/fatal), optional tags/error/stackTrace. HTTP payload fields are type=http, requestStartedAt, method, uri, optional durationMicros/requestHeaders/requestBody/response/error. Response fields are optional statusCode/headers/body. Error fields are type/message and optional stackTrace.

Body fields are state (absent/captured/disabled/unsupported), representation (text/json/media only when captured), and data (required when captured, including explicit JSON null). Media data is a list of MediaFileMetadata objects with optional fileName/contentType/sizeBytes/path. This typed representation has no byte payload field. Unknown optional wire fields may be ignored; missing required fields and invalid enums/types produce invalid decode results. Schema version is checked by DiagnosticRecordCodec before decoding.
