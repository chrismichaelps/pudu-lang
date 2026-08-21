---
type: subsystem
tags: [subsystem]
aliases: [Semantics]
---

# Semantics

## Purpose

Enforce [[architecture/SEMANTICS]] by resolving names, inferring/checking [[Pudu Type]] values, proving match/effect obligations, verifying [[Ownership]], and lowering valid programs to [[Core IR]].

## Owns

[[Name Resolution]] · [[Type Checking]] · [[Ownership Checking]] · exhaustiveness · trait coherence · typed syntax · lowering.

## Boundaries

- Consumes [[Frontend]] syntax and diagnostics.
- Produces typed/core values only when no error-severity semantic diagnostics remain.
- Does not perform IO or target-specific emission.

## Grill Log

- **Q:** Can ownership run before types? **A:** No; ownership behavior depends on resolved places, `Copy`, references, and generic constraints. _Rationale:_ typed places are the smallest reliable input. _Rejected:_ syntax-based move checker.
- **Q:** Can semantic recovery fabricate types? **A:** Use explicit poison/error types that unify only to suppress cascades and never reach [[Core IR]]. _Rationale:_ tools need continued analysis without compiling invalid programs. _Rejected:_ defaulting invalid expressions to unit.

## Referenced by

[[architecture/OVERVIEW]] · [[Frontend]] · [[Runtime]] · [[Backend]] · [[Tooling]]
