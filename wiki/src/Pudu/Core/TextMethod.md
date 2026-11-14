---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Core/TextMethod.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Core Text Operations]
---
# Core Text Operations

Owns the closed `CoreTextMethodName` vocabulary re-exported by [[Pudu Core]].
Lowering selects an operation. Emission chooses its implementation.

## Resolved Grill Log

Extract the existing operation tags to keep Core focused on checked IR nodes.
Preserve every constructor and the guard/read split for conversions and byte
access. The enum holds no C representation or runtime state.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu Core]]
