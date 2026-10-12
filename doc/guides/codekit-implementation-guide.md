# CodeKit Application Implementation Guide

This is the standalone, end-to-end integration guide for CodeKit. It contains
the package choices, application composition rules, code examples, data and
resource lifecycles, privacy behavior, supported capture boundaries, viewer
behavior, and verification checklist an implementation agent needs. Do not
assume another CodeKit document is required to understand or implement the
integration.

The guide describes the current CodeKit workspace package APIs. The current
workspace versions are unpublished. Before editing an application, an agent
must verify that the selected packages are available from a dependency source
the app can use. It must not invent package versions, pretend the packages are
on pub.dev, or introduce speculative overrides.

## 1. Select the features

Use this checklist as the feature scope. HTTP clients and Flutter integrations
can be selected independently; storage and record mode each require one choice.
Diagnostic sinks can be combined.

```text
HTTP capture (choose independently)
[ ] Dio
[ ] package:http

Storage (choose one)
[ ] In-memory (default)
[ ] SQLite with Drift (native platforms)

Diagnostic sinks (choose independently)
[ ] Colored console
[ ] Discord webhook
[ ] Telegram bot

Flutter integrations (choose independently)
[ ] In-app diagnostics viewer
[ ] Flutter framework and root-isolate error capture

Record mode (choose one)
[ ] Redact before recording
[ ] Store raw
```

### Package map

| Package | Add it when | Platform/dependency notes |
| --- | --- | --- |
| `codekit_core` | Always; it owns records, the recorder, redaction, storage contracts, query/export, and sink contracts | Pure Dart; no Flutter or HTTP-client dependency |
| `codekit` | A Dart app wants one convenient import for core plus the colored console sink | It re-exports `codekit_core` and `codekit_console`; it is not a global singleton and does not add the optional adapters |
| `codekit_console` | Colored diagnostic output is selected | Uses `colored_logger`; ANSI is used when supported, with plain-text fallback on Web |
| `codekit_dio` | The app sends requests with Dio | Add Dio separately; use the app's configured instance |
| `codekit_http` | The app sends requests with `package:http` | Add `http` separately; use the returned wrapper |
| `codekit_drift_diagnostic_store` | Records must persist across process restarts | Native SQLite for Android, iOS, and desktop; use memory on Web in this MVP |
| `codekit_webhook` | Records should be sent to Discord and/or Telegram | Requires network access; credentials must not be embedded in a public client app |
| `codekit_flutter` | Flutter framework and root-isolate errors should be recorded | Installs process-global handlers explicitly |
| `codekit_ui` | The app needs the in-app records viewer, Trace controls, settings, and export UI | Flutter UI; does not create or own the diagnostics instance |

The app creates one `CodeKitDiagnostics` instance and passes that same instance
to every selected producer and UI. Core has no default global instance. Sinks
are destinations, not storage. HTTP capture adapters and webhook transports
are separate: instrumenting the app's HTTP client does not instrument the
webhook client's outbound requests.

## 2. Resolve package dependencies before implementation

All current CodeKit workspace packages declare `publish_to: none`; their
current versions cannot be installed from pub.dev. The umbrella also has a
historical `0.0.x` release line, but that is not the current workspace API.

Before modifying dependencies, inspect where the target app lives and which
source it can consume:

1. If the app is already a member of this Pub workspace, confirm the root
   workspace member list includes it and use the workspace's resolved package
   versions. Do not add ad hoc path overrides for packages already in the
   workspace.
2. If the app is in the same repository but outside the workspace, determine
   whether the repository intends to add it as a workspace member or consume
   package directories through supported local path dependencies. Make only
   the minimal, deliberate change required by the repository's existing
   package layout.
3. If the app is in another repository, check for an approved local checkout
   or Git source and ref. Verify all selected internal dependencies resolve
   from that source together. Do not guess a release version or point only one
   package at a ref while its internal dependencies resolve elsewhere.
4. If no usable source exists, stop before changing the app's dependency
   configuration and report exactly what source or release is missing.

`codekit` is an umbrella convenience only. Individual applications can depend
directly on `codekit_core` and only the selected packages. Keep optional
packages out of the dependency graph when their features are not selected.
`colored_logger` is brought in by `codekit_console`; application code normally
does not need to depend on it directly.

Typical package imports for selected integrations are:

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_console/codekit_console.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:codekit_drift_diagnostic_store/codekit_drift_diagnostic_store.dart';
import 'package:codekit_webhook/codekit_webhook.dart';
import 'package:codekit_flutter/codekit_flutter.dart';
import 'package:codekit_ui/codekit_ui.dart';
```

Only import packages the app selected. `package:codekit/codekit.dart` may
replace the separate core and console imports when using the umbrella; it does
not replace imports for Dio, HTTP, Drift, webhook, Flutter hooks, or UI.

## 3. Understand the runtime data flow

```text
app logs ───────────────┐
Dio requests ───────────┤
package:http requests ──┼──> CodeKitDiagnostics.log(input)
Flutter error hooks ────┘              │
                                       ├──> store copy
                                       ├──> redacted sink dispatch
                                       └──> query / Trace / export
                                                    │
                                                    └──> viewer or app UI
```

There are two input types:

- `LogInput` records application messages, errors, stack traces, tags, source,
  and JSON-compatible context. Use it for app breadcrumbs and manually handled
  exceptions.
- `HttpInput` is a completed HTTP snapshot created by a client adapter. It
  includes a locally generated record ID, start time, request data, response
  snapshot or error, and measured duration when available.

Core detaches and validates snapshots at acceptance. Context supports only
acyclic JSON-compatible values: null, booleans, finite numbers, strings, lists,
and maps with string keys. It does not call `toString()` on arbitrary context
objects. Put errors in the `error` and `stackTrace` fields rather than
embedding exception objects in context.

Each accepted record receives an ID, UTC `recordedAt`, the record mode active
at acceptance, optional source/context, and a typed payload. IDs are local
diagnostic metadata; adapters do not add them to network request headers.

## 4. Initialize the core

The core-only setup works in Dart and Flutter. The default store is
`MemoryDiagnosticStore`, the default record mode is `RecordMode.storeRaw`, and
the default redaction policy enables the Authorization, Cookie, and Set-Cookie
header presets. No sinks are installed unless they are passed at construction.

```dart
import 'package:codekit_core/codekit_core.dart';

final diagnostics = CodeKitDiagnostics(
  retention: RetentionPolicy(maxRecords: 1000),
  redactionPolicy: RedactionPolicy(),
  recordMode: RecordMode.redactBeforeRecording,
  captureExcludeUriPatterns: [
    RegExp(r'/health(?:\?|$)'),
    RegExp(r'/metrics(?:\?|$)'),
  ],
  onWarning: (warning) {
    // Send to a separate safe logger; never log this through a failing store.
    print('CodeKit ${warning.code}: ${warning.message}');
  },
);
```

Constructor options:

| Option | Behavior |
| --- | --- |
| `store` | Optional `DiagnosticStore`; omitted means in-memory. Diagnostics owns and closes it, including an injected store. |
| `retention` | Count-only retention. Omitted or `maxRecords: null` means unlimited. Non-null values below 100 are normalized to 100. |
| `redactionPolicy` | Policy used for Redact-before-recording, sink dispatch, and redacted export. |
| `recordMode` | Applies to newly accepted records only. Defaults to `RecordMode.storeRaw`. |
| `sinks` | Optional output list. Diagnostics owns and disposes the sinks. |
| `captureExcludeUriPatterns` | Optional regular expressions matched against the full URI string. A match prevents HTTP diagnostic capture; it does not cancel the host request. |
| `pendingRecordLimit` | Persistent write queue limit; defaults to 1000 pending records, excluding the active write. Must be positive. |
| `onWarning` | Safe warning callback for recorder/storage/sink failures. Callback errors are isolated. |

Retention has no age, byte-size, or background-expiration limit. When the
record count exceeds the configured limit, old records are removed in batches
of at least five percent of the limit, rounded up, or by more when necessary
to get under the limit. For example, at a limit of 100, inserting record 101
evicts five oldest records, leaving 96.

### Log application events

```dart
final receipt = diagnostics.log(
  LogInput(
    message: 'Payment request completed',
    level: LogLevel.info,
    source: 'CheckoutRepository',
    tags: {'payment', 'checkout'},
    context: const {
      'orderId': 'order-42',
      'attempt': 1,
      'isRetry': false,
    },
  ),
);

if (!receipt.accepted) {
  // The diagnostic was dropped; do not fail the payment operation because
  // diagnostics did not accept it.
  print('Diagnostic dropped: ${receipt.dropReason}');
}
```

Record an exception without changing the app's exception handling:

```dart
try {
  await repository.loadProfile();
} catch (error, stackTrace) {
  diagnostics.log(
    LogInput(
      message: 'Could not load profile',
      level: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
      source: 'ProfileScreen',
      tags: {'profileLoadFailure'},
      context: const {'profileId': '42'},
    ),
  );
  rethrow; // Preserve the application's original error behavior.
}
```

`LogLevel` values are `trace`, `debug`, `info`, `warning`, `error`, and
`fatal`; omitted level defaults to `info`. Tags are exact, case-sensitive
labels. Context and tags are explicit; there is no ambient request/user context
propagation.

### Receipts and persistence confirmation

`log()` returns a `RecordReceipt` synchronously. `accepted` means the input
passed validation, policy processing, and store acceptance; it does not mean a
persistent write has completed. The receipt has a `recordId` when accepted and
a `dropReason` when dropped. `persistedOrNull()` is safe to await when a caller
needs confirmation:

```dart
final receipt = diagnostics.log(
  const LogInput(message: 'Checkpoint reached'),
);
final persistence = await receipt.persistedOrNull();
if (persistence != null) {
  print('Persisted ${persistence.recordId}');
}
```

For memory storage, records are immediately queryable and persistence
confirmation is null. For persistent storage, records become queryable only
after the write and retention operation succeed. Pending records are not
included in queries. Queue overflow drops the new record instead of blocking
the app; failed writes are not retried and do not fall back to memory. Core has
no write timeout, flush, or drain operation. A hung store can hold the active
write and eventually fill the queue.

## 5. Configure privacy and redaction

Record mode, storage backend, and export representation are separate decisions:

| Choice | Effect |
| --- | --- |
| `RecordMode.storeRaw` | Stores captured values without running the policy. This is the default and can persist secrets. |
| `RecordMode.redactBeforeRecording` | Applies the policy before the record reaches storage. Removed values cannot be recovered later. |
| `ExportRepresentation.redacted` | Applies the current policy to an export copy. This is the default for export and does not mutate stored data. |
| `ExportRepresentation.asStored` | Exports exactly the representation currently in storage. Previously redacted values stay redacted; raw values may be disclosed. |

The active policy is applied separately to each new record, sink dispatch, and
redacted export. Policy or mode changes affect later operations only; they do
not rewrite stored records. A redacted result is not a guarantee that every
sensitive value was found.

Available rules:

- Header presets `authorization`, `cookie`, and `setCookie` default to enabled
  and match both request and response headers. Additional header rules match
  exact names case-insensitively and can target request, response, or both.
- Query rules match exact parameter names. Repeated values are all replaced.
- Body-field rules traverse simple dotted JSON object paths. They do not walk
  arrays or support wildcards, indices, or keys containing dots.
- Text rules replace regular-expression matches in supported text values,
  including messages, errors, stack traces, body text, context strings, and
  header/query values. Map keys are not rewritten.

The replacement marker is `[REDACTED]`. Built-in header presets run first;
additional rules run in declaration order. Field rules affect captured JSON
bodies and text bodies that can be parsed as JSON. A missing field or
non-JSON text is unchanged; that does not prove the body is safe. Arbitrary
text-regex rules may mask additional text on a later application.

```dart
final policy = RedactionPolicy(
  // Keep the defaults on unless there is a deliberate reason not to.
  authorization: true,
  cookie: true,
  setCookie: true,
  rules: [
    HeaderRedactionRule(
      {'x-api-key', 'x-session-token'},
      target: HeaderTarget.both,
    ),
    QueryRedactionRule({'access_token', 'api_key'}),
    BodyFieldRedactionRule({'password', 'user.email'}),
    TextRedactionRule(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]+')),
  ],
);

final diagnostics = CodeKitDiagnostics(
  redactionPolicy: policy,
  recordMode: RecordMode.redactBeforeRecording,
);
```

`captureExcludeUriPatterns` is not redaction: it skips capture entirely for
matching requests. Use exclusions when no diagnostic record should be created
for a class of endpoints. Do not rely on redaction alone to omit those events.

If redaction throws before recording, the record is dropped; CodeKit does not
fall back to raw. If redaction fails during an export, the export fails without
partial output or falling back to As stored.

## 6. Choose storage

### In-memory storage

No extra adapter is needed. This is the default and works on Dart, Flutter
native, and Web. Records and Trace sessions disappear when the process ends.
Set `RetentionPolicy(maxRecords: ...)` if the app needs a bounded count.

### Native SQLite with Drift

The Drift factory opens the database, creates diagnostics, and transfers store
ownership to that diagnostics instance. The caller chooses a native file path.
In a Flutter application, add `path_provider` and `path` as direct app
dependencies when using the following pattern:

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_drift_diagnostic_store/codekit_drift_diagnostic_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<CodeKitDiagnostics> createPersistentDiagnostics() async {
  final directory = await getApplicationSupportDirectory();
  final databasePath = p.join(directory.path, 'codekit.sqlite');

  return createDriftDiagnostics(
    databasePath: databasePath,
    retention: RetentionPolicy(maxRecords: 5000),
    recordMode: RecordMode.redactBeforeRecording,
    redactionPolicy: RedactionPolicy(
      rules: [
        HeaderRedactionRule({'x-api-key'}),
        BodyFieldRedactionRule({'password', 'user.email'}),
      ],
    ),
  );
}
```

The factory accepts the same core settings as `CodeKitDiagnostics`, including
sinks, URI exclusions, warning callback, and pending-write limit. The adapter
creates the parent directory. It stores records and Trace sessions in native
SQLite, uses explicit schema migrations, and skips malformed persisted rows
with a warning. Web is not supported by this adapter in the current MVP; use
memory storage there. The database is not encrypted by CodeKit. Store raw is
especially sensitive when persistence is enabled; use redaction deliberately
and apply app-specific file protection/encryption if required.

Do not independently close a store passed to `CodeKitDiagnostics`; diagnostics
owns it and closes it from `dispose()`. A store instance belongs to one
diagnostics instance. Database path and retention are host configuration; the
viewer does not edit them.

## 7. Add diagnostic sinks

Sinks receive a redacted dispatch copy prepared with the policy captured for
that dispatch, even when the store's record mode is Store raw. Sink dispatch is
independent of whether persistence later succeeds. If policy processing for the
sink fails, the event is not delivered to that sink and a warning is emitted.

### Colored console

```dart
import 'package:codekit_console/codekit_console.dart';
import 'package:codekit_core/codekit_core.dart';

final console = ColoredConsoleSink(
  logDispatchPolicy: LogDispatchPolicy(
    levels: {LogLevel.warning, LogLevel.error, LogLevel.fatal},
  ),
  httpDispatchPolicy: HttpDispatchPolicy(
    statusGroups: {HttpStatusGroup.clientError, HttpStatusGroup.serverError},
  ),
);

final diagnostics = CodeKitDiagnostics(sinks: [console]);
```

Colored console accepts all LOG and HTTP records by default. Its policies can
limit severity, tags, URI patterns, or HTTP status groups. It writes concise
lines synchronously; it is output, not persistent storage. Web uses plain text
when ANSI terminal output is unavailable. A custom `writer` callback can route
the formatted line elsewhere.

### Discord and Telegram webhooks

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_webhook/codekit_webhook.dart';

List<DiagnosticSink> createWebhookSinks({
  Uri? discordWebhookUrl,
  String? telegramBotToken,
  String? telegramChatId,
}) => [
  if (discordWebhookUrl != null)
    DiscordSink(
      webhookUrl: discordWebhookUrl,
      httpDispatchPolicy: HttpDispatchPolicy(
        statusGroups: {HttpStatusGroup.serverError},
      ),
      logDispatchPolicy: LogDispatchPolicy(
        levels: {LogLevel.fatal},
        includeTags: {'reportToOperations'},
      ),
      contentOptions: const DiagnosticContentOptions(
        requestHeaders: false,
        requestBody: false,
        responseHeaders: false,
        responseBody: false,
        context: false,
      ),
    ),
  if (telegramBotToken != null && telegramChatId != null)
    TelegramSink(
      botToken: telegramBotToken,
      chatId: telegramChatId,
      logDispatchPolicy: LogDispatchPolicy(
        levels: {LogLevel.error, LogLevel.fatal},
      ),
    ),
];
```

Important webhook behavior:

- A webhook sink with a null HTTP or LOG dispatch policy does not receive that
  kind of record. Configure the policy for each kind you intend to deliver.
- HTTP policy can include/exclude URI regular expressions and select response
  status groups. Missing status maps to `HttpStatusGroup.unknown`.
- LOG policy can select levels, require matching tags, and exclude tags. A
  record with any excluded tag is rejected; when `includeTags` is non-empty, at
  least one must match.
- Delivery is fire-and-forget, one request at a time per sink. Events arriving
  while a sink is busy or cooling down are dropped; there is no queue and no
  automatic retry.
- The default circuit breaker opens after five consecutive failures for one
  minute. A service rate-limit response can establish a server-directed
  cooldown. These controls are per sink and can be configured with
  `SinkCircuitBreakerOptions`.
- The default sink owns a private `package:http` client and closes it when
  diagnostics is disposed. If an application injects a `WebhookTransport`,
  that transport remains caller-owned.
- Webhook URLs and bot tokens are credentials. Do not commit them or bundle
  server-side credentials into a public mobile/Web app. For a public client,
  prefer an authenticated backend relay. Send only data appropriate for that
  destination.

Optional `DiscordSinkOptions`, `TelegramSinkOptions`, and
`DiagnosticContentOptions` control service presentation and which optional
record sections are included. Do not use sink content filtering as a substitute
for redacting data before persistence.

## 8. Capture HTTP clients

Attach capture to the client's actual configured instance. CodeKit must not
create a parallel client, buffer a stream, consume a response, add a request
header, or change retry/error behavior to improve diagnostics. Capture failure
must not replace the app's response or original network error.

### Dio

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:dio/dio.dart';

final Dio appDio = createConfiguredDio(); // Existing interceptors/adapters.
final Dio observedDio = appDio.withDiagnostics(diagnostics);

try {
  final response = await observedDio.get<Map<String, Object?>>('/profile');
  print(response.data);
} finally {
  // withDiagnostics returns the exact same Dio instance.
  observedDio.close();
}
```

The extension attaches one CodeKit interceptor for the same diagnostics
instance and returns the same Dio. Reapplying it with the same instance is a
no-op; a different diagnostics instance can add a separate interceptor. Each
retry attempt that re-enters the interceptor creates a record. Redirects
handled internally by Dio's adapter remain part of one logical request.

The interceptor records on response or error, using a private request ID that
is not sent over the network. It calls Dio's handler onward whether or not
capture succeeds. It does not close Dio when diagnostics is disposed; the app
owns the client lifecycle.

Dio body behavior:

| Input | Captured form |
| --- | --- |
| `String` | Text |
| JSON-compatible `Map`, `List`, number, or boolean | JSON snapshot |
| `FormData` | Text fields plus file metadata; file bytes are not read |
| `Uint8List`, stream, or other unsupported object | Unsupported body |
| Response configured as stream | Unsupported response body; stream remains untouched |
| No body | Absent |

### `package:http`

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_http/codekit_http.dart';
import 'package:http/http.dart' as http;

final http.Client configuredClient = createConfiguredHttpClient();
final http.Client observedClient = configuredClient.withDiagnostics(diagnostics);

try {
  final response = await observedClient.get(
    Uri.parse('https://api.example.com/profile'),
  );
  print(response.statusCode);
} finally {
  // Close the returned wrapper; it forwards close to the inner client once.
  observedClient.close();
}
```

Unlike Dio's extension, this extension returns a wrapper. Always send requests
through and close the returned wrapper; using the original inner client or
top-level `http` functions bypasses capture. Wrapping the same diagnostics
instance again in a wrapper chain does not add another layer. A different
diagnostics instance adds one.

The wrapper captures at `send()` and records at response headers. It returns the
original response stream and does not consume it. Text/JSON request snapshots
and multipart fields/file metadata may be captured; multipart file bytes,
streamed request bodies, and response bodies are not captured. The multipart
content type is recorded without a boundary added later by request
finalization. Wrapper order determines whether a retry wrapper exposes each
attempt or only its final response. Redirects handled inside the underlying
client are not separate records.

### HTTP capture common behavior

- Excluded URIs are checked before snapshotting; the host request still runs.
- Request IDs are generated before dispatch and remain internal metadata.
- The stored record is completed once the adapter reaches its completion
  boundary; `recordedAt` is the recorder acceptance time, not request start.
- Duration is measured by the adapter. For streamed responses it ends at
  headers, not when the app later finishes reading the stream.
- Body states distinguish `absent`, `captured`, `disabled`, and `unsupported`.
  Unsupported means the client could not make a supported non-invasive
  snapshot; it is not an empty body.
- File metadata can include name, content type, size, and possibly local path
  depending on the producer. Treat paths and metadata as sensitive too.

## 9. Flutter error hooks

Configure the app's own handlers first, then install CodeKit's optional global
hooks:

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_flutter/codekit_flutter.dart';

// First set FlutterError.onError and PlatformDispatcher.instance.onError
// according to the application's existing error policy.
final hooks = CodeKitFlutterErrorHooks.install(diagnostics);
```

`FlutterError.onError` exceptions are recorded as error-level LOG records;
root-isolate `PlatformDispatcher` errors are recorded as fatal LOG records.
CodeKit then calls the callbacks that were installed before it. The platform
callback's boolean return is preserved; if there was no earlier callback,
CodeKit returns false.

Only one CodeKit hook installation may be active at a time. Keep the returned
handle and call `hooks.dispose()` when this capture scope ends. Disposal
restores a previous callback only if CodeKit's own wrapper is still installed;
it does not overwrite a newer callback installed by another library. Dispose
hooks before disposing diagnostics. This package does not install hooks
automatically and does not depend on the viewer.

## 10. Add the Flutter viewer

### Floating bubble

The bubble belongs in `MaterialApp.builder` and must use the same navigator key
as the app. The application owns the diagnostics instance and decides when it
is disposed.

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_ui/codekit_ui.dart';
import 'package:flutter/material.dart';

final diagnostics = CodeKitDiagnostics();
final navigatorKey = GlobalKey<NavigatorState>();

MaterialApp(
  navigatorKey: navigatorKey,
  builder: (context, child) => CodeKitBubble(
    diagnostics: diagnostics,
    navigatorKey: navigatorKey,
    debugOnly: true,
    viewerSettings: const CodeKitViewerSettings(
      allowRuntimeRecordModeChanges: false,
      setupDetails: [
        CodeKitViewerSetupDetail(
          label: 'HTTP capture',
          value: 'Dio',
          description: 'Configured on the app API client',
        ),
        CodeKitViewerSetupDetail(
          label: 'Storage',
          value: 'In-memory',
        ),
      ],
    ),
    child: child!,
  ),
  home: const AppHomePage(),
);
```

The bubble is visible in all builds unless `debugOnly: true`. It is draggable,
available across app routes, and hidden while its viewer route is open. If the
app owns its own navigation entry, use `CodeKitDiagnosticsScreen` directly and
pass the same diagnostics object. The viewer is not required for recording,
querying, Trace management, or export.

### Settings shown in the viewer

`CodeKitViewerSettings` accepts:

- `setupDetails`: factual, read-only app-provided label/value/description
  entries, for example selected adapters and storage type.
- `allowRuntimeRecordModeChanges`: defaults to false. If true, the settings
  sheet lets a user select Store raw or Redact before recording for new
  records. It does not rewrite existing records.

The active `RedactionPolicy` is shown read-only. The viewer does not edit
redaction rules, URI exclusions, retention, database path, sinks, or adapter
attachment. Setup details are informational, not proof that a feature is
working and not an access-control mechanism.

### Viewer workflows and interaction behavior

- The records page supports paged loading, text/regex search, filters by type,
  HTTP status group, duration, and inclusive time range, plus reload and pull
  to refresh. The filter action indicates when filters are active. Search
  matches message/source/error for LOG and method/URI/source/error for HTTP; it
  does not search headers, bodies, or context.
- Long-pressing a record enters selection mode. Search and filters remain
  available; selected rows are outlined rather than shown with checkboxes.
  Select all applies to the current filtered result set. Export and deletion
  operate on selected IDs.
- HTTP detail has separate Request and Response tabs, a summary, collapsible
  request/response headers (collapsed by default), and body inspection
  (expanded by default). Copy controls appear only when the corresponding data
  is available. Record ID, recorded time, and record mode are shown in an
  information dialog.
- Trace controls show whether capture is active and the count of accepted IDs.
  Saved sessions can scope the list, be exported, or be explicitly deleted.
- Filters, Settings, Trace sessions, and Search history use the same 55%-height
  draggable, scrollable sheet. Drag down or tap outside to close.
- Export asks the user to choose Redacted or As stored. Copy and Share are
  separate full-width actions; Share can optionally share a temporary `.txt`
  file on native platforms or download it on Web. The sheets close by drag or
  tapping outside and have no top-right X action.

Search history is kept in UI memory only and stores the 20 most recent valid,
submitted searches. It is not persisted in the diagnostics store.

Direct navigation is also supported:

```dart
Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => CodeKitDiagnosticsScreen(
      diagnostics: diagnostics,
      viewerSettings: const CodeKitViewerSettings(
        setupDetails: [
          CodeKitViewerSetupDetail(label: 'Storage', value: 'Drift'),
        ],
      ),
    ),
  ),
);
```

Use this when the app wants to control the route itself instead of displaying
the floating bubble. A custom route still uses the same diagnostics object and
does not take ownership of it.

## 11. Query, Trace, delete, and export without the viewer

The app can use core APIs directly or build a custom UI.

### Query and pagination

```dart
var page = await diagnostics.query(
  RecordQuery(
    limit: 50,
    text: 'payment',
    types: {DiagnosticRecordType.http},
    statusGroups: {HttpStatusGroup.serverError},
    durationLevels: {DurationLevel.slow},
  ),
);

while (page.nextCursor != null) {
  page = await diagnostics.query(
    RecordQuery(
      limit: 50,
      text: 'payment',
      types: {DiagnosticRecordType.http},
      statusGroups: {HttpStatusGroup.serverError},
      durationLevels: {DurationLevel.slow},
      cursor: page.nextCursor,
    ),
  );
}
```

Records are ordered newest first. A cursor is opaque and belongs to the same
store and query; do not change filters/search while continuing with an old
cursor. Restart from the first page after query changes. Status groups are
informational, success, redirection, client error, server error, and unknown.
Default duration thresholds classify under 200 ms as fast, under 1 second as
normal, under 3 seconds as warn, and at least 3 seconds as slow; absent duration
is unknown. Pass `DurationThresholds` to customize the boundaries. Empty filter
sets mean unrestricted. Text search is case-insensitive substring matching;
regex is a separate mode and cannot be set at the same time as `text`.

### Manual Trace capture

A Trace session stores record IDs, not copies of records. One manual capture
can be active per diagnostics instance. Accepted IDs are collected during the
interval, including records queued for persistent storage.

```dart
diagnostics.startTrace();
print('Trace active: ${diagnostics.isTraceActive}');

diagnostics.log(
  const LogInput(message: 'User started checkout', tags: {'checkout'}),
);
print('Captured IDs: ${diagnostics.activeTraceRecordCount}');

final session = await diagnostics.stopTrace(name: 'Checkout investigation');
if (session != null) {
  final export = await diagnostics.exportTraceSession(session.id);
  if (export.status == ExportStatus.success) {
    print(export.text);
  }
}
```

An empty capture returns null and is not saved. Starting twice or stopping
while inactive throws `StateError`. Stop saves IDs without waiting for pending
persistent writes. A picker-style session can be built from queryable records
in an inclusive time interval:

```dart
final session = await diagnostics.createTraceSession(
  from: DateTime.now().subtract(const Duration(minutes: 10)),
  to: DateTime.now(),
  name: 'Last ten minutes',
);

final savedSessions = await diagnostics.listTraceSessions();
for (final saved in savedSessions) {
  print('${saved.name ?? 'Trace'}: ${saved.recordIds.length} IDs');
}

if (session != null) {
  // Delete only after an explicit user action/confirmation.
  await diagnostics.deleteTraceSession(session.id);
}
```

Picker-based creation does not include pending writes. A saved session can
outlive referenced records: records may be deleted, evicted, or never finish
persisting. Export includes only IDs that still resolve, skips missing IDs,
and does not rewrite the session. If none resolve, the export is empty. A
storage query failure is a failure, not an empty result. Deleting records does
not delete Trace sessions; delete a session explicitly with
`deleteTraceSession(sessionId)`.

### Export and HTTP fragments

```dart
final result = await diagnostics.exportRecords(
  selectedRecordIds,
  representation: ExportRepresentation.redacted,
);

switch (result.status) {
  case ExportStatus.success:
    final text = result.text!;
    print('Exported ${result.recordCount} record(s)');
    print(text);
    break;
  case ExportStatus.empty:
    print('No selected records are available');
    break;
  case ExportStatus.failed:
    print('Export failed: ${result.error}');
    break;
}
```

Core returns indented JSON text; clipboard, sharing, file creation, and download
are UI/platform responsibilities. To format one HTTP fragment:

```dart
final headers = await diagnostics.formatHttpFragment(
  httpRecordId,
  HttpFragment.headers,
  target: HeaderTarget.both,
  representation: ExportRepresentation.redacted,
);

final body = await diagnostics.formatHttpFragment(
  httpRecordId,
  HttpFragment.body,
  target: HeaderTarget.response,
  representation: ExportRepresentation.redacted,
);

final curl = await diagnostics.formatHttpFragment(
  httpRecordId,
  HttpFragment.curl,
  representation: ExportRepresentation.redacted,
);
```

`HttpFragment` supports `body`, `headers`, and `curl`; `HeaderTarget` selects
request, response, or both for headers/body. cURL is generated from the
available, already-transformed snapshot. It may be incomplete when the body was
not captured or was redacted. Generating it never sends a request.

`deleteByIds(ids)` removes selected records and returns the number removed;
`clearRecords()` removes currently stored records and returns the count. Neither
operation deletes Trace sessions. Clear is not a barrier: a previously queued
persistent write can finish afterward and make a record visible again.

## 12. Compose and dispose resources

The application owns the lifecycle of the diagnostics instance and its client
instances. Diagnostics owns its store and configured sinks. It does not own or
close the app's Dio or HTTP client. Flutter hooks are separately installed and
disposed by the app.

A lifecycle owner should perform shutdown in this order:

```dart
import 'package:codekit_core/codekit_core.dart';
import 'package:codekit_dio/codekit_dio.dart';
import 'package:codekit_flutter/codekit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

Future<void> shutdownDiagnostics({
  required CodeKitDiagnostics diagnostics,
  CodeKitFlutterErrorHooks? flutterHooks,
  Dio? dio,
  http.Client? httpClient,
}) async {
  flutterHooks?.dispose();
  dio?.close();
  // If this is the CodeKit HTTP wrapper, close forwards to its inner client.
  httpClient?.close();
  await diagnostics.dispose();
}
```

Import `Dio` and `package:http` in the application file only when those clients
are selected. If an HTTP wrapper owns the underlying client, do not close both
the wrapper and the inner client separately. A Dio extension returns the
original Dio, so close it once.

`dispose()` is idempotent. It stops new acceptance, completes/discards queued
persistent writes safely, closes sinks, and closes the store. It is not a flush
or drain guarantee; pending records may be lost. Do not claim that every
accepted record reached disk. Choose an app shutdown boundary that accepts
best-effort persistence. There is no automatic app lifecycle observer and no
public flush operation.

Flutter's `State.dispose()` is synchronous. Do not block it waiting on async
disposal; make the runtime owner expose an async shutdown method and invoke it
at a lifecycle point where the application can manage its future. If the app
can only start async shutdown from synchronous teardown, make that fire-and-
forget behavior explicit and do not treat it as a persistence guarantee.

## 13. End-to-end implementation sequence

An agent implementing the checked features should follow this sequence:

1. Inspect the app's language/platform targets, SDK constraints, dependency
   source, startup composition root, existing configured clients, global error
   handlers, navigation setup, shutdown owner, and test commands.
2. Confirm the selected CodeKit package sources are usable. If not, stop before
   dependency edits and report the missing source/ref/release.
3. Add only the selected dependencies. Do not add Drift to a Web target or
   Flutter packages to a Dart-only target.
4. Create one `CodeKitDiagnostics` at the app composition boundary. Deliberately
   configure record mode, redaction, retention, exclusions, sinks, and storage.
5. Attach the selected adapters to the actual existing client instances.
   Preserve interceptors, retry behavior, client ownership, error propagation,
   and streams.
6. Install Flutter hooks only after the app's own callbacks are configured.
   Add the viewer only if selected and pass the same diagnostics object.
7. Wire all cleanup through the existing lifecycle owner. Stop hooks and close
   app clients; then dispose diagnostics once.
8. Add focused tests with synthetic secrets and deterministic fake responses.
   Prove both host behavior and diagnostic output; do not use real credentials
   or send test events to real webhook destinations.
9. Format, analyze, run the relevant package/app tests, and inspect the final
   diff for dependency scope and accidental network/request behavior changes.
10. Report selected features, files changed, exact verification commands and
    results, privacy/lifecycle decisions, unsupported body cases, and any
    remaining limitation. Do not commit or publish unless separately asked.

## 14. Test plan and acceptance criteria

### Core and privacy

- A normal log produces one queryable record with the expected type, ID, UTC
  acceptance time, source, tags, and JSON-compatible context.
- Invalid/cyclic/non-JSON context is rejected as a diagnostic drop and does not
  fail or alter the host operation.
- Redact-before-recording removes configured values before the store receives
  them. Store raw preserves them. Changing mode/policy affects only later
  records.
- Redacted export transforms a copy; stored data remains unchanged. As-stored
  export uses the stored representation. Policy failure never falls back to
  raw or emits partial export text.
- URI exclusions prevent records and sink output for matching HTTP requests,
  while the original request still reaches its server.
- Count retention removes oldest records according to the configured limit.

### HTTP adapters

- The original Dio instance is returned and its application response/error is
  unchanged. Attaching the same diagnostics twice does not duplicate capture.
- The HTTP wrapper is used for requests and closed once; requests through its
  original inner client bypass capture.
- Success, HTTP error response, network exception, retries, and URI exclusions
  produce the expected record count and local timing/ID metadata.
- Supported text/JSON/multipart metadata is represented correctly; stream and
  byte bodies are not consumed and are marked with the appropriate capture
  state.
- Tests verify the response stream remains readable by the application.

### Storage and lifecycle

- Memory mode is queryable immediately and disappears with process teardown.
- Drift mode writes, closes, and reopens at a test-owned temporary native path;
  verify retention, IDs, sessions, and migrations with the actual adapter.
- Persistence queue overflow and write failure are safe and produce warnings;
  no host operation is blocked or failed by diagnostics.
- Shutdown is idempotent, clients are closed by their application owner, and
  tests do not assert that pending writes are flushed by disposal.

### Sinks

- Test sink dispatch policies for LOG severity/tags and HTTP URI/status groups.
- Use fake `WebhookTransport`; never contact Discord/Telegram in tests.
- Verify payload redaction, one in-flight delivery per sink, drop-while-busy,
  cooldown/circuit behavior, warning sanitization, and disposal ownership.
- Confirm webhook secrets do not appear in logs, fixtures, source, or compiled
  public client configuration.

### Workspace verification commands

Run only the checks for changed/selected packages, from the workspace root with
the repository-pinned SDK. These commands are examples for this workspace; a
consumer app should also run its own project-level checks.

```sh
# Format the changed app/package Dart files.
.fvm/flutter_sdk/bin/dart format --output=none --set-exit-if-changed packages/codekit_core/lib packages/codekit_core/test

# Pure-Dart packages.
.fvm/flutter_sdk/bin/dart analyze packages/codekit_core
.fvm/flutter_sdk/bin/dart test packages/codekit_core/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_console
.fvm/flutter_sdk/bin/dart test packages/codekit_console/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_dio
.fvm/flutter_sdk/bin/dart test packages/codekit_dio/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_http
.fvm/flutter_sdk/bin/dart test packages/codekit_http/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit_webhook
.fvm/flutter_sdk/bin/dart test packages/codekit_webhook/test
.fvm/flutter_sdk/bin/dart analyze packages/codekit
.fvm/flutter_sdk/bin/dart analyze packages/colored_logger
.fvm/flutter_sdk/bin/dart test packages/colored_logger/test

# Drift: run tests from the package directory so its native-assets build hook runs.
.fvm/flutter_sdk/bin/dart analyze packages/codekit_drift_diagnostic_store
(cd packages/codekit_drift_diagnostic_store && ../../.fvm/flutter_sdk/bin/dart test)

# Flutter packages.
.fvm/flutter_sdk/bin/flutter analyze packages/codekit_flutter
.fvm/flutter_sdk/bin/flutter test packages/codekit_flutter/test
.fvm/flutter_sdk/bin/flutter analyze packages/codekit_ui
.fvm/flutter_sdk/bin/flutter test packages/codekit_ui/test

# Native export delivery tests, when changing that feature.
(cd packages/codekit_ui && ../../.fvm/flutter_sdk/bin/flutter test test_native)
```

Replace the sample formatter paths with the selected package/app paths that
changed. Run only commands for packages affected by the implementation.

A Web UI run requires Chrome and must be launched from the UI package directory
so Flutter resolves that package's local test path:

```sh
cd packages/codekit_ui
CHROME_EXECUTABLE=/path/to/chrome ../../.fvm/flutter_sdk/bin/flutter test --platform chrome test
```

HTTP adapter integration tests use the package suites and do not require a
production API. Webhook tests must use a fake transport or loopback fixture,
never real service credentials.

### Common integration mistakes

| Symptom | Likely cause / correct action |
| --- | --- |
| No HTTP records | The request used a different client, code still uses the original `package:http` client instead of the wrapper, or the URI matches an exclusion. |
| No webhook delivery | The sink's relevant `httpDispatchPolicy` or `logDispatchPolicy` is null, its policy excludes the record, or it is busy/cooling down. Configure explicit policies and inspect safe warnings. |
| Record is accepted but not in a persistent query yet | The write is still pending. Await that receipt's `persistedOrNull()` if the flow needs confirmation; do not assume pending records are queryable. |
| Body says unsupported | The adapter intentionally avoids consuming a stream or reading bytes. This is different from an empty body and must not be "fixed" by buffering the host response. |
| As-stored export still shows `[REDACTED]` | The record was redacted before it was stored. Removed values cannot be restored. |
| Bubble is absent in release | `debugOnly: true` hides it outside debug mode. Set the intended visibility explicitly. |
| Records disappear after restart | Memory storage is process-local. Select Drift on a supported native platform and provide a stable application-owned path. |
| Shutdown loses recent persistent records | Disposal is not a queue drain. Await individual confirmations where needed and design around best-effort writes. |

### Flutter hooks and viewer

- Verify existing callbacks are chained, CodeKit logs the error, and disposal
  restores only callbacks still owned by CodeKit.
- Verify the viewer receives the same diagnostics instance and navigator key.
- Test selection, search, filters, Trace controls/session scope, read-only
  settings, opt-in record-mode changes, export choice, and empty/missing-ID
  behavior.
- Test copy/share/file delivery with platform fakes; device share sheets still
  need native device QA where the app requires it.

## 15. Ready-to-use coding-agent prompt

Copy the prompt, keep only the selected checklist items, and give it to the
agent together with this complete guide.

```text
Implement the checked CodeKit features in the existing application. This guide
is the complete CodeKit integration contract for this task. Treat the checked
items as scope and do not add unchecked integrations.

Selected features:
HTTP capture (choose independently)
- [ ] Dio
- [ ] package:http

Storage (choose one)
- [ ] In-memory
- [ ] SQLite with Drift (native platforms only)

Diagnostic sinks (choose independently)
- [ ] Colored console
- [ ] Discord webhook
- [ ] Telegram bot

Flutter integrations (choose independently)
- [ ] In-app diagnostics viewer
- [ ] Flutter framework and root-isolate error capture

Record mode (choose one)
- [ ] Redact before recording
- [ ] Store raw

Before editing:
1. Inspect the target app's architecture, supported platforms/SDK, dependency
   source options, current Dio/package:http instances, global error handlers,
   navigation key, startup/shutdown owner, and verification commands.
2. Confirm selected CodeKit package versions are actually available to this
   app. The current workspace versions are unpublished. If no usable approved
   local/workspace/Git source exists, do not invent versions or dependency
   overrides; stop and report the exact blocker.
3. Use the API names and behavioral constraints in this guide. Verify imports
   and signatures against the selected package source before coding.

Implementation rules:
- Create one explicitly owned CodeKitDiagnostics instance. Do not add a
  global singleton or a second recorder for one app.
- Add only the selected packages. `codekit_core` is the shared foundation;
  optional adapters, storage, sinks, hooks, and UI stay optional.
- Preserve configured client instances and host behavior. Do not consume,
  buffer, or wrap response streams to improve capture. Keep request IDs local.
- Deliberately choose storage, count retention, redaction policy, URI exclusion,
  and record mode. Remember: Store raw is the default; exports default to
  Redacted; redaction cannot guarantee discovery of every secret.
- If Drift is selected, use a host-chosen native database path; Web uses
  memory in this MVP. Do not claim dispose flushes pending writes.
- If a webhook is selected, set explicit dispatch policies, keep credentials
  out of source and public client builds, and test only with a fake transport.
  Delivery is fire-and-forget, drops while busy/cooling, and does not retry.
- If Flutter hooks are selected, install after the app's own callbacks and
  dispose without overwriting callbacks another library installed later.
- If the viewer is selected, use the app's navigator key and same diagnostics
  instance. Make record-mode switching opt-in; policy and setup details remain
  read-only in the viewer.
- Wire ownership and cleanup into the existing lifecycle. Close app clients
  separately; dispose diagnostics once. Do not claim a persistence drain.
- Add focused tests with synthetic data; run format, analyzer, and relevant
  tests. Do not commit, publish, send real webhook requests, or make unrelated
  architecture changes.

At completion report: selected features, dependency source, files changed,
composition/lifecycle decisions, privacy configuration, capture limitations,
verification commands/results, and unresolved blockers.
```
