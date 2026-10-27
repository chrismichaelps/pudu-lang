---
type: module
path: "@root/src/Pudu/Compiler/Lower/Place.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Place]
---
# Compiler Lower Place

Export lowerPlaceAssignment. Parse a target into a root local and field and
index steps; hold each index, then the value, in temporaries; assign the
root the rebuilt value. Field steps use CoreRecordUpdate, index steps read
with ArrayGetAt and write with ArrayReplaceAt, both at the root span.
Nothing for a target that is not a place of a local.

## Resolved Grill Log

Moved here from Compiler Lower Record's field assignment, which it now
covers. Index temporaries make each index run once, in the evaluator's
order. See [[Native Place Assignment]].

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]
