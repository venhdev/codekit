---
title: CodeKit Diagnostic Sinks
status: active
created: 2026-10-11
updated: 2026-10-11
---

# CodeKit Diagnostic Sinks

## Authority and scope

This document owns sink interfaces, routing policies, transport, delivery guarantees, guards and service-specific presentation. [Public API](public-api.md) owns diagnostics setup and its single recording entrypoint. [Lifecycle](diagnostic-data-lifecycle.md) owns record acceptance, persistence and export redaction. [Record schema](record-schema.md) owns input and stored payload types.

Sinks are optional outputs. They do not replace the single queryable store and do not own persistence receipts or Trace data. `CodeKitDiagnostics` configures and coordinates sinks; it captures the current redaction policy once at dispatch start. Stored raw data and redacted dispatch data may differ without changing either branch's contract.

## Contracts and composition

`DiagnosticSink` is the core contract for prepared, immutable output. Its HTTP/LOG policy getters, `dispatch(DiagnosticRecord)`, and `dispose()` methods are implemented in core. Concrete destination types do not leak into core.

`DiscordSink` and `TelegramSink` implement this interface in the selected `codekit_webhook` package. Service implementations belong in optional integrations, not core. Shared busy/circuit/transport logic uses composition; there is no base class or inheritance between the two service sinks. `ColoredConsoleSink` in `codekit_console` is a separate, synchronous destination using `colored_logger`; its default HTTP and LOG policies receive all records, and callers can narrow either policy. The logger emits plain text on Web when no ANSI terminal is available.

Service connection configuration, routing policy, content selection and presentation options are separate concerns. There is no cross-service `SenderInfo` or service-specific rendering model in core. The unified `diagnostics.log()` entrypoint is the normal application path; a separate direct `sendMessage()` API is not required by the approved MVP design.

## HTTP dispatch policy

```dart
class HttpDispatchPolicy {
  final List<RegExp>? includeUriPatterns;
  final List<RegExp>? excludeUriPatterns;
  final Set<HttpStatusGroup>? statusGroups;

  HttpDispatchPolicy({
    this.includeUriPatterns,
    this.excludeUriPatterns,
    this.statusGroups,
  });
}

enum HttpStatusGroup {
  informational, // 100–199
  success,       // 200–299
  redirection,   // 300–399
  clientError,   // 400–499
  serverError,   // 500–599
  unknown,       // Missing status or outside 100–599.
}
```

No predicate or `shouldDispatch` callback is supported. A completed HTTP snapshot is dispatched once, following response or error; there is no request-stage dispatch or chronological/simultaneous toggle in MVP. Stream completion follows the lifecycle's headers-only boundary.

Patterns use `hasMatch` on the full captured URI. Matching any exclude pattern vetoes dispatch. When include patterns are present and nonempty, at least one must match. A configured status group set must contain the resulting status group. The remaining conditions combine with AND; members of one list/set combine with OR. URI filters do not apply to LOG inputs.

This exclusion is local to a sink; it does not suppress recording or another sink. Global endpoint capture exclusion is separate and takes priority before capture/dispatch processing.

## LOG dispatch policy

```dart
class LogDispatchPolicy {
  final Set<LogLevel>? levels;
  final Set<String>? includeTags;
  final Set<String>? excludeTags;

  LogDispatchPolicy({
    this.levels,
    this.includeTags,
    this.excludeTags,
  });
}
```

Tags are developer-supplied event metadata, not destination names. Match tags exactly and case-sensitively. Any excluded tag vetoes dispatch; nonempty include tags require at least one match, and configured levels must also match. No callback or regex is supported for tags. Level filtering alone must not infer that an error is an app crash; developers mark such events explicitly.

## Nullable configuration semantics

| Configuration | Meaning |
| --- | --- |
| Sink's HTTP or LOG policy is null | Automatic dispatch of that record type is disabled. |
| Policy present, all fields null | Receive all records of that type. |
| `levels` / `statusGroups` null | No level/status restriction. |
| `levels` / `statusGroups` empty set | Match no records of that type. |
| Include/exclude tags or patterns null or empty | No corresponding condition. |

Network sinks default both dispatch policies to null. A null policy disables automatic dispatch for that record type. Policy constructors detach collections into immutable snapshots. Optional parameters are nullable; a webhook destination is required, while its transport is optional.

## Transport and ownership

`WebhookTransport` is optional on each network sink. Its request/response types use Dart values and bytes, not Dio/http library types. It sends one request and returns status, headers and body so the service adapter can interpret API success and rate-limit information. It must not silently retry or swallow delivery errors.

```dart
abstract interface class WebhookTransport {
  Future<WebhookResponse> send(WebhookRequest request);
}

// Request data: URI, HTTP method, headers, body bytes.
// Response data: status code, headers, body bytes.
// Header values are lists so repeated values can be retained.
```

Without an injected transport, each sink creates one private `package:http` client and closes it when disposed. Webhook requests use this direct client rather than `codekit_http`, so the default delivery path cannot recursively enter the capture pipeline. An injected transport remains caller-owned: sink disposal does not close it and no internal client is created. The public transport contract remains client-neutral. If an injected transport sends through a client instrumented by the same `CodeKitDiagnostics`, the developer must exclude the webhook destination with `captureExcludeUriPatterns` or otherwise prevent recursive capture.

## Delivery guards and failures

Dispatch is fire-and-forget relative to the producer and independent of store success. A store receipt describes recording only; storage queue overflow or write failure does not suppress an independently eligible dispatch, and dispatch failure or busy-drop does not change the receipt. Invalid input and global capture exclusion prevent dispatch; recording redaction failure does not itself gate the independently prepared sink branch. If dispatch redaction fails, skip dispatch and warn separately, with no raw fallback. There is no durable dispatch queue, retry, or delivery promise across process restart.

Each network sink permits one send at a time and has no pending queue. New dispatches while busy are dropped, not buffered or retried. Reserve the slot across dispatch preparation and transport completion; record generation must never wait for a network send. Sink failures do not delay another sink or the store branch.

Circuit breaker defaults: five consecutive delivery failures open that sink for one minute. Success resets the counter. While open, skip dispatches; after cooldown allow one probe, reopen on failure and reset on success. Report state changes through the separate warning path rather than warning for every skipped dispatch. `SinkCircuitBreakerOptions` configures these values at construction.

Honor a valid server-supplied rate-limit delay as an additional cooldown, even before five failures. Drop the affected message and later arrivals during cooldown; never replay it. Do not resume before either applicable circuit or server cooldown ends. Shared service limits must be respected when multiple sinks use the same remote identity; cross-instance coordination remains a transport/integration implementation concern, not a new durable queue.

Disposal stops new dispatches, does not drain or promise delivery, and releases sink-owned resources. Injected transports remain caller-owned. Already-running sends may finish; failures are handled safely and must not produce recursive diagnostics via the same sink. The default HTTP path bypasses the capture adapter; for injected transports, preventing recursive capture is the caller's responsibility as described above.

## Content selection

```dart
class DiagnosticContentOptions {
  final bool? requestHeaders;
  final bool? requestBody;
  final bool? responseHeaders;
  final bool? responseBody;
  final bool? curl;
  final bool? context;
  final bool? error;
  final bool? stackTrace;
}
```

Null uses package defaults: always include the LOG message/level or HTTP method/URI/status/duration summary; include error and stack trace when available; omit headers, bodies, cURL and context unless enabled. Options select already captured data. They never change capture, record mode, retention or redaction, and never read media/file bytes. Inapplicable or unavailable sections are omitted.

Discord renders selected sections in one embed and disables automatic mentions; Telegram renders escaped text. Presentation changes must not reintroduce raw data after dispatch redaction.

## Service options

```dart
class DiscordSinkOptions {
  final String? username;
  final Uri? avatarUrl;
  final String? title;
  final int? color;
  final String? footer;
  final bool? includeTimestamp;
}

class TelegramSinkOptions {
  final int? messageThreadId;
  final bool? disableNotification;
  final bool? protectContent;
  final bool? disableLinkPreview;
}
```

Optional fields default to null and use documented service/package behavior. Discord has no automatic color mapping; specify `color` to set one. The package defaults to no title, footer, or timestamp. Discord username/avatar override the webhook identity for messages; Telegram sendMessage does not support those overrides. Telegram bot token/chat ID and Discord webhook URL are required connection settings, not presentation options. Credentials must not appear in failure warnings. The optional warning callback receives a stable code and credential-free message; callback failures are swallowed. Without a callback, the package reports warnings through `dart:developer`.

MVP supports the fields above, not an exhaustive service SDK. Discord payload/embeds and Telegram payload mapping are private integration responsibilities. Rich media, polls, components, uploads and custom formatter callbacks are outside this initial surface.

## Payload sizing and service responses

Dispatch formatters obey the service limits: Discord content up to 2,000 characters, up to 10 embeds, up to 25 fields per embed, field values up to 1,024 characters and combined embed text up to 6,000 characters. Telegram sendMessage text is 1–4,096 characters after entity parsing. Enforce applicable per-field limits as well as aggregate limits.

MVP truncates only the dispatch representation with an explicit truncation indication; it does not split into multiple sends or modify stored records. Preserve valid encoding and Telegram escaped formatting when truncating. Core retention has no byte accounting; remote payload limits are separate protocol requirements.

Discord response interpretation considers its execution settings; using server confirmation (`wait=true`) is recommended internally so a send failure is observable without blocking the producer. Telegram success is defined by its JSON `ok` field, not status alone. Inspect response bodies and headers for documented rate-limit delays. No retry follows either truncation or delivery failure.

Full `CodeKitDiagnostics` composition is shown in the [Public API example](public-api.md#unified-input-and-constructor-examples). Each network sink accepts an optional `WebhookTransport`; when omitted, the sink creates and closes its own `package:http` client. An injected transport remains caller-owned.

## Verified references

- [Discord Execute Webhook](https://docs.discord.com/developers/resources/webhook#execute-webhook): identity overrides, content/embeds, confirmation behavior.
- [Discord Embed Limits](https://docs.discord.com/developers/resources/message#embed-limits): field and aggregate payload limits.
- [Discord Rate Limits](https://docs.discord.com/developers/topics/rate-limits): 429 responses, headers and retry delay.
- [Telegram sendMessage](https://core.telegram.org/bots/api#sendmessage): destination, formatting and message options.
- [Telegram Response Parameters](https://core.telegram.org/bots/api#responseparameters): flood-control retry_after.

The legacy dio_curl_interceptor project supplied local precedent for status filtering, embed sections and per-sink circuit breaking. Its shared SenderInfo, Dio-specific client injection, direct request-stage dispatch and HTML/plain-text resend behavior are not adopted.
