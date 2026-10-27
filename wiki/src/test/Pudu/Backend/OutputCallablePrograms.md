---
type: module
path: "@root/test/Pudu/Backend/OutputCallablePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Output Callable Programs]
---
# Backend Output Callable Programs

Export outputCallableSuccessPrograms with explicit stdout/stderr answers and
outputCallableRefusalPrograms with named runtime-failure sources. Exercise all
four builtin tags as values through containers, returns, captures, generic calls,
shadowing, rendering and equality, plus exact call-depth boundaries. Failure
cases preserve dynamic builtin/function kind names for operators and keys.

## Resolved Grill Log

Both evaluator paths are oracles; explicit byte answers prevent agreement on
an accidental rendering. Count all owned allocations for success cases. A
builtin call at the deepest source frame must succeed; a user function in the
same typed slot must still observe E7002. Failure spans come from actual checked
source, and constants derive from the shared callDepthLimit.

## Referenced by

[[Native Output Callable Values]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[src/Pudu/Backend/_MOC]]

Export outputCallableFailureCleanup for an isolated counted run with both
outputs connected to pipes without readers. Loop through all four tags and
consume Err payloads repeatedly, including full-buffer writes. Normal status
must be zero; failure details are independently checked by OutputSpec.
