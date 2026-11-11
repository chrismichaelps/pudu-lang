---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Runtime]
---
# Native Host Runtime

Export hostRuntimeParts: every host part in emission order, what the program
asks of the machine it runs on. A family comes after the families its parts
call: state, math, process, concurrency, files, handles, scopes and lanes.

## Resolved Grill Log

Parts are selected by need like every runtime part, so a program that asks
nothing of the host carries none of this.

## Referenced by

[[Backend Runtime]] · [[Native Host Services]]
