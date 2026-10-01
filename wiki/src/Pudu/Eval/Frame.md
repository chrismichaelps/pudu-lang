---
type: module
path: "@root/src/Pudu/Eval/Frame.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Frame]
---
# Eval Frame
## Purpose
Read and write one level of bindings by name, whether it is a name map or a compiled body's slot
frame, so everything that works by name treats the two alike.
## Interface
`frameLookup`, `frameAssign` (only a name the frame already binds), `frameBind`, `frameSnapshot`
(the bindings as they stand, copied), and `frameOf`.
## Governance and algorithm
A slot frame answers a name through its layout and writes the slot in place; a name it was not laid
out with lives in its extra map. A snapshot copies a slot frame's values, which is what a captured
environment holds, so a capture cannot change after it is taken.
## Grill Log
- **Q:** Give the tree walker its own path for slot frames? **A:** No. _Rationale:_ every name-based
  operation going through these five functions is what lets fallbacks inside a compiled body,
  lending, and capture keep working on slot frames without knowing about them.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Env]] · [[Eval Compile]]
