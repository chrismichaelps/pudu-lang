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
is the seam's production adapter. Milestone 2 (#488) adds user-defined
functions: reachability-driven lowering in [[Compiler Lower]] and
[[Compiler Lower Body]], declared parameter and return types, calls and
recursion with the evaluator's argument order, and the call-depth refusal
(`E7002`) reproduced by the runtime from [[Diagnostic Evaluation]]. The
interpreter remains the semantic oracle and the default execution path;
[[Backend Native Tests]] hold the native path to it byte for byte. Later
milestones (records, collections, ownership, fallback policy) remain open.

## Boundaries

- Does not reinterpret typing or ownership.
- Receives explicit target configuration.
- External compiler discovery/execution crosses only [[Native Toolchain]].

## Grill Log

- **Q:** Should C be user-visible source of truth? **A:** No; it is a deterministic artifact derived from Core IR. _Rationale:_ Pudu semantics cannot inherit C undefined behavior. _Rejected:_ specifying Pudu as syntactic C translation.
- **Q:** May generated C rely on signed overflow? **A:** No. _Rationale:_ checked/wrapping/saturating semantics require defined helper operations. _Rejected:_ optimization flags that assume overflow cannot occur.
- **Q:** Why does milestone 1 refuse so much? **A:** The subset is the part of the language whose semantics the first runtime can reproduce exactly; every refusal names its construct and points at the interpreter, so nothing runs natively under different rules than it ran before. _Rejected:_ partial support behind a silent fallback.
- **Q:** Why do milestone 2 functions require declared types? **A:** Checker inference solves unannotated types by unification and never writes the solution back to the syntax tree, so lowering cannot see them; requiring annotations keeps one source of truth instead of re-running inference in the backend. _Rejected:_ backend-side type inference.

## Referenced by

[[architecture/OVERVIEW]] · [[Semantics]] · [[Runtime]] · [[Tooling]] · [[Native Toolchain]]

## Completion track

[[Native Emission Coverage]] is the coverage ledger for complete native behavior. Issue #489 extends scalar control flow with while/loop values, labelled transfers and Never joins. Each admitted construct must retain interpreter equality and typed refusal boundaries for unimplemented runtime representations.
