---
type: module
path: "@root/test/Pudu/Backend/CollectionCallablePrograms.hs"
fidelity: Active
aliases: [Backend Collection Callable Programs]
---
# Backend Collection Callable Programs

Export collectionCallableSuccessPrograms (explicit stdout/stderr) and
collectionCallableRefusalPrograms (runtime failures). Successes cover the four
builtins called through annotated locals, unconstrained builtin values that
are only compared or shown, two signatures of mapOf and three of setOf in one
program, generic callers, record fields, captures, returned values, arrays of
callables, every charFromCode scalar boundary, source and local shadowing, an
entry returning a builtin, and the caller-site key check passing for keys
that could hold a function but do not. Refusals cover E7008 through a plain
value, a record field, a generic caller and a nested value call, and an
argument that fails before the builtin runs.

## Resolved Grill Log

Expectations were taken from the tree interpreter and checked against the
compiled evaluator; both still run beside the native build in every case.
Refusals compare exact stderr, so a native error pointing at the reference
instead of the call fails. The healthy programs also run under the counted
allocation wrappers through the shared callable corpus.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

## Referenced by

[[Native Collection Callables]] · [[src/Pudu/Backend/_MOC]]
