---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/State.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host State]
---
# Native Host State

Export the family's runtime parts and their prerequisites.

What a host call leaves behind for the program to read: whether it was done, what the host said when it was not, and the run gate that lets one thread run at a time.

## Resolved Grill Log

The state is per thread, read once after the call that set it. The run gate keeps reference counts and the frame engine single-threaded, as the interpreter's own scheduler runs one evaluation at a time.

The live registry uses an inline table for its first eight entries and
indexes relative to the first token in the current live generation. When
the last object is forgotten, reset the storage and base while continuing
the monotonic token sequence. Refuse invalid, stale, and wrong-kind tokens
before accessing the table. The run gate still protects registry access.
Yield checks the scheduler clock while workers are live or an external
callback can enter. The last worker's exit restores the single-thread path
in runs without external callback admission.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
