---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Concurrent.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Concurrent]
---
# Native Host Concurrent

Export the family's runtime parts and their prerequisites.

Cells, locks, channels and threads behind their tokens. A held value is a box of one member; the function that releases the box names its type.

Its forward declaration of `pudu_frame_depth` carries no attribute, because the definition now precedes every body ([[Backend Frame Runtime]]); a plain tentative declaration is valid on either side of it.

A failure on a started thread runs the cleanup hook before the long jump, so stack frames of direct functions release their owned values while their storage is still live.

## Resolved Grill Log

A started thread's failure ends that thread, not the program. Threads take turns through the run gate.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
