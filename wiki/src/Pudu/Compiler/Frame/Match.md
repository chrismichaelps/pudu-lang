---
type: module
path: "@root/src/Pudu/Compiler/Frame/Match.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Frame Match]
---
# Compiler Frame Match

## Purpose and interface

Export `lowerMatch` and `MatchLowering`: a `CoreMatch` as a chain of tests over
one subject slot. Each arm tests its pattern, then its guard, then runs its
body; any failed test falls through to the next arm.

- Variant tests read the tag with `FrameIsVariant`; payloads are read with
  `FramePayload` only after the tag matched.
- With no arm left, the subject is rendered by `show` into E7011
  `no match arm accepted ...`, as the evaluator does.

## Grill Log

- **Q:** Is E7011 reachable? **A:** Not from a checked program, because
  checking requires every match to cover its subject. It is kept so the native
  path refuses exactly as the evaluator would if it were reached.

## Referenced by

[[Compiler Frame Lowering]] · [[Compiler Lower Match]] · [[src/_MOC]]
