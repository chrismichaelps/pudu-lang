---
type: module
path: "@root/src/Pudu/Eval/Compile/Cache.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Compile Cache]
---
# Eval Compile Cache
## Purpose
Keep each compiled body for the length of a run, so a body is compiled on its first call only.
## Interface
`compiledBody cache bodySpan compile` answers the cached code for the body at `bodySpan`, or runs
`compile` and stores its result.
## Governance and algorithm
The cache belongs to a program's run and is shared by its threads, so it is updated atomically;
two threads that compile the same body at once both answer a correct compilation and one is kept.
Compile-time evaluation has no cache and runs the tree walker.
## Grill Log
- **Q:** Keep the cache inside the compiler module? **A:** No. _Rationale:_ calls read it, and the
  compiler compiles calls; a separate module is what lets both depend on it without a cycle.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Compile]] · [[Eval Call]]
