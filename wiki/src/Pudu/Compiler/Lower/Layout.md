---
type: module
path: "@root/src/Pudu/Compiler/Lower/Layout.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Layout]
---
# Compiler Lower Layout

## Purpose and interface

Export `moduleLayouts`: the layout of every record and sum a lowered module
mentions, closed over the layouts they reach, for `coreModuleLayouts`.

## Grill Log

- **Q:** Why carry layouts beside the functions instead of inside the types?
  **A:** Types name records and sums by identity only, so a recursive sum stays
  a finite type; the layout map is where each is spelled out once.

## Closure layouts (#555)

Resolved Grill Log: every function type met gets a `CoreClosureLayout` of the
lifted functions whose closure has that type, empty when none was made.

## Arrays (#556)

Resolved Grill Log: an array type's element and the new Core shapes are
collected.

## Referenced by

[[Compiler Lower]] · [[Core IR]] · [[src/_MOC]]
