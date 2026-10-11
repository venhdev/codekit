---
title: Dependency Compatibility and Engineering Scout
description: Evidence for dependency versions and selective reuse of Memozen engineering practices.
status: draft
created: 2026-10-11
updated: 2026-10-11
---

# Dependency Compatibility and Engineering Scout

## Scope and recommendation

Use the installed Flutter toolchain to resolve the shared dependency graph, including SDK-pinned test dependencies. The [version registry](../techstack.md) owns the proposed baseline versions; this report owns research evidence and recommendations, not architecture or engineering requirements.

The core needs no new runtime dependency for the currently approved contracts. Dio belongs in its adapter; sharing, native temporary-directory lookup and browser download APIs belong in UI/platform code. `http` is a proposed webhook client, not a selected transport. Following design approval, Drift is the selected native MVP backend under the [system architecture](../specs/system-architecture.md#system-boundaries). No production manifests or packages were created by this scout.

## Compatibility evidence

On 2026-10-11, the installed `.fvm/flutter_sdk` reported Flutter 3.47.0 and Dart 3.13.0. Official Pub package metadata supplied available versions and SDK constraints. A disposable Flutter project under `.agents/scratch/deps-scout/` resolved the proposed direct dependency set together, including Flutter tests and the conditional Drift generator dependencies, without dependency overrides.

| Probe | Result | Implication |
| :--- | :--- | :--- |
| Proposed runtime dependencies plus compatible development dependencies | `flutter pub get` succeeded | One combined graph is resolvable with the installed SDK. |
| Force `test 1.33.0` with SDK `flutter_test` | Resolution failed: `test_api 0.7.15` versus SDK-pinned `0.7.12` | Use the compatible test release in the version registry. |
| Force `build_runner 2.16.2` with compatible `test` | Resolution failed: analyzer `^14.3.0` versus `>=8.0.0 <14.0.0` | Use the compatible generator runner in the version registry if Drift is selected. |

Pub resolution verifies dependency constraints, not platform compilation, browser persistence, file sharing, migrations, or runtime behavior. The scratch project is a combined compatibility probe, not the production package dependency map. Native share plugin build requirements still need platform-specific verification when UI manifests are introduced.

The registry contains baseline versions, not pubspec constraint syntax or transitive pins. Production member manifests will declare compatible constraints; the workspace root lockfile will own the actual resolved graph. Do not add direct dependencies merely because they appeared transitively in this probe. In particular, selecting a SQLite opener and Web assets remains part of the storage design, rather than a consequence of resolving Drift.

The `colored_logger` entry reports the existing local manifest version. It was not part of the registry-package compatibility probe; its platform imports and migration remain separate work. `type_caster`, `intl`, Riverpod, Freezed, and a UUID package are not introduced by this report.

## Primary evidence

| Source | Evidence used |
| :--- | :--- |
| [Dio package metadata](https://pub.dev/api/packages/dio) | Adapter release and SDK constraints. |
| [Drift package metadata](https://pub.dev/api/packages/drift) | Storage candidate release and SDK constraints. |
| [share_plus package metadata](https://pub.dev/api/packages/share_plus) | UI sharing release and Dart/Flutter constraints. |
| [test package metadata](https://pub.dev/api/packages/test) | Test release and exact `test_api` dependency. |
| [build_runner package metadata](https://pub.dev/api/packages/build_runner) | Generator runner release and analyzer dependency. |

Other direct package versions were read from their official Pub metadata endpoints and verified in the same resolver probe. Local evidence consists of the installed SDK version output, scratch `registry.json`, scratch `pubspec.yaml` and `pubspec.lock`, and the resolver diagnostics above. Scratch artifacts are ignored and are not durable specification owners.

## Selective reuse from Memozen

Memozen source paths below are relative to that repository, not CodeKit dependencies. They identify research inputs only; CodeKit should own any adopted rule locally.

| Memozen input | Recommendation for CodeKit | Adjustment |
| :--- | :--- | :--- |
| `docs/README.md`: single documentation ownership | Reuse | Already established by the CodeKit documentation index; avoid another master architecture document. |
| `docs/architecture/client-mobile/mobile-architecture.md`: framework-free kernel | Reuse principle | Preserve pure Dart core, immutable snapshots and inward dependencies. Use the existing package boundaries; omit app layers and performance promises without measurement. |
| `docs/architecture/standards/code-quality-standards.md`: analysis and formatting | Reuse with adaptation | Analyze without rewriting files; format separately. Use Dart commands for Dart packages and Flutter commands for Flutter packages. Generated files are verified through generation and compilation, not hand editing. |
| `docs/architecture/standards/naming-and-identifiers.md`: naming and collisions | Reuse with adaptation | PascalCase types, lowerCamelCase members and Dart constants, snake_case files, descriptive identifiers and positive boolean names. Do not decide codec field naming through an app naming standard. |
| Same naming document: mandatory architectural suffixes | Omit | Do not require Command/Query/Orchestrator/Repository types unless the actual responsibility warrants them. |
| `docs/architecture/standards/testing-standards.md`: deterministic outcome-based tests | Reuse with adaptation | Control clocks and async completion; verify behavior, boundaries and transitions. Use small typed fixtures where repetition warrants them. Codec expectations should use independently specified wire literals. |
| Same testing document: exhaustive dimensions and app integration stack | Omit | No mandatory test proportions, banners, PostgreSQL/Testcontainers, authentication matrix, or transactional-outbox guarantees. Choose relevant contract tests. |
| Root and mobile architecture: feature-first app hierarchy, Riverpod, offline-first database authority | Omit | CodeKit is a library ecosystem with optional storage and best-effort recording, not a synchronized end-user app. |
| `AGENTS.md`: app stack locks and workflow gates | Omit | Memozen-specific instructions do not become CodeKit standards. |

## Proposed documentation ownership and next design steps

If adopted, use one `doc/standards/engineering-standards.md` for naming, analysis, formatting and general test discipline. Register it in the documentation index and link testing guidance from `.agents/harness-anchor.md`. This report proposes that document; it does not establish those recommendations as requirements yet.

Keep package boundaries in system architecture, serialization in record schema, queue/retention/redaction behavior in lifecycle, and interaction rules in UI. In particular, preserve the approved best-effort FIFO queue, reject-new overflow, no retry/fallback, disposal without draining, simple dotted object redaction paths, and Trace export that skips missing IDs.

Continue architectural clarification for the native Drift platform openers, webhook transport, supported consumer SDK minimums, native/Web build requirements and complete codec field coverage. Do not copy Memozen versions without resolving them against CodeKit's toolchain.
