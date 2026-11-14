---
type: module
path: "@root/test/Pudu/Backend/ExpressionBodyPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Expression Body Programs]
---
# Backend Expression Body Programs

Export expressionBodySuccessPrograms as named complete-source/explicit-output
triples and expressionBodyRefusalPrograms as named runtime-failure sources.
Native and counted-allocation harnesses use these same cases.

## Resolved Grill Log

Cover expression entries, scalar and owned helper results, calls through
values, generic copies, methods/trait defaults, argument effects, `return`
and `?` inside expression blocks, direct/mutual recursion, and exact runtime
failure spans. Depth probes derive from the language callDepthLimit. Successful
cleanup cases exit zero. No generated C or oracle adjustment occurs here.

## Referenced by

[[Native Expression Bodies]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[src/Pudu/Backend/_MOC]]
