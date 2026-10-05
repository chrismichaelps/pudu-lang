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
`frameLookup`, `frameAssign` (only a name the frame already binds), `frameBind`, and `frameSnapshot`
(the bindings as they stand, copied).
## Governance and algorithm
`CellFrame` reads and assigns through a map of private IORef value cells. Binding
adds a fresh cell after its initializer; values are forced to WHNF at every
write, matching strict maps. Snapshot traverses cells into an immutable map.
Name presence, lexical order and shadowing remain dynamic.
A slot frame answers a name through its layout and writes the slot in place; a name it was not laid
out with lives in its extra map. A snapshot copies a slot frame's values, which is what a captured
environment holds, so a capture cannot change after it is taken.
## Grill Log
- **Q:** Retain cells in a captured environment? **A:** No; snapshot their current
  values. _Rationale:_ closures capture the value at creation, and a callback or
  host child must never observe later writes to its caller's local cells.
- **Q:** Keep name reads and writes opaque to their environment callers? **A:** No.
  _Rationale:_ the Loop allocation profile shows repeated wrappers at these
  boundaries. Inline `frameLookup` and `frameAssign`; preserve both frame shapes,
  snapshots, update semantics and every missing-name answer.
- **Q:** Give the tree walker its own path for slot frames? **A:** No. _Rationale:_ every name-based
  operation going through these five functions is what lets fallbacks inside a compiled body,
  lending, and capture keep working on slot frames without knowing about them.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Env]] · [[Eval Compile]]
