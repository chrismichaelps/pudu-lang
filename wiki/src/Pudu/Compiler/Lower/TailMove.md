---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/TailMove.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Tail Move]
---
# Compiler Lower Tail Move

## Purpose and interface

The pass turns the final read of a counted local in a function's tail into a
move. A value the function holds alone then reaches the next call or update
with no extra reference. It runs on each lowered function before frame
lowering.

## Contract

- Runs on each lowered function before frame lowering.
- Walks the body's tail block from its result backwards through its
  statements, tracking which locals are read later. A read of an array, map,
  set, store or record local that nothing later reads becomes a move.
- Declarations and assignments end a local's life before their right side.
- Any expression or statement shape the pass does not read precisely counts as
  reading every local, so no read before it moves.
- Call arguments, record and collection operations, tuples, fields and nested
  tail blocks are read in their evaluation order.

## Resolved Grill Log

- **Q:** Does a move in a typed fast function need its own form? **A:** No. A
  move in a typed fast function is a plain copy, since its slots carry no
  counts. The fast emitter accepts moves, so the pass never removes a
  function's fast form. [[NATIVE-OWNERSHIP]]

## Referenced by

[[NATIVE-OWNERSHIP]] · [[Compiler Lower]]
