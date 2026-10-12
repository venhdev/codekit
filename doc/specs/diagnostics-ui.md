---
title: CodeKit Diagnostics UI
description: First UI contract for inspecting diagnostic records, managing Trace sessions, exporting records, and reusing recent searches.
status: active
created: 2026-10-10
updated: 2026-10-12
---

# CodeKit Diagnostics UI

## Purpose and ownership

This document owns user-facing behavior for the optional `codekit_ui` diagnostics interface. The [diagnostic data lifecycle](diagnostic-data-lifecycle.md) owns record, retention, Trace session, and export data semantics. The [system architecture](system-architecture.md) owns package boundaries and platform dependency direction.

The initial interface helps a developer inspect records, find relevant HTTP requests, select records for export, manage Trace sessions, and reuse recent searches. It is an optional Flutter UI; the Dart diagnostics core remains usable without it.

## Records view

The records view is the primary CodeKit screen opened from the CodeKit bubble. In list-only mode its leading action is Back, which exits CodeKit; its app bar contains Filters (`tune` icon) and Settings (`settings` icon). A record search bar sits immediately below the app bar, followed by Search history (`history` icon) and Reload (`refresh` icon). Icon-only controls provide accessible labels/tooltips.

The view provides:

- A text/regex search field over LOG message/source/error message and HTTP method/URI/source/error message. It does not search headers, bodies or context; body inspection retains its separate search.
- A filter sheet opened from the app-bar Filters icon. The result count appears beneath the search bar; do not duplicate the filter control with a second Filters button in the results row.
- While cursor pagination has more pages, the visible count is a lower bound (for example, `128+ matching`); the UI does not run a separate full-count scan on every search.
- Multi-select status chips for `1xx`, `2xx`, `3xx`, `4xx`, `5xx`, and `Unknown` (missing/out-of-range HTTP status and app logs); a from/to time range; duration categories (`fast`, `normal`, `warn`, `slow`, and no-duration); and record type (`app log` or `HTTP`).
- The main list has two modes. **List-only** is the default: rows open details and do not show checkboxes or bulk actions. Long-pressing a row enters **Selection** mode and selects that row. Selection mode shows checkboxes, a selected count, and bulk export/delete actions; the leading action becomes Close (`X`) and clears selection on exit. Row taps then toggle selection. It has no Done or app-bar multi-select action.
- Pull-to-refresh reloads the list in list-only mode. Reload has the same result and remains beside Search history for an explicit refresh.
- Explicit export actions for selected records or all records matching the current search and filters are available only in Selection mode. Searching or filtering alone does not export data.

Recent searches can be reapplied from Search history. Search regex is a view filter; endpoint exclusion regex prevents capture and does not select export results.

Rows use distinct layouts by record type:

- **HTTP:** the first line shows record type, status code, duration, and timestamp. Duration is shown as a value such as `42 ms`; its chip background color represents the duration level. The second line shows method and URI, with the method/URI area limited to two lines. A concise request/response summary may follow when available. The stable record ID is available in record details.
- **App log:** show type and log level with timestamp, followed by a concise message preview and source when available.

Changing search/filter or reloading clears the record selection, avoiding invisible selected records.

Tapping a row opens its record details. In Selection mode, its row or checkbox independently adds or removes the record from the current multi-selection; there is no persistent preview pane on the main screen.

## Record details and HTTP inspector

HTTP details keep the request/response summary (method, URI, status, duration, start time, source and error) above **Request** and **Response** tabs. Each tab owns only its corresponding headers and body. Headers start collapsed; body starts expanded. Structured body inspection offers JSON Tree, Pretty and Raw views, search, and expand/collapse controls. Non-JSON content remains viewable without requiring JSON parsing. If body capture was disabled, unsupported by the client, data was not captured, or values were redacted, the UI communicates the available state rather than reading data again from the network or local files.

Record ID, recorded timestamp and record mode are intentionally not shown in the detail body. The app-bar information action opens a dialog containing that package metadata. Copy headers is shown only when the tab has headers; Copy body is shown only for a captured, nonempty body. Copy cURL remains available from the HTTP summary.

Copy/export surfaces support complete one-or-more records or app logs, and individual HTTP bodies, headers and cURL. Every payload copy/share/export asks the user to choose Redacted or As stored before output, using the [data disclosure contract](diagnostic-data-lifecycle.md#export-and-data-disclosure). This includes Copy cURL. A fragment confirmation only needs representation choice; full-record Confirm Export offers COPY/SHARE with a SHARE-only file checkbox.

The initial copy scope is full body, headers and cURL. Copying JSON subtrees is deferred; JSON tree inspection remains in scope. cURL is generated on demand according to the lifecycle contract, and the UI identifies representations that lack data needed for replay.

## Confirm Export

The export confirmation presents the two data representations defined by the [diagnostic data lifecycle](diagnostic-data-lifecycle.md): **Redacted** and **As stored**. Redacted export operates on an export copy and never edits stored records. As stored exports the stored representation; records redacted before recording remain redacted.

The dialog receives selected IDs, including selections obtained from search/filter or Trace sessions. It offers full-width COPY and SHARE actions in the content: COPY is outlined with a secondary-container background, while SHARE is a filled primary action. COPY copies the chosen text representation regardless of the file checkbox. SHARE shares text by default; its optional “Share as file (.txt)” checkbox sits directly beneath SHARE and affects SHARE only. Cancel is the only dialog-footer action. Native file share uses a temporary text file; Web file output downloads a .txt file without dart:io. Browser text-share availability must be checked and reported clearly; no fallback behavior is presumed here. A dismissed share sheet leaves the dialog open without a success message; unavailable sharing reports an error.

Redacted is selected by default and file creation is unchecked. Export is unlimited in record count/size. There is no required progress/cancel scheduler, worker/isolate or database-snapshot feature in MVP. Very large selections remain a runtime measurement concern.

## Trace sessions

The records status row has quick Trace controls: its Trace chip opens the sessions sheet, its adjacent Start/Stop control toggles manual capture, and an active chip shows the count of accepted IDs in the current capture. In Selection mode, the count remains visible when active but controls are read-only. The Trace sessions bottom sheet is 55% of the viewport height and scrolls its contents. It lists saved sessions, offers a create action, and exposes manual Start/Stop capture controls. Tapping a session scopes the records view to its saved IDs; active search and filters are intersected with that scope, and All matching export remains scoped. A session can be exported directly from the list or explicitly deleted through its actions menu after confirmation. Creating a picker-based session selects an inclusive time interval `[from, to]`, previews the currently queryable record count, and references all retained diagnostic record IDs in that interval.

Picker-created and manually captured sessions appear in the same list. Manual Stop stores the accepted ID list without waiting for persistence; picker creation uses queryable records, as specified by the [Trace lifecycle](diagnostic-data-lifecycle.md#trace-sessions). Counts shown in the session list describe saved IDs, not a guarantee of currently available records. Manual capture remains active when the sheet closes; reopening shows Stop capture.

Session export and session-scoped viewing use only IDs that currently resolve. A visible Trace scope chip clears the scope. When no records resolve during export, show a message and offer Delete session or Cancel; never delete automatically or create an empty file/clipboard export. Do not perform background completeness checks or remove sessions when their records disappear.

## Search history

Search history opens from the search bar's history icon. Its bottom sheet is 55% of the viewport height and scrolls its contents. It holds the 20 most recent searches in UI memory only; it is lost on process restart and is not stored by DiagnosticStore.

An item contains only query text and text/regex mode. Save on explicit submission of a valid, nonempty search, not on every keystroke. Submitting an identical query and mode moves its existing item to the top; there are no duplicates. Matching history identity uses the submitted query text and mode, not search-result equivalence.

Tap an item to reapply its query/mode while retaining current filters and move it to the most-recent position. Clear all leaves an empty list. There is no pin, rename, per-item deletion, general action model or action replay engine in MVP. Configuration changes, exports, deletion and Trace actions are not tracked in this history. This replaces the earlier Recent actions design, rather than adding a second history.

## Bottom sheets

Filters, Settings, Trace sessions and Search history use the same bottom-sheet container. It opens at 55% of the viewport height, scrolls its body, includes a drag handle, can be dragged down to dismiss, and has an explicit Close control. Each feature supplies only its body and optional persistent actions.

## Viewer settings

The optional `CodeKitViewerSettings` configuration lets a host expose factual, read-only setup details in the Settings sheet (for example storage backend, attached adapters and Flutter hooks). The sheet always displays the active `RedactionPolicy`, including header presets and configured rules, as read-only data.

Changing record mode at runtime is opt-in through `allowRuntimeRecordModeChanges`; if enabled, the sheet offers Store raw and Redact before recording. The choice applies only to subsequently accepted records. Redaction rules, endpoint exclusions, retention, storage and adapter attachment remain host configuration and are not editable from the viewer.

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
│ [←] CodeKit                [tune][settings]│
│ [Search records: text / regex ] [history][⟳]│
└──────────────────────────────────┘
```

### Records screen

```text
┌──────────────────────────────────┐
│ [←] CodeKit                [tune][settings]│
│ [Search records: text / regex ] [history][⟳]│
├──────────────────────────────────┤
│ 128 matching  [Trace off] [Start]│  List-only mode
├──────────────────────────────────┤
│ [HTTP] [500] [1820 ms] 10:42:18  │
│ GET /users/42                    │
│   Request failed                 │
├──────────────────────────────────┤
│ [LOG] [ERROR]          10:42:11  │
│ Failed to load user profile      │
│ AuthService                      │
├──────────────────────────────────┤
│ [HTTP] [200] [42 ms]   10:41:59  │
│ GET /health                      │
└──────────────────────────────────┘
```

Long-pressing a row enters selection mode, selects it, and adds checkboxes, `N selected`, and the Export selected, All matching and Delete actions. Its leading Back action becomes Close (`X`); leaving mode clears selection. The duration chip background conveys its speed level; the displayed duration remains visible as text. There is no persistent preview pane.

### HTTP details and fragment copy

```text
┌──────────────────────────────────┐
│ [×] HTTP GET /users/42       [i] │
│ GET /users/42 · Status 500        │
│ Duration 1820 ms · [Copy cURL]    │
│ [Request] [Response]              │
├──────────────────────────────────┤
│ Status 500 · Duration 1820 ms     │
│ ▸ Headers                         │  collapsed by default
│ ▾ Body [Tree] [Pretty] [Raw]      │  expanded by default
│ [Search JSON] [Expand] [Collapse] │
│ ... body content ...             │
│                       [Copy body]│
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

The information action opens ID, recorded time and record mode in a dialog. A tab only shows Copy headers/body when its respective data is available. Fragment copy asks for representation on each action. Full-record export uses the Confirm Export dialog below.

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
│ [Close]                          │
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

Tap a session row to apply its saved-ID scope to the records list; use the Trace chip in the records view to clear it.

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
│ [Close]                          │
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
