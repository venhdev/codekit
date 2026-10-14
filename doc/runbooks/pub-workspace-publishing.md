---
title: Publish Packages from a Pub Workspace
description: Release CodeKit workspace members individually through the standard Dart Pub workflow.
status: active
created: 2026-10-10
updated: 2026-10-14
---

# Publish Packages from a Pub Workspace

This runbook is the operational source of truth for publishing CodeKit packages developed in a Dart Pub workspace. It applies after the planned development work is complete. It does not authorize prereleases during development.

The [CodeKit roadmap](../roadmap.md) owns product milestones. The `/ci-pub` workflow owns release quality checks and version approval. This runbook owns Pub workspace validation, package ordering, and the publish commands.

## Package CI and release tags

GitHub Actions verifies only workspace packages with changed files. Changes to
the root workspace manifest or lockfile, SDK pin, shared analysis options, or
CI workflows trigger verification for all packages. Verification runs format,
analysis, and tests from each selected package directory after resolving the
shared workspace from the root: pure-Dart packages run `dart analyze --fatal-infos`
and `dart test`, while Flutter packages (`codekit_flutter` and `codekit_ui`)
run `flutter analyze --fatal-infos` and `flutter test` (plus `flutter test test_native`
for `codekit_ui`). `example` remains a workspace member but is not
a CI target: its source is not built, analyzed, tested, or published.

Release tags identify one package and its manifest version using
`<package-name>-v<version>`, for example `codekit_core-v0.1.1`. The publish
workflow rejects a tag unless its package name and version match that package's
`pubspec.yaml`. Each tag publishes one package; when releasing dependent
packages together, create tags and publish in dependency order.

## Preconditions

- All packages in the release scope are complete, and their tests, formatting, and changelogs are ready for the `/ci-pub` preflight.
- Version selection and manifest/changelog updates have passed the `/ci-pub` approval gate.
- The workspace root is private (`publish_to: none`); each publishable member has its own valid `pubspec.yaml`.
- Members remain `publish_to: none` during development. Remove that guard only from packages explicitly approved for a release, then repeat the dry-run and clean-tree checks before upload.
- Every workspace member's Dart SDK constraint matches the workspace toolchain (`>=3.13.0 <4.0.0`), and internal dependency constraints accept the versions declared by local workspace members.
- The release changes are committed and the Git working tree is clean before publication.

## Compatibility and order

The first CodeKit diagnostics release uses `0.1.0` for new packages. Their
internal `^0.1.0` constraints accept compatible 0.1.x updates, but a 0.2.0
breaking contract change requires coordinated dependent-package updates.
`colored_logger` is a separate, previously published package and advances to
2.2.0 for the Web-safe terminal fallback. The `codekit` umbrella is also
previously published; its 0.1.0 redesign does not preserve the 0.0.x utility
API. Existing consumers must migrate deliberately.

Release order follows dependencies: `codekit_core` and `colored_logger` first;
then `codekit_console`, `codekit_dio`, `codekit_http`,
`codekit_drift_diagnostic_store`, `codekit_webhook`, `codekit_flutter` and
`codekit_ui`; `codekit` last. Peer packages in the middle can be released in
any order once their dependencies are available.

## Procedure

1. **Complete release preflight.** Run `/ci-pub` for the release scope. Stop if tests, formatting, changelog review, or version approval fails. Do not upload packages until all planned development is complete.
2. **Confirm workspace membership.** Run `fvm dart pub workspace list` from the repository and check that every package intended for release appears in the list.
3. **Dry-run every package.** Ensure the Git working tree is completely clean before running validation. For each package in the release scope, run `fvm dart pub -C packages/<package> publish --dry-run`. Review the included file list and resolve every warning or error before continuing.
4. **Order packages by dependency.** Publish depended-on packages before packages that depend on them. Confirm that each internal version constraint accepts the dependency's release version.
5. **Publish each package individually.** Create and push `<package>-v<version>` for each approved package, following the dependency order. The GitHub Actions publish workflow validates the tagged package, runs `publish --dry-run`, then publishes from `packages/<package>` through pub.dev OIDC. Pub publishes the package in the selected directory; the workspace is not one atomic release.
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
