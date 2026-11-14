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

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
