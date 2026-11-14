---
type: module
path: "@root/src/Pudu/Core/Keyed.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Core Keyed Operations]
---
# Core Keyed Operations

Own the closed CoreKeyedMethodName enum, reexported unchanged through Pudu.Core.
Include the four word-map algebra tags. No execution, inference or C spelling.

## Resolved Grill Log

Extract the existing enum to keep Core.hs below 500 lines. Existing constructors
retain their names; new word operations require Map[K, UInt64] operands/results.
There is no persisted Core ordinal or change to the frame-cell layout.

## Referenced by

[[Pudu Core IR Module]] · [[Compiler Lower Word Map]] · [[Backend Frame Values]]

## Query contract (#814)

Add KeyedWordSubset, KeyedWordDisjoint, KeyedWordPopCount and KeyedWordMembers. Predicates return Bool from identical UInt64-valued maps; count returns UInt128; members requires UInt64 keys and returns Array[UInt64]. No cell ABI change.

Resolved Grill Log: project existing checked semantics; no inference, fallback, unsafe cell reinterpretation or frame ABI change. Reuse granular runtime dependencies and existing numeric/array ownership kernels.

## Indexed stores (#840)

KeyedPut inserts with the new key's spelling replacing an equal held key. KeyedMixHash and KeyedHash take the hashed value itself as the receiver and answer an Int. Resolved Grill Log: the two hashes ride the keyed family instead of adding a Core and frame shape each; the emitter validates the receiver's carrier.
