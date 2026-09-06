---
type: module
path: "@root/src/Pudu/Eval/WordMap.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Word Map]
---

# Eval Word Map

## Purpose, interface and invariants

`callWordMapPopCount` checks one MapValue argument, projects UInt64 payloads with explicit range
checks and invokes Runtime Word Kernels directly over the map Foldable instance. Keys are ignored.
Returns IntValue (UnsignedKind 128). Wrong receiver or payload reports E7001 with the call span;
wrong arity reports E7003. It performs no unchecked conversion or surface callback.

## Grill Log

- **Q:** Count bits in Pudu callbacks? **A:** No; traverse the host container once and apply the
  native Word64 population count to each checked payload. This removes interpreted bit loops.
- **Q:** Claim an unboxed map or measured speedup? **A:** No; the map still stores boxed values.
  The change removes dispatch and staging, not the tree representation. No validation was run.

## Dependencies and consumers

[[Eval Word Map]] adapts [[Runtime Word Kernels]] for [[Std BitSet]] through [[Eval Builtin]].

## Referenced by

[[src/_MOC]] · [[Backend Representation Specialization]]
