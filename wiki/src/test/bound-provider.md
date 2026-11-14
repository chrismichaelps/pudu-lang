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

## Structural implementation witnesses (#735, #782)

Execute reordered, nested, transparent-alias and repeated-binder heads, plus
method-local type arguments, exact outputs and positioned invalid bounds.
Retain existing provider controls and warm inode checks across both evaluators
and off/cold/warm products. Resolved Grill Log: swapped and double-nested output
failed before matching; method-local witnesses must not overwrite impl binders.
The original bounded receiver dispatch remains required before #735 closes.

Explicit and retained static calls preserve method arguments; wrong result, arity,
missing bound, repeated-head mismatch, ambiguous bounds and explicit value-shadow
application retain positioned E3001/E3003/E3005/E3012/E3013/E3028.
