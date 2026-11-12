---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Signal.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Signals]
---
# Native Host Signals

Export the family's runtime parts and their prerequisites.

The request to stop that arrives from outside the program: watching for it and reading whether it came, as `Pudu.Eval.Signal` answers them.

## Resolved Grill Log

- Act on the signal in the handler? No: the handler sets one flag, and the program reads it where it is ready to stop.
- Install on every watch? No: the first watch installs both handlers; later ones answer true without installing.
- Which signals? The terminate and interrupt requests, recorded alike.
- A blocked call when the signal arrives? It restarts; only the flag changes.
- A machine without these signals? Watching answers false and nothing is installed.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
