---
title: Publish Packages from a Pub Workspace
description: Release CodeKit workspace members individually through the standard Dart Pub workflow.
status: draft
created: 2026-10-10
updated: 2026-10-10
---

# Publish Packages from a Pub Workspace

This runbook is the operational source of truth for publishing CodeKit packages developed in a Dart Pub workspace. It applies after the planned development work is complete. It does not authorize prereleases during development.

The [CodeKit roadmap](../roadmap.md) owns product milestones. The `/ci-pub` workflow owns release quality checks and version approval. This runbook owns Pub workspace validation, package ordering, and the publish commands.

## Preconditions

- All packages in the release scope are complete, and their tests, formatting, and changelogs are ready for the `/ci-pub` preflight.
- Version selection and manifest/changelog updates have passed the `/ci-pub` approval gate.
- The workspace root is private (`publish_to: none`); each publishable member has its own valid `pubspec.yaml`.
- Every workspace member's Dart SDK constraint is at least `^3.6.0`, and internal dependency constraints accept the versions declared by local workspace members.
- The release changes are committed and the Git working tree is clean before publication.

## Procedure

1. **Complete release preflight.** Run `/ci-pub` for the release scope. Stop if tests, formatting, changelog review, or version approval fails. Do not upload packages until all planned development is complete.
2. **Confirm workspace membership.** Run `fvm dart pub workspace list` from the repository and check that every package intended for release appears in the list.
3. **Dry-run every package.** For each package in the release scope, run `fvm dart pub -C packages/<package> publish --dry-run`. Review the included file list and resolve every warning or error before continuing.
4. **Order packages by dependency.** Publish depended-on packages before packages that depend on them. Confirm that each internal version constraint accepts the dependency's release version.
5. **Publish each package individually.** Run `fvm dart pub -C packages/<package> publish` for each package, following the dependency order. Pub publishes the package in the selected directory; the workspace is not one atomic release.
6. **Handle propagation delays safely.** If a newly published dependency is not yet available during validation of a dependent package, wait and retry. Do not use `--skip-validation` in the normal release path because it bypasses client-side checks and dependency resolution.
7. **Record completion.** Confirm the released versions on pub.dev and update the relevant task/release records.

## Workspace behavior and failure points

- Pub resolves an internal dependency to its workspace member during development, while the dependency's declared version constraint must still match that member's version. Consumers outside the workspace resolve according to the published package's declared dependency source and constraint.
- A workspace uses one shared dependency resolution, so incompatible version requirements across members can prevent `pub get` even when the packages might otherwise be released separately.
- `fvm dart pub publish --dry-run` validates a package and previews its archive without uploading it. Inspect this output for every package; the workspace root lockfile and other workspace-only files are not part of the selected member's package archive.
- Publishing several members is not atomic. If a later package fails, earlier packages may already be released; dry-run all packages before the first upload.

## References

- [Dart Pub workspaces](https://dart.dev/tools/pub/workspaces)
- [`dart pub publish`](https://dart.dev/tools/pub/cmd/pub-lish)
- [Publishing packages](https://dart.dev/tools/pub/publishing)
