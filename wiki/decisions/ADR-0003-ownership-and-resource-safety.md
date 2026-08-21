---
type: adr
status: ACCEPTED
date: 2026-08-21
decision_risk: 100.0
review_date: 2026-11-01
tags: [adr]
aliases: [ADR-0003-ownership-and-resource-safety]
---

# ADR-0003 — Ownership and Resource Safety

## Context

The proposal promises moves, immutable/mutable borrows, native performance, and safety beyond C++. These promises determine the type system, IR, runtime, concurrency, and FFI.

## Problem

An unspecified ownership model can compile use-after-free, reject ordinary safe code, or make async/resource cleanup incoherent.

## Decision

Adopt the state transitions and obligations in [[Ownership]] and [[architecture/SEMANTICS]]:

- owning values move unless proven `Copy`;
- shared and exclusive borrows are statically exclusive as appropriate;
- intra-function regions end at last use using control-flow analysis;
- partial moves and definite initialization are tracked by place;
- destruction is deterministic with specified order;
- resource close failures use explicit `close` when recoverable;
- unsafe is lexical and cannot disable safe-value ownership;
- task transfer requires `Send`, shared cross-task access requires `Sync`.

## Rationale

These rules provide a coherent safe native model with familiar expressiveness and predictable resource behavior. Last-use regions avoid unnecessary lexical rejection without requiring general user lifetime syntax in v1.

## Consequences

- The semantic representation needs places, projections, move paths, control-flow joins, and drop elaboration.
- Public reference returns are constrained to borrowed inputs.
- Async lowering must preserve scope and cleanup.
- Native representations cannot rely on C aliasing behavior that violates Pudu contracts.

## Alternatives

- **Garbage collection:** rejected because predictable native resource lifetime is central to Pudu's purpose.
- **Reference counting by default:** rejected because it adds hidden atomic/cycle costs and does not prevent data races.
- **Lexical borrows only:** rejected as unnecessarily restrictive for normal sequential code.
- **Fully explicit lifetime parameters in v1:** rejected as interface complexity before inference limits are proven.

## Validation

- Property tests generate control-flow/move scenarios and compare accepted/rejected outcomes to the reference checker model.
- Negative corpus covers use after move, aliasing mutation, escaping references, partial moves, reinitialization, loop joins, panic/failure cleanup, and task transfer.
- Native sanitizer runs and interpreter/native drop-trace conformance must be green before safety claims.
- Review 2026-11-01 after ownership slice and unsafe/FFI prototype.

## Referenced by

[[decisions/_MOC]] · [[Ownership]] · [[Ownership Checking]] · [[architecture/SEMANTICS]] · [[CHANGELOG]]
