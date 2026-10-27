---
type: module
path: "@root/src/Pudu/Backend/Emit/State.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit State]
tags: [module, backend, codegen]
---
# Backend Emit State

## Purpose

Own deterministic output state, diagnostic-site baking, byte escaping, and temporary allocation.

## Interface

Exports EmitState fields, emptyEmitState, line, freshTemp, textOfInt, overflowSite, divideByZeroSite, callDepthSite, renderSites, cString, and cStringBytes.

## Algorithm and invariants

Output and site lists accumulate in reverse; counters increase monotonically across the translation unit. Site geometry uses the shared diagnostic renderer. UTF-8 bytes escape as three-digit octal sequences; question marks also escape to prevent C11 trigraph replacement. No source-dependent preprocessor behavior is allowed.

## Negative logic

No frontend or evaluator dependencies, IO, environment reads, or semantic inference.
Only lowered Core IR reaches this boundary. Source text never becomes executable C.

## Dependencies and consumers

Uses [[Source]], [[Diagnostic Render]], [[Diagnostic Arithmetic]], [[Diagnostic Evaluation]], and [[Pudu Core]]. Consumed by [[Backend Emit]].

## Grill Log

- **Q:** Why extract this responsibility? **A:** It has a stable pure interface and keeps the emitter below 500 lines. The split preserves output ordering and diagnostic geometry. Rejected: a single growing emitter.
- **Q:** May extraction change semantics? **A:** No; eager evaluation is sequenced by the emitter, while this module supplies representation and assembly primitives. Rejected: backend inference.

## Referenced by

[[Backend Emit]] · [[src/Pudu/Backend/_MOC]]

## Resolved loop state (#489)

State also owns the active map from numeric loop identities to optional scalar result slots, plus sets of emitted break and continue references. Loop emission restores the enclosing slot map after its lexical region; transfer-reference sets accumulate so nested loops can reference outer labels.

- **Q:** May source label text identify a target? **A:** No; only lowering's resolved CoreLoopId is accepted. Rejected: name lookup during emission.
