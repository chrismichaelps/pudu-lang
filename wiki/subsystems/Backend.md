---
type: subsystem
tags: [subsystem]
aliases: [Backend]
---

# Backend

## Purpose

Lower checked [[Core IR]] into portable C11 and coordinate the [[Native Toolchain]] to publish an atomic [[Compilation Artifact]].

## Owns

Native backend · C names/layout · runtime ABI references · target model · toolchain process translation.

## Status

Milestone 1 is implemented (#486): [[Compiler Lower]] gates the frozen scalar
subset with typed refusals, [[Backend Emit]] emits deterministic C11 from
[[Pudu Core]] with baked diagnostic sites, [[Backend Runtime]] supplies the
checked helpers and interpreter-parity refusal text, and [[Backend Toolchain]]
is the seam's production adapter. The interpreter remains the semantic oracle
and the default execution path; [[Backend Native Tests]] hold the native path
to it byte for byte. Later milestones (functions, records, collections,
ownership, fallback policy) remain open.

## Boundaries

- Does not reinterpret typing or ownership.
- Receives explicit target configuration.
- External compiler discovery/execution crosses only [[Native Toolchain]].

## Grill Log

- **Q:** Should C be user-visible source of truth? **A:** No; it is a deterministic artifact derived from Core IR. _Rationale:_ Pudu semantics cannot inherit C undefined behavior. _Rejected:_ specifying Pudu as syntactic C translation.
- **Q:** May generated C rely on signed overflow? **A:** No. _Rationale:_ checked/wrapping/saturating semantics require defined helper operations. _Rejected:_ optimization flags that assume overflow cannot occur.
- **Q:** Why does milestone 1 refuse so much? **A:** The subset is the part of the language whose semantics the first runtime can reproduce exactly; every refusal names its construct and points at the interpreter, so nothing runs natively under different rules than it ran before. _Rejected:_ partial support behind a silent fallback.

## Referenced by

[[architecture/OVERVIEW]] · [[Semantics]] · [[Runtime]] · [[Tooling]] · [[Native Toolchain]]
