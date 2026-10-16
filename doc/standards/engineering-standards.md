---
title: CodeKit Engineering Standards
description: Cross-cutting code design, reuse, implementation, formatting and verification rules for CodeKit.
status: active
created: 2026-10-11
updated: 2026-10-16
---

# CodeKit Engineering Standards

## Scope and authority

This document owns cross-cutting engineering practices for CodeKit packages. It
guides implementation quality without replacing package boundaries in the
[system architecture](../specs/system-architecture.md), public contracts in
their package specifications, or test-harness details in the
[harness anchor](../../.agents/harness-anchor.md). When guidance here conflicts
with an approved package contract, resolve the conflict before changing either
the implementation or its documentation.

## Enums and case-specific behavior

- Keep enums simple when their cases only name a closed set of alternatives.
- Use an enhanced enum when cases own stable associated values or behavior that
  makes the domain easier to understand at its call sites. Do not enhance every
  enum by default.
- Use explicit mappings when converting external values or numeric ranges into
  enum cases. Do not rely on enum declaration order or `values[index]` to encode
  domain meaning.
- Add enum capability getters when they centralize a meaningful rule used by
  multiple callers. Avoid getters that only wrap an obvious comparison at one
  call site.

## Constants and hard-coded values

- Keep a literal local when it is obvious, used once, and needs no independent
  explanation.
- Name a private constant when a value is non-obvious, repeated, or represents an
  implementation boundary such as a batch size or cursor protocol version.
- Define contract defaults and limits once in their owning specification, then
  give their implementation representation a single named source where sharing
  requires it. Do not create public constants solely to avoid a local literal.
- Keep independently versioned layers independent. For example, the diagnostic
  record schema version and a Drift database schema version have different
  migration responsibilities and must not share one constant.

## Reuse and abstraction

- Reuse code when the behavior, invariants, and change reasons are the same.
  Similar names or data shapes alone do not establish a shared abstraction.
- Keep transport-specific conversion in its adapter when client APIs have
  different capture or lifecycle semantics.
- Prefer a small amount of clear duplication over an abstraction that only
  coordinates two implementations without removing meaningful divergence.
  Reconsider centralization when another implementation arrives or the shared
  behavior changes.
- Put cross-package contracts in the lowest appropriate shared package. Keep
  platform or integration details out of the platform-neutral core.

## Object-oriented design and inheritance

- Use inheritance when a consumer-facing type must satisfy a framework or
  package base class, or when the subtype is genuinely substitutable for its
  base contract. Examples include the `package:http` `BaseClient` wrapper and a
  Dio `Interceptor` adapter.
- Prefer composition for sharing optional behavior or coordinating services.
  Do not introduce an abstract base class only to share a few methods between
  otherwise independent implementations.
- Define interfaces at real package or dependency boundaries, such as storage,
  sink, or injected transport contracts. Avoid interfaces that merely duplicate
  a single concrete class without enabling substitution.
- Use sealed types for closed model variants when exhaustive handling is useful;
  keep extension points explicit rather than making closed contracts open by
  accident.

## SOLID as design checks

Apply SOLID to reduce change coupling, not as a requirement to maximize the
number of classes or interfaces:

- **Single responsibility:** keep a type cohesive around one reason to change.
  A public facade may coordinate the workflow; split collaborators when it
  accumulates independent responsibilities with separate invariants or
  lifecycles.
- **Open/closed:** add a new implementation through an existing contract when
  that contract fits. Do not add speculative hooks for unapproved extensions.
- **Liskov substitution:** derived adapters must preserve the behavior promised
  by their base API, including request/response and lifecycle behavior.
- **Interface segregation:** keep contracts focused on capabilities their
  consumers actually need.
- **Dependency inversion:** keep core logic dependent on core contracts; let
  storage, transport, and client integrations implement or inject those
  contracts at package boundaries.

## Implementation and verification workflow

- For planned features and refactors, stage a concrete changeset and review it
  before implementation. Keep edits within the approved files and acceptance
  criteria; record any necessary scope change before proceeding.
- Use repository editing tools such as `apply_patch` for targeted source and
  documentation changes. Use scripts for repeatable transformations, not
  one-off heredoc programs that obscure the actual diff.
- After each logical Dart edit batch, run `dart format` on the changed Dart
  files. Do this before analysis and tests so formatting remains part of the
  reviewed diff.
- Verify in this order: analyze/type checks, targeted tests, then the affected
  package test suites. Add tests for behavior or invariants that need proof;
  avoid tests that only restate the implementation.
- Do not hand-edit generated files. Update their source and run the repository's
  generator, then verify generated output through analysis and tests.
