---
title: CodeKit Diagnostics UI
description: First UI contract for inspecting diagnostic records, managing Trace sessions, exporting records, and reusing recent searches.
status: active
created: 2026-10-10
updated: 2026-10-11
---

# CodeKit Diagnostics UI

## Purpose and ownership

This document owns user-facing behavior for the optional `codekit_ui` diagnostics interface. The [diagnostic data lifecycle](diagnostic-data-lifecycle.md) owns record, retention, Trace session, and export data semantics. The [system architecture](system-architecture.md) owns package boundaries and platform dependency direction.

The initial interface helps a developer inspect records, find relevant HTTP requests, select records for export, manage Trace sessions, and reuse recent searches. It is an optional Flutter UI; the Dart diagnostics core remains usable without it.

## Records view

The records view is the primary CodeKit screen opened from the CodeKit bubble. Its app bar contains Close, Trace sessions (`timeline` icon), Filters (`tune` icon), and Reload (`refresh` icon). A record search bar sits immediately below the app bar; its trailing Search history (`history` icon) control opens the search-reuse history. Icon-only controls provide accessible labels/tooltips.

The view provides:

- A text/regex search field over LOG message/source/error message and HTTP method/URI/source/error message. It does not search headers, bodies or context; body inspection retains its separate search.
- A filter sheet opened from the app-bar Filters icon. The result count appears beneath the search bar; do not duplicate the filter control with a second Filters button in the results row.
- While cursor pagination has more pages, the visible count is a lower bound (for example, `128+ matching`); the UI does not run a separate full-count scan on every search.
- Multi-select status chips for `1xx`, `2xx`, `3xx`, `4xx`, `5xx`, and `Unknown` (missing/out-of-range HTTP status and app logs); a from/to time range; duration categories (`fast`, `normal`, `warn`, `slow`, and no-duration); and record type (`app log` or `HTTP`).
- Multi-select record selection and a visible selected count.
- Explicit export actions for selected records or all records matching the current search and filters. Searching or filtering alone does not export data.

Recent searches can be reapplied from Search history. Search regex is a view filter; endpoint exclusion regex prevents capture and does not select export results.

Rows use distinct layouts by record type:

- **HTTP:** the first line shows record type, status code, duration, and timestamp. Duration is shown as a value such as `42 ms`; its chip background color represents the duration level. The second line shows method and URI, with the method/URI area limited to two lines. A concise request/response summary may follow when available. The stable record ID is available in record details.
- **App log:** show type and log level with timestamp, followed by a concise message preview and source when available.

Changing search/filter or reloading clears the record selection, avoiding invisible selected records.

Tapping a row opens its record details. Its checkbox independently adds or removes the record from the current multi-selection; there is no persistent preview pane on the main screen.

## Record details and HTTP inspector

HTTP details provide an overview, request and response headers and bodies, and error details when available. Structured body inspection offers JSON Tree, Pretty and Raw views, search, and expand/collapse controls. Non-JSON content remains viewable without requiring JSON parsing. If body capture was disabled, data was not captured, or values were redacted, the UI communicates the available state rather than reading data again from the network or local files.

Copy/export surfaces support complete one-or-more records or app logs, and individual HTTP bodies, headers and cURL. Every payload copy/share/export asks the user to choose Redacted or As stored before output, using the [data disclosure contract](diagnostic-data-lifecycle.md#export-and-data-disclosure). This includes Copy cURL. A fragment confirmation only needs representation choice; full-record Confirm Export offers COPY/SHARE with a SHARE-only file checkbox.

The initial copy scope is full body, headers and cURL. Copying JSON subtrees is deferred; JSON tree inspection remains in scope. cURL is generated on demand according to the lifecycle contract, and the UI identifies representations that lack data needed for replay.

## Confirm Export

The export confirmation presents the two data representations defined by the [diagnostic data lifecycle](diagnostic-data-lifecycle.md): **Redacted** and **As stored**. Redacted export operates on an export copy and never edits stored records. As stored exports the stored representation; records redacted before recording remain redacted.

The dialog receives selected IDs, including selections obtained from search/filter or Trace sessions. It offers two actions: COPY and SHARE. COPY copies the chosen text representation regardless of the file checkbox. SHARE shares text by default; its optional “Share as file (.txt)” checkbox sits directly beneath that action and affects SHARE only. Native file share uses a temporary text file; Web file output downloads a .txt file without dart:io. Browser text-share availability must be checked and reported clearly; no fallback behavior is presumed here.

Redacted is selected by default and file creation is unchecked. Export is unlimited in record count/size. There is no required progress/cancel scheduler, worker/isolate or database-snapshot feature in MVP. Very large selections remain a runtime measurement concern.

## Trace sessions

The Trace sessions bottom sheet is 55% of the viewport height and scrolls its contents. It lists saved sessions, offers a create action, and exposes manual Start/Stop capture controls. A session can be exported directly from the list or explicitly deleted through its actions menu after confirmation. Creating a picker-based session selects an inclusive time interval `[from, to]`, previews the currently queryable record count, and references all retained diagnostic record IDs in that interval.

Picker-created and manually captured sessions appear in the same list. Manual Stop stores the accepted ID list without waiting for persistence; picker creation uses queryable records, as specified by the [Trace lifecycle](diagnostic-data-lifecycle.md#trace-sessions). Counts shown in the session list describe saved IDs, not a guarantee of currently available records. Manual capture remains active when the sheet closes; reopening shows Stop capture.

Session export uses only IDs that currently resolve. When no records resolve, show a message and offer Delete session or Cancel; never delete automatically or create an empty file/clipboard export. Do not perform background completeness checks or remove sessions when their records disappear.

## Search history

Search history opens from the search bar's history icon. Its bottom sheet is 55% of the viewport height and scrolls its contents. It holds the 20 most recent searches in UI memory only; it is lost on process restart and is not stored by DiagnosticStore.

An item contains only query text and text/regex mode. Save on explicit submission of a valid, nonempty search, not on every keystroke. Submitting an identical query and mode moves its existing item to the top; there are no duplicates. Matching history identity uses the submitted query text and mode, not search-result equivalence.

Tap an item to reapply its query/mode while retaining current filters and move it to the most-recent position. Clear all leaves an empty list. There is no pin, rename, per-item deletion, general action model or action replay engine in MVP. Configuration changes, exports, deletion and Trace actions are not tracked in this history. This replaces the earlier Recent actions design, rather than adding a second history.

## Record deletion

Deleting selected records requires a confirmation dialog stating the selected record count. Trace sessions are unaffected. Clear/delete behavior for pending writes is owned by the [record lifecycle](diagnostic-data-lifecycle.md#record-deletion-and-disposal): Clear may be followed by completion of earlier writes.

## Wireframe previews

These ASCII wireframes illustrate the agreed layout and entry points. The behavioral sections above remain authoritative if a visual detail is later refined.

### Open CodeKit from the application bubble

```text
┌──────────────────────────────────┐
│                                  │
│        Application screen        │
│                                  │
│                            (●)   │  CodeKit bubble
└──────────────────────────────────┘
                 tap
                  ▼
┌──────────────────────────────────┐
│ [×] CodeKit [timeline][tune][⟳]  │
│ [Search records: text / regex ] [history]
└──────────────────────────────────┘
```

### Records screen

```text
┌──────────────────────────────────┐
│ [×] CodeKit [timeline][tune][⟳]  │
│ [Search records: text / regex ] [history]
├──────────────────────────────────┤
│ 128 matching · 2 selected        │
├──────────────────────────────────┤
│ ☑ [HTTP] [500] [1820 ms] 10:42:18│
│   GET /users/42                  │
│   Request failed                 │
├──────────────────────────────────┤
│ ☑ [LOG] [ERROR]          10:42:11│
│   Failed to load user profile    │
│   AuthService                    │
├──────────────────────────────────┤
│ ☐ [HTTP] [200] [42 ms]   10:41:59│
│   GET /health                    │
├──────────────────────────────────┤
│ [Export selected] [All matching] │
│                         [Delete] │
└──────────────────────────────────┘
```

The duration chip background conveys its speed level; the displayed duration remains visible as text. Tapping a row opens record details; tapping its checkbox changes multi-selection. There is no persistent preview pane.

### HTTP details and fragment copy

```text
┌──────────────────────────────────┐
│ [×] HTTP GET /users/42            │
│ [Overview] [Request] [Response]   │
│ [cURL]                           │
├──────────────────────────────────┤
│ Status 500 · Duration 1820 ms     │
│ Request / response headers       │
│                    [Copy headers]│
│ Body: [Tree] [Pretty] [Raw]       │
│ [Search JSON] [Expand] [Collapse] │
│ ... body content ...             │
│                       [Copy body]│
│                       [Copy cURL]│
└──────────────────────────────────┘
                 copy
                  ▼
┌──────────────────────────────────┐
│ Copy body / headers / cURL        │
│ ( ) Redacted                     │
│ ( ) As stored                    │
│ [Cancel]                  [Copy] │
└──────────────────────────────────┘
```

Fragment copy asks for representation on each action. Full-record export uses the Confirm Export dialog below.

### Filters sheet

```text
┌──────────────────────────────────┐
│              ─────               │
│ Filters                    [Done]│
├──────────────────────────────────┤
│ Status                           │
│ [1xx] [2xx] [3xx] [4xx] [5xx] [Unknown]
│                                  │
│ Time range                       │
│ From [ date / time ]             │
│ To   [ date / time ]             │
│                                  │
│ Duration                         │
│ [Fast] [Normal] [Warn] [Slow] [None]
│                                  │
│ Record type                      │
│ [App log] [HTTP record]          │
│                         [Reset]  │
└──────────────────────────────────┘
```

### Confirm Export dialog

```text
┌──────────────────────────────────┐
│ Confirm export                   │
├──────────────────────────────────┤
│ 2 records selected               │
│                                  │
│ (●) Redacted                     │
│ ( ) As stored                    │
│                                  │
│ [COPY]                           │
│                                  │
│ [SHARE]                          │
│ [ ] Share as file (.txt)          │
│                                  │
│ [Cancel]                         │
└──────────────────────────────────┘
```

COPY ignores the file checkbox. SHARE shares text when unchecked; when checked it shares a temporary file on native or downloads .txt on Web.

### Trace sessions sheet — 55% viewport height

```text
┌──────────────────────────────────┐
│              ─────               │
│ Trace sessions       [+ Create]  │
│          height: 55% viewport    │
├──────────────────────────────────┤
│ [Start capture]                  │
│ Active: 00:01:24          [Stop] │
├──────────────────────────────────┤
│ 10:30–10:42 · 86 saved IDs       │
│                         [Export] │
├──────────────────────────────────┤
│ 09:15–09:20 · 12 saved IDs       │
│                         [Export] │
└──────────────────────────────────┘
```

### Trace export with no available records

```text
┌──────────────────────────────────┐
│ No records available             │
│                                  │
│ None of this session's saved IDs │
│ currently resolve to records.    │
│                                  │
│ [Cancel]        [Delete session] │
└──────────────────────────────────┘
```

Deletion requires an explicit user action; missing IDs alone never delete the session.

### Create Trace session picker

```text
┌──────────────────────────────────┐
│ Create Trace session             │
├──────────────────────────────────┤
│ From [ date / time ]             │
│ To   [ date / time ]             │
│                                  │
│ Records in range: 86             │
│ [Cancel]                 [Create]│
└──────────────────────────────────┘
```

### Search history sheet — 55% viewport height

```text
┌──────────────────────────────────┐
│              ─────               │
│ Search history        [Clear all]│
│          height: 55% viewport    │
├──────────────────────────────────┤
│ [Regex] /payments/.*             │
├──────────────────────────────────┤
│ [Text] Payment failed            │
├──────────────────────────────────┤
│ [Regex] timeout|connection       │
└──────────────────────────────────┘
```

Tap a row to reuse its query and mode; existing filters remain unchanged.

### Delete confirmation

```text
┌──────────────────────────────────┐
│ Delete 2 records?                │
│                                  │
│ Delete the selected records.    │
│ Saved Trace sessions are kept.  │
│                                  │
│                                  │
│ [Cancel]                [Delete]│
└──────────────────────────────────┘
```

The `1xx` and `Unknown` chips use neutral colors. The CodeKit bubble is placed in `MaterialApp.builder` with the same `navigatorKey` as the app; it remains available across app routes and is hidden while the viewer is open.
