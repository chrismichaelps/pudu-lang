---
type: module
path: "@root/src/Pudu/Backend/Emit/CrossComparison.hs"
fidelity: Active
aliases: [Backend Cross Comparison]
---
# Backend Cross Comparison

## Retained constructor ordering

Resolved Grill Log. Compare canonical constructor identity across
callable layouts. Compare a constructor against a held sum as an
empty positional variant, including payload length when the tags agree.

Generate pairs of typed equality and ordering helpers for dynamic payloads
with different native layouts. Traverse dependent layout pairs once.
Each side is read through its own cell member. Nominal identities,
active variants, declaration-order fields, and ordered collection entries
decide comparison. Integer kinds remain distinct for nested equality, and
numeric ordering follows the interpreter's total order.

## Resolved Grill Log

A type instantiation is a layout key. The held value's owner and contents
decide equality and ordering. The helper graph must terminate for recursive
layouts and use ordinary demand-selected helper declarations. Traversal
borrows the values, and allocated tree snapshots are released before returning.
Rejected: comparing variant-tag ordinals or reading one layout through another.

## Referenced by

[[Native Aggregate Emission]] · [[src/Pudu/Backend/_MOC]] · [[Pudu Cabal Manifest]]

The graph also compares callable source sites across carriers and reads
the active callable shape when it is used as an order key.
