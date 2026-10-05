---
type: handoff
tags: [handoff, runtime, performance, plan]
---

# Compiled Evaluation — Plan B: slot frames

**Goal:** a compiled body keeps its parameters and locals in an array at positions fixed when it was
compiled, so reading or assigning one is an index, not a search by name and a rebuilt map.

**Architecture:** a frame becomes either a name map, as now, or a slot frame: a mutable array, the
fixed layout naming each position, and a map for any name a body binds at run time that it never
declared. Every existing path that works by name (`lookupName`, `updateExisting`, `bind`,
`storePlace`, capture) reads a slot frame through its layout, so the tree walker, fallbacks inside
a compiled body, lending, and capture keep working unchanged. Compiled code bypasses the layout and
uses the index directly wherever its compile-time scope proves the name is that body's own.

## Global Constraints

- Behaviour, values, and diagnostics are unchanged; [[Eval Compile]]'s oracle and the full suite
  decide.
- A body that binds one name twice (shadowing within itself) keeps map frames, so a layout is always
  one name to one position.
- Anything pushed above a slot frame (match arm bindings, fallback frames) still shadows it,
  because a slot frame sits in the frame stack where the body's frame was.
- Captured environments snapshot a slot frame into a map, so a captured value cannot change after
  capture, exactly as with map frames.
- Measure with `bench/eval.sh` at -O2.

## Task 1: Frames as a type

- [x] `Frame` in `Pudu.Eval.Value` beside `Captured`; `Captured` holds frames.
- [x] `Pudu.Eval.Frame`: `frameLookup`, `frameAssign`, `frameBind`, `frameSnapshot`.
- [x] Every `envFrames` site in Env, Place, Program, and Call goes through them. No slot frame is
  created yet; the full suite passes unchanged.

## Task 2: Compiled bodies on slot frames

- [x] Layout per body: parameters, then every `let` the compiled code declares, if no name repeats.
- [x] On entry the parameters' map frame becomes the body's slot frame; reads and assignments of
  slotted names compile to index operations; a slotted body's blocks open no frame.
- [x] Oracle, suite, gates; `bench/eval.sh` recorded here.

## Status

Plan B is complete (#427). At -O2 with `bench/eval.sh`, tree walker against compiled: loop
2.70 s / 0.90 s, records 2.21 s / 1.12 s, maps 1.03 s / 0.56 s, arrays 1.37 s / 0.79 s, calls
0.56 s / 0.37 s, multimap 7.99 s / 4.95 s. Bodies with no local of their own keep map frames, since
setting up slots for each call cost more than it saved for them.

## Exact next action

Direct calls and compiled `for`, `if let`, and index reads landed (#428). Next: profile
`bench/eval/MultiMap.pudu` again; its time is now spread across call setup, keyed-map comparison of
tuple keys, and method dispatch on builtin values, so the next step is a design choice between a
leaner monad for compiled code and native code generation, recorded in [[Compiled Evaluation]].

## Referenced by

[[handoffs/_MOC]] · [[Compiled Evaluation]] · [[2026-09-30-compiled-evaluation-plan]]
