---
type: module
path: "@root/lib/Std/Text/Parse.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, parser]
aliases: [Std Text Parse]
---
# Std Text Parse
## Purpose
Build deterministic text parsers from `Parser[T] = fn(Input) -> Step[T]`, with positioned failures.
## Interface
Exports parser state/problem types, runners, primitives, sequencing/choice/repetition combinators, numeric/text parsers, lookahead, labels, and source-position explanations.
## Governance and algorithm
Every successful step returns the remaining input and position; alternatives backtrack only through `attempt`, repetition must advance, and integer parsing checks the requested width.
## Grill Log
- **Q:** Why is backtracking explicit? **A:** Consumed input is a decision unless the author marks the parser speculative. _Rejected:_ unconditional retry that hides expensive ambiguity.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
