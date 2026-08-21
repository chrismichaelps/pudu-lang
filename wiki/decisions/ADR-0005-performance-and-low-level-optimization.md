---
type: adr
status: ACCEPTED
date: 2026-08-21
decision_risk: 10.0
review_date: 2026-11-01
tags: [adr]
aliases: [ADR-0005-performance-and-low-level-optimization]
---

# ADR-0005 — Performance and Low-Level Optimization

## Context

Pudu targets performance-sensitive native software, and its Haskell implementation must remain responsive as the language and team scale.

## Problem

Unstructured “optimize everything” work creates unsafe transformations, opaque mutable compiler state, misleading microbenchmarks, and a slow compiler or runtime despite local cleverness.

## Decision

Adopt [[Performance Constitution]]. Keep explicit phase data and pure contracts, admit local low-level mutation/compact structures based on profiles, preserve ownership/effect facts into Core/CFG IR, and implement a staged proof-preserving optimization pipeline before relying on the C toolchain optimizer.

## Rationale

This approach makes safety information an optimization input, keeps performance measurable, and allows internals to become low-level without exposing representation complexity across phase interfaces.

## Consequences

- Benchmark infrastructure is part of production tooling, not post-v1 polish.
- Optimizations need semantic conformance and before/after evidence.
- Initial readable representations may be replaced behind stable interfaces.
- Unsafe C assumptions and fast-math defaults remain prohibited.

## Alternatives

- **Optimize after feature completion:** rejected because representation and incremental boundaries would calcify.
- **Start with arena/unsafe mutation everywhere:** rejected because no baseline proves need and defect localization suffers.
- **Delegate all optimization to clang/gcc:** rejected because Pudu-specific ownership/failure/drop facts would be lost.

## Validation

- Establish compiler phase and generated-code baselines with the first end-to-end executable slice.
- Track allocation/time/code-size history in CI artifacts once stable runners exist.
- Require semantic conformance for every optimization pass.
- Review 2026-11-01 after Core IR and native backend benchmarks exist.

## Referenced by

[[decisions/_MOC]] · [[Performance Constitution]] · [[architecture/SEMANTICS]] · [[CHANGELOG]]
