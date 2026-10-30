---
type: module
path: "@root/test/bound-provider.mjs"
fidelity: Active
aliases: [Bound Provider Gate]
tags: [module, test, compiler, runtime]
---
# Bound Provider Gate

Run the real compiler on generic direct, alias, retained and default method calls with distinct
trait return types, primitive and record receivers and both implementation declaration orders.
A separate pair of modules exports generic functions bounded by distinct canonical traits both
named Wire; their implementations share Int.encode, so a basename-only key must fail.
Two distinct generic parameters may instantiate to the same runtime type but retain different
providers. Test tree and compiled evaluation with cache disabled, cold and warm; require exact
stdout, exit status and unchanged cache entry inode identities on the warm run. Check positioned
E3013 ambiguity, E3001 wrong result and E3012 missing bound. Temporary sources and caches are removed.

## Resolved Grill Log

- Literal receivers can hide provider typing defects; use annotated nominal values.
- Merely checking a generic body is insufficient; execute and consume its result.
- Cache output parity requires evidence entries are reused, not only two equal outputs.
- This gate covers evaluator modes, not unfinished native C11 generic dispatch.

## Referenced by

[[Repository Gates]] · [[Bound Provider Delivery]] · [[src/_MOC]]
