---
type: module
path: "@root/test/Pudu/Backend/RangePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Range Programs]
---
# Backend Range Programs

Exports rangeSuccessPrograms and rangeRefusalPrograms, for
[[Native Range Values]].

Resolved Grill Log: every range shape, rendered and displayed; every method
on bounded, unbounded, empty and single-value ranges; `map` with a printing
closure; a range returned from a function and walked; slicing arrays and Str
by range values; equality, ordering in tuples, ranges as map keys and set
members; and lengths at the Int limit. The refusals are each method's
failure on a missing end, `length` and `sum` past Int, zero and negative
steps, iterating an unbounded range, and slices out of bounds or reversed.

## Referenced by

[[Native Range Values]] · [[Backend Module Programs]] · [[Backend Text Leak Tests]]
