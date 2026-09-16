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

## Boundaries

- Does not reinterpret typing or ownership.
- Receives explicit target configuration.
- External compiler discovery/execution crosses only [[Native Toolchain]].

## Grill Log

- **Q:** Should C be user-visible source of truth? **A:** No; it is a deterministic artifact derived from Core IR. _Rationale:_ Pudu semantics cannot inherit C undefined behavior. _Rejected:_ specifying Pudu as syntactic C translation.
- **Q:** May generated C rely on signed overflow? **A:** No. _Rationale:_ checked/wrapping/saturating semantics require defined helper operations. _Rejected:_ optimization flags that assume overflow cannot occur.

## Referenced by

[[architecture/OVERVIEW]] · [[Semantics]] · [[Runtime]] · [[Tooling]] · [[Native Toolchain]]
