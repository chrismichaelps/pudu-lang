---
type: module
path: "@root/src/Pudu/Compiler/Lower/Swiss.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Swiss]
---
# Compiler Lower Swiss

Export lowerSwissPrimitive and swissCallable for the six flat-table
primitives. The table type must be laid out as `capacity: Int`, `count: Int`,
`ctrl: Buckets[UInt64]`, `slots: Buckets[(UInt64, V)]`.

| Primitive | Core |
| --- | --- |
| swissTableEmpty | negative capacity refuses with E7004; else the record with a rounded capacity, zero count and two empty stores |
| swissTableSize | the `count` field |
| swissTableEntries | the values of `slots`, in slot order |
| swissTableLookup | `Some` of the pair's value at the slot the find kernel answers, else `None` |
| swissTableInsert | the insert kernel over the table and the (key, value) pair |
| swissTableDelete | the delete kernel over the table and the key |

## Resolved Grill Log

Field reads, store reads and Option construction stay in Core; only probing,
rehashing and the control words run in the runtime. A table of any other
layout refuses at the call. Rejected: probing loops written as Core.

## Referenced by

[[Compiler Lower Primitive]] · [[Compiler Lower Intrinsic]] · [[Native Builtin Kernels]]
