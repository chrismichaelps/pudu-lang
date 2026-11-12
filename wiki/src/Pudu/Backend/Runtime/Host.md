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
call: state, math, process, concurrency, input, files, handles, scopes, lanes,
signals, sockets, compression, child programs, and time rendering and reading.

## Resolved Grill Log

Parts are selected by need like every runtime part, so a program that asks
nothing of the host carries none of this. [[Native Host Input]] supplies decoding\nhelpers before [[Native Host Files]] uses them.

## Referenced by

[[Backend Runtime]] · [[Native Host Services]] · [[Native Host Signals]] · [[Native Host Sockets]] · [[Native Host TLS]] · [[Native Host Compression]] · [[Native Host Child Programs]] · [[Native Host Time]] · [[Native Host Time Reading]]
