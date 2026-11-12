---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Lanes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Lanes]
---
# Native Host Lanes

Export the family's runtime parts and their prerequisites.

Packed binary64 lanes held in byte sequences. A kernel that finds its operands outside what it takes leaves the state that reads as None.

## Resolved Grill Log

Each kernel keeps the interpreter's operation order, so sums and products round the same way; floating contraction is off for them.

## Broad phase (#846)

`pudu_host_lanes_overlap_pairs` answers as `Pudu.Runtime.Broadphase`: None for
lanes of different counts, a NaN bound or a minimum above its maximum; otherwise
boxes sorted by minimum x with ties by index, each swept against the following
boxes while their minimum x does not pass its maximum, touching boxes
overlapping, and the pairs (smaller index first) sorted and flattened.

Resolved Grill Log: sort then sweep, as the interpreter does, rather than test
every pair. The pair buffer grows by doubling with overflow checks.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]]
