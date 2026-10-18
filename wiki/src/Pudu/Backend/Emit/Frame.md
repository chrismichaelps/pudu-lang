---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame.hs"
fidelity: Active
aliases: [Backend Frame Program]
---
# Backend Frame Program

## Purpose and interface

Export emitFrameProgram :: Text -> [Source] -> FrameModule -> Either FrameFault Text.
Assemble selected runtime, frame types, sites, generated bodies, parameter-index
arrays/descriptors, frame engine and C main in deterministic order. Close runtime
dependencies from emitted roots only, with the frame engine's required host-failure
and cleanup parts. Select status only for an integer entry. Unit/Never entry
discards the returned cell and exits zero on normal completion. Entry must exist
and have no parameters. Numeric IDs follow module order. Empty parameter vectors
use NULL, not zero-length arrays. Frame slot counts and argument scratch maxima
come from actual emitted functions. No frontend/compiler import or inference.

## Resolved Grill Log

- **Q:** Lower structured Core inside the backend? **A:** No; the compiler calls lowerFrames before this boundary.
- **Q:** Emit unused recursive wrappers too? **A:** No; only step bodies and descriptors are emitted.
- **Q:** Hide a failed emission as C text? **A:** No; return FrameFault data.

## Dependencies and consumers

[[Core Frame IR]] · [[Backend Frame Bodies]] · [[Backend Frame Runtime]] · [[Backend Runtime]] · [[Backend Emit]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]
