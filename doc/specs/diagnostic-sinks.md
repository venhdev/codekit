---
title: CodeKit Diagnostic Sinks
status: draft
created: 2026-10-11
updated: 2026-10-11
---

# CodeKit Diagnostic Sinks

## Authority and scope

This document owns sink interfaces, routing policies, transport, delivery guards and service-specific presentation. [Public API](public-api.md) owns diagnostics setup and its single recording entrypoint. [Lifecycle](diagnostic-data-lifecycle.md) owns the store branch and shared redaction processing. [Record schema](record-schema.md) owns input and stored payload types.

Sinks are optional outputs. They do not replace the single queryable store and do not own persistence receipts or Trace data. `CodeKitDiagnostics` configures and coordinates sinks; it captures the current redaction policy once at dispatch start. Stored raw data and redacted dispatch data may differ without changing either branch's contract.

## Contracts and composition

`DiagnosticSink` is a core interface implemented by console and network sinks. It receives a prepared, immutable diagnostic representation; concrete sink types do not leak into core. HTTP and LOG routing use the policies below. Method signatures for the internal prepared-dispatch hook remain implementation design work.

`ConsoleSink`, `DiscordSink` and `TelegramSink` implement this interface. Service implementations belong in optional integrations, not core. Shared busy/circuit/transport logic uses composition; no mandatory large base class and no inheritance between Discord and Telegram implementations. The integration package split remains to be decided; do not create additional packages from these class names alone.

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

Network sinks default both dispatch policies to null. Console defaults to enabled policies for both types. Policy constructors detach collections into immutable snapshots. Optional parameters are nullable; required transport and destination settings remain required.

## Transport and ownership

`WebhookTransport` is injected into each network sink. Its request/response types use Dart values and bytes, not Dio/http library types. It sends one request and returns status, headers and body so the service adapter can interpret API success and rate-limit information. It must not silently retry or swallow delivery errors.

```dart
abstract interface class WebhookTransport {
  Future<WebhookResponse> send(WebhookRequest request);
}

// Required request data: URI, HTTP method, headers, body bytes.
// Required response data: status code, headers, body bytes.
// Concrete constructors and repeated-header representation remain open.
```

Developer-supplied transport/client remains developer-owned. Diagnostics disposes sinks, but sinks do not close an injected app-wide client. Core and sink contracts do not require Dio or package:http; a developer can adapt an existing client. No default client implementation is selected by this contract.

## Delivery guards and failures

Dispatch is fire-and-forget relative to the producer and independent of store success. Invalid input and global capture exclusion prevent dispatch; storage queue overflow, recording redaction failure or write failure do not themselves gate the independently prepared sink branch. If dispatch redaction fails, skip dispatch and warn separately, with no raw fallback.

Each network sink permits one send at a time and has no pending queue. New dispatches while busy are dropped, not buffered or retried. Reserve the slot across dispatch preparation and transport completion; record generation must never wait for a network send. Sink failures do not delay another sink or the store branch.

Circuit breaker defaults: five consecutive delivery failures open that sink for one minute. Success resets the counter. While open, skip dispatches; after cooldown allow one probe, reopen on failure and reset on success. Report state changes through the separate warning path rather than warning for every skipped dispatch. These values can be configured at construction; exact options class naming remains open.

Honor a valid server-supplied rate-limit delay as an additional cooldown, even before five failures. Drop the affected message and later arrivals during cooldown; never replay it. Do not resume before either applicable circuit or server cooldown ends. Shared service limits must be respected when multiple sinks use the same remote identity; cross-instance coordination remains a transport/integration implementation concern, not a new durable queue.

Disposal stops new dispatches, does not drain or promise delivery, and releases sink-owned resources. Injected transports remain caller-owned. Already-running sends may finish; failures are handled safely and must not produce recursive diagnostics via the same sink. HTTP calls made by webhook transports must not be captured and dispatched back into the same pipeline.

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

Discord renders selected sections as embed fields; Telegram renders headings and escaped text/code sections. Presentation changes must not reintroduce raw data after dispatch redaction.

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

Optional fields default to null and use documented service/package behavior. Exact visual defaults such as title/footer/timestamp and automatic color mapping must be documented by each implementation; nullable options do not imply inventing service capabilities. Discord username/avatar override the webhook identity for messages; Telegram sendMessage does not support those overrides. Telegram bot token/chat ID and Discord webhook URL are required connection settings, not presentation options. Credentials must not appear in failure warnings.

MVP supports the fields above, not an exhaustive service SDK. Discord payload/embeds and Telegram payload mapping are private integration responsibilities. Rich media, polls, components, uploads and custom formatter callbacks are outside this initial surface.

## Payload sizing and service responses

Dispatch formatters obey the service limits: Discord content up to 2,000 characters, up to 10 embeds, up to 25 fields per embed, field values up to 1,024 characters and combined embed text up to 6,000 characters. Telegram sendMessage text is 1–4,096 characters after entity parsing. Enforce applicable per-field limits as well as aggregate limits.

MVP truncates only the dispatch representation with an explicit truncation indication; it does not split into multiple sends or modify stored records. Preserve valid encoding and Telegram escaped formatting when truncating. Core retention has no byte accounting; remote payload limits are separate protocol requirements.

Discord response interpretation considers its execution settings; using server confirmation (`wait=true`) is recommended internally so a send failure is observable without blocking the producer. Telegram success is defined by its JSON `ok` field, not status alone. Inspect response bodies and headers for documented rate-limit delays. No retry follows either truncation or delivery failure.

## Setup example

The following is a design example, not executable production code. Concrete constructors below are illustrative until implementation signatures are finalized.

```dart
final diagnostics = CodeKitDiagnostics(
  redactionPolicy: RedactionPolicy(),
  sinks: [
    ConsoleSink(),
    DiscordSink(
      webhookUrl: discordWebhook,
      transport: appTransport,
      options: DiscordSinkOptions(
        username: 'CodeKit · Mobile',
        avatarUrl: avatarUri,
        title: 'Diagnostics',
        color: 0xE74C3C,
      ),
      contentOptions: DiagnosticContentOptions(
        responseBody: true,
        stackTrace: true,
      ),
      logDispatchPolicy: LogDispatchPolicy(
        includeTags: {'appCrash'},
      ),
      httpDispatchPolicy: HttpDispatchPolicy(
        statusGroups: {HttpStatusGroup.serverError},
      ),
    ),
    TelegramSink(
      botToken: telegramToken,
      chatId: telegramChatId,
      transport: appTransport,
      options: TelegramSinkOptions(
        disableNotification: true,
      ),
      logDispatchPolicy: LogDispatchPolicy(
        includeTags: {'paymentSucceeded'},
      ),
    ),
  ],
);
```

## Verified references

- [Discord Execute Webhook](https://docs.discord.com/developers/resources/webhook#execute-webhook): identity overrides, content/embeds, confirmation behavior.
- [Discord Embed Limits](https://docs.discord.com/developers/resources/message#embed-limits): field and aggregate payload limits.
- [Discord Rate Limits](https://docs.discord.com/developers/topics/rate-limits): 429 responses, headers and retry delay.
- [Telegram sendMessage](https://core.telegram.org/bots/api#sendmessage): destination, formatting and message options.
- [Telegram Response Parameters](https://core.telegram.org/bots/api#responseparameters): flood-control retry_after.

The legacy dio_curl_interceptor project supplied local precedent for status filtering, embed sections and per-sink circuit breaking. Its shared SenderInfo, Dio-specific client injection, direct request-stage dispatch and HTML/plain-text resend behavior are not adopted.
