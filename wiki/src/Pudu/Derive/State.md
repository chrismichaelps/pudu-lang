---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Derive/State.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, expansion]
aliases: [Derive Residual State]
---

# Derive Residual State

## Purpose and interface

Own the pure, failure-aware per-request residualizer state: generated node ordinal,
iteration count and field obligations. `runResidual`, `generated`, `iteration`,
`requireFields`, `refuse` and `withinDepth` hide its representation. Products are
ordinary syntax and structured errors/obligations; this module performs no checking,
resolution, filesystem access or evaluation.

`FieldObligation` carries `obligationLabel`, the owner-qualified field name diagnostics show. `noteExit` and `exitsTaken` count lowered callback exits, so a callback body is wrapped in its exit loop only when it left early.

## Algorithm and limits

Every generated node consumes one work unit and receives a deterministic ordinal
under the request anchor. Iterations consume the shared compile-time iteration
limit independently. Depth is checked before descending. Limits come from
[[Compile Time Limits]], and exhausted work returns a located typed failure before
an impl product is published. State belongs to one request; none survives a call.

## Edge cases and negative logic

Empty records generate valid empty loops. Failed expansion publishes no partial
product. Imported authored spans retain their real identities. No recursive
provenance chains, silent budget fallback, unbounded counter arithmetic or global
mutable state.

## Grill Log

- **Q:** Budget only the outer loop? **A:** No; count all generated nodes and all
  nested iterations. _Rationale:_ nested unrolling can multiply output. _Rejected:_
  per-loop counters reset at recursion or unbounded syntax traversal.
- **Q:** Wrap every callback body in an exit loop? **A:** No; only bodies whose lowering took an exit, counted here.

## Referenced by

[[Derive Record Residualizer]] · [[Source]] · [[Derive Design]]
