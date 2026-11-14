---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Frame/Direct.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, backend, emit, native, frames, performance]
aliases: [Backend Frame Direct]
---

# Backend Frame Direct

## Purpose and interface

Decide which frame functions run in a frame on the C stack and are called as plain C
functions.

```haskell
directFunctions :: FrameModule -> Set Text
argumentCount :: FrameFunction -> Int
frameCells :: FrameFunction -> Int
directCellLimit :: Int        -- 512
directStackBudget :: Int      -- 65536 bytes
directFrameOverhead :: Int    -- 128 bytes per frame beyond its cells
```

## Algorithm and invariants

- A function is direct when:
  - (a) it is not the module entry;
  - (b) it has no closure record, so it is never reached as a function value;
  - (c) none of its blocks ends in a call through a function value;
  - (d) it is in no call cycle (strongly connected components of the call graph);
  - (e) every function it calls by name is direct;
  - (f) its frame, slots plus the widest argument scratch, is at most `directCellLimit` cells;
  - (g) its own frame bytes (cells × 16 plus `directFrameOverhead`) plus the deepest direct
    callee chain stay within `directStackBudget`.
- Components are visited callees first, so each decision only reads decisions already made.
- `argumentCount` is the widest call's argument count, shared with the function table.
- `frameCells` is slots plus argument scratch, at least one.

## Negative Logic (Prohibited Paths)

- No direct function that recurses, directly or through others.
- No direct function reached as a value or calling through one.
- No direct function that calls a heap-path function, so a direct call never enters the
  dispatcher.
- No unbounded host stack use.

## Dependencies and consumers

Uses [[Core Frame IR]]. Consumed by [[Backend Frame Bodies]], [[Backend Frame Program]] and
[[Backend Emit Export]].

## Grill Log

- **Q:** Why not let a direct function call a heap-path function through a nested dispatcher?
  **A:** That would let a recursive callee grow the host stack under a direct frame and mix
  two return protocols in one body. _Rejected:_ nested dispatch loops.
- **Q:** Why a stack budget instead of trusting the call graph? **A:** A non-recursive chain
  can still be deep and wide; 64 KiB stays far inside the smallest secondary-thread stack the
  supported platforms give. _Rejected:_ an unbounded acyclic depth.
- **Q:** Why exclude functions with a closure record even when also called by name? **A:** The
  function table must keep a frame body for value calls; keeping such functions on one path
  keeps their depth and blame accounting single. _Rejected:_ two entry protocols for one
  function.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Frame Bodies]] · [[Native Direct Calls Delivery]]
