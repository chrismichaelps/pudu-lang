---
type: module
path: "@root/src/Pudu/Backend/Emit.hs"
fidelity: Active
aliases: [Backend Emit]
grammar: "[[grammar/haskell]]"
---
# Backend Emit

## Purpose and interface

Export emitProgram :: Text -> [Source] -> FrameModule -> Either FrameFault Text.
Delegate deterministic translation-unit assembly to [[Backend Frame Program]].
The compiler-owned [[Compiler Frame Lowering]] runs before this boundary. No
backend import from frontend, semantic or compiler modules; no lowering, IO,
allocation or source inference occurs in this facade. Source/module version and
sites remain inputs to pure generation. Failures return data, never partial C
or a host exception. Old recursive C emission is removed from this module.

## Resolved Grill Log

- **Q:** Keep emitProgram accepting structured Core? **A:** No; explicit frame IR is the backend contract for bounded C call depth.
- **Q:** Fall back to recursive emission on a frame fault? **A:** No; callers render the existing typed native refusal.
- **Q:** Change arithmetic/diagnostics with this facade? **A:** No; existing helpers and shared site geometry remain authoritative.

## Dependencies and consumers

[[Backend Frame Program]] · [[Core Frame IR]] · [[Source]] · [[Pudu CLI]] ·
[[Backend Emit Tests]] · [[Backend Native Tests]] · [[Native Execution Frames]]

## Referenced by

[[Backend Module Map]] · [[src/_MOC]] · [[Native Frame Pressure Repair]]
