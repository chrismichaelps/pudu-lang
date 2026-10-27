---
type: module
path: "@root/src/Pudu/Backend/Emit/Range.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Range]
---
# Backend Emit Range

## Purpose and interface

`rangeHelpers` gives the range type the aggregate helpers every boxed type has
(drop, show, equal, compare, comparable) as thin calls into
[[Native Range Runtime]], and `rangeMethodCall` writes the call for one range
operation with its failure sites.

## Resolved Grill Log

- **Q:** Why go through aggregate helpers at all? **A:** Tuples, records,
  arrays, maps and sets holding ranges reach them by name, as they reach every
  other member type's.
- A range holds no references, so dropping one only frees its box.

## Dependencies and consumers

[[Backend Emit Cell]] · [[Native Range Runtime]]

## Referenced by

[[Native Aggregate Emission]] · [[Backend Frame Values]] · [[Native Range Values]] · [[src/Pudu/Backend/_MOC]]
