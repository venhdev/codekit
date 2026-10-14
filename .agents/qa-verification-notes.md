# CodeKit QA and Verification Records

This document records transient verification evidence, test run outcomes, and platform QA status across development milestones. For durable product milestones, see [`doc/roadmap.md`](../doc/roadmap.md). For task execution conventions, see [`.agents/task-tracker.md`](task-tracker.md).

## Milestone 3: Inspection and Export QA Evidence

- **Automated Verification**:
  - VM widget tests passing (`packages/codekit_ui/test`).
  - Chrome web widget tests passing (`flutter test --platform chrome`).
  - Chrome runtime test verified file export: downloaded and validated `.txt` record export format without `dart:io`.
  - Mock-platform tests verify native temporary file creation and platform channel invocation.
- **Pending Physical Device Verification**:
  - Android system share sheet UX verification on physical device.
  - iOS system share sheet UX verification on physical device.

## Milestone 6: Pub Workspace Publishing Preflight

- **Workspace Preflight Check**:
  - All 10 workspace packages verified via `fvm dart pub publish --dry-run` with 0 warnings on a clean Git working tree.
  - Workspace guard `publish_to: none` preserved in package manifests until formal versioned release approval.
