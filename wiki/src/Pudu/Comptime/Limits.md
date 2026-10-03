---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Comptime/Limits.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, comptime]
aliases: [Compile Time Limits]
---

# Compile Time Limits

## Purpose and interface

Expose phase-neutral `callDepthLimit = 4096`, `iterationLimit = 100000` and
`expansionNodeLimit = 1000000`. Runtime loops remain unrestricted; compile-time
execution and derive residualization share the depth and iteration boundaries.
The generated-node bound separately caps syntax growth between loop iterations.

## Algorithm, edge cases and negative logic

Pure constants with no evaluator/frontend dependencies or state. No per-module
reset that permits nested expansion to evade a request's budget. Zero-field shapes
consume no iterations. Each phase reports its own located budget failure.

## Grill Log

- **Q:** Reuse the iteration limit as a syntax-node limit? **A:** No; preserve
  100000 iterations while separately allowing up to 1000000 generated nodes.
  _Rationale:_ an ordinary body produces several nodes per iteration. _Rejected:_
  unbounded growth or changing the existing loop contract accidentally.

## Referenced by

[[Derive Residual State]] · [[Derive Design]] · [[src/Pudu/_MOC]]
