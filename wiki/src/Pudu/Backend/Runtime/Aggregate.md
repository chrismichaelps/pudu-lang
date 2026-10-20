---
type: module
path: "@root/src/Pudu/Backend/Runtime/Aggregate.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Aggregate Runtime]
---
# Native Aggregate Runtime

## Purpose and interface

Export aggregateRuntimeParts and aggregateRuntimeDependencies. `text_join`
writes an opening, parts separated by `, `, and a closing, and takes the parts'
references. It needs only `text_allocate`, so it sits with the other runtime
parts, ahead of the cell type.

`float_order` is compareValues' float order (#522): NaN equals NaN and sorts
after every number; otherwise IEEE less/equal on the raw binary64 bits.

## Grill Log

- **Q:** Why release the parts inside the join? **A:** Every caller builds the
  parts only to join them; taking them keeps generated show helpers short.

## Referenced by

[[Native Aggregate Emission]] · [[src/_MOC]]

## Labels (#521)

`pudu_text_join` takes an optional label per part, written before it; records
pass `"x: "`, tuples pass NULL.
