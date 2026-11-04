---
type: module
path: "@root/src/Pudu/Backend/Emit/Bytes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Bytes]
---
# Backend Emit Bytes

## Purpose and interface

`bytesHelpers` gives the Bytes type its aggregate helpers (drop, show, equal,
compare, comparable), and `bytesFunction` names the runtime function for one
operation.

## Resolved Grill Log

- Bytes order and compare by their contents, the order text already uses for
  its bytes.

## Dependencies and consumers

[[Backend Emit Cell]] · [[Native Bytes Runtime]]

## Referenced by

[[Native Aggregate Emission]] · [[Backend Frame Values]] · [[src/Pudu/Backend/_MOC]]
