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

## Checked join lengths (#569)

Resolved Grill Log: check opening/closing, each part length, separator and
label independently before accumulation. Compound unchecked extra arithmetic
can wrap before the prior length guard, and GCC's inlining exposed insufficient
size reasoning in a builtin-key failure case. Preserve part release/output
behavior and strict compiler warnings. Overflow must reach the existing memory
failure path before allocation or byte access.

Keep the final delimiter lower bound explicit before allocation and copying.
The captured GCC 15 reproducer compiles warning-free with that invariant
check; checked accumulation alone still triggered its inlined array-bounds
warning. No warning suppression, alternate byte copy or oracle change.
