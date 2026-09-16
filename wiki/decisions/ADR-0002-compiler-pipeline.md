---
type: adr
status: ACCEPTED
date: 2026-08-21
decision_risk: 5.0
review_date: 2026-10-01
tags: [adr]
aliases: [ADR-0002-compiler-pipeline]
---

# ADR-0002 — Compiler Pipeline

## Context

The implementation must be production-quality Haskell, support an interpreter/REPL and native compiler pipeline, and keep compiler performance measurable.

## Problem

Direct native emission from syntax would couple semantics to a backend, duplicate behavior in the interpreter, and degrade diagnostics. Direct LLVM bindings create a large early dependency seam.

## Decision

Use the explicit phases in [[architecture/OVERVIEW]], implemented in Haskell locked by [[grammar/haskell]]. The interpreter owned by [[Runtime]] and native emitter owned by [[Backend]] both consume checked [[Core IR]]. Native v1 emission targets portable C11 and crosses [[Native Toolchain]] for executable production.

## Rationale

Separate phase types make invalid states harder to represent and tests more focused. The interpreter becomes the executable semantic oracle. C11 output provides native portability and inspectability with a much smaller early seam than LLVM.

## Consequences

- Source provenance must survive every transformation.
- Core IR design precedes interpreter/backend logic.
- Backend conformance compares interpreter and compiled outcomes.
- C undefined behavior must be avoided explicitly in emission helpers.
- LLVM remains possible behind a promoted backend seam after semantics stabilize.

## Alternatives

- **LLVM first:** rejected for dependency/API/toolchain complexity and slower semantic iteration.
- **Tree-walk interpreter plus unrelated C generator:** rejected for duplicated semantics.
- **Custom bytecode VM first:** rejected as extra runtime architecture before the semantic core is stable.

## Validation

- Predicted: phase unit tests isolate defects; conformance corpus produces equal observations in interpreter and native execution.
- Predicted: a clean development build remains fast because frontend/semantic phases are pure and modular.
- Review 2026-10-01 after first end-to-end native slice.

## Referenced by

[[decisions/_MOC]] · [[architecture/OVERVIEW]] · [[architecture/SEMANTICS]] · [[Native Toolchain]] · [[CHANGELOG]]
