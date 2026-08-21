---
type: adr
status: ACCEPTED
date: 2026-08-21
decision_risk: 10.0
review_date: 2026-10-01
tags: [adr]
aliases: [ADR-0001-language-purpose-and-v1-scope]
---

# ADR-0001 — Language Purpose and v1 Scope

## Context

The private local proposal describes a broad safe-systems syntax covering numeric modes, algebraic types, ownership, traits, async, macros, compile-time execution, collections, and error propagation. It does not fully define their interactions or a staged implementation center and is intentionally excluded from repository history.

## Problem

A feature-list implementation would accept syntax without trustworthy semantics, overextend the first compiler, and make “safer than C++” an unsupported claim.

## Decision

Adopt the purpose and non-goals in [[Pudu Language]]. Every proposal feature remains part of the intended language, but admission requires syntax, static semantics, dynamic semantics, diagnostics, interpreter/native conformance, tooling impact, and tests. The semantic core is versioned through [[architecture/SEMANTICS]].

Core delivery order:

1. Modules, bindings, functions, primitives, blocks, control flow, records/sums, and matches.
2. Generics/traits, `Result` propagation, collections/iterators.
3. Moves, borrows, deterministic resources, and unsafe boundary.
4. Async structured concurrency and cancellation.
5. Restricted compile-time evaluation and hygienic declarative macros.
6. FFI, production tooling, stabilization, and optimization.

## Rationale

The proposal's goal is preserved while semantic integrity becomes the definition of completeness. A small coherent core allows precise diagnostics and conformance before advanced surface area compounds defects.

## Consequences

- Parsing a feature is never sufficient for completion.
- Reserved but not yet semantically accepted constructs produce explicit “feature not enabled” diagnostics.
- `Decimal`, macro matcher syntax, and foreign declarations remain Senior Definition Needed until their slice ADRs.
- Documentation must label implemented language versions accurately.

## Alternatives

- **Implement all syntax immediately:** rejected because behavior would be guessed and tests shallow.
- **Reduce Pudu permanently to a teaching language:** rejected because it violates the native systems-language goal.
- **Copy Rust/C++ semantics wherever unspecified:** rejected because Pudu requires its own coherent, documented contracts.

## Validation

- Predicted: every implemented feature has success/failure/diagnostic/conformance tests; zero undocumented semantic branches.
- Predicted: proposal coverage is tracked by semantic slices rather than token acceptance.
- Review 2026-10-01 against coverage, diagnostic cascades, and semantic churn.

## Consensus

Architect: APPROVE. DNA Engineer impact: semantics and pages required before every slice. Shadow impact: implementation cannot improvise missing behavior.

## Referenced by

[[decisions/_MOC]] · [[Pudu Language]] · [[architecture/SEMANTICS]] · [[CHANGELOG]]
