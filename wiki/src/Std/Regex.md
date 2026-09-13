---
type: module
path: "@root/lib/Std/Regex.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, regex, text]
aliases: [Std Regex]
---
# Std Regex
## Purpose
Compile and run regular expressions over text, with the bounds a pattern written by someone else
needs.
## Interface
Exports `Regex`, `Match`, `RegexError`, `compile`, `unmatchable`, `stepLimit`, `search`, `find`,
`isMatch`, `isExact`, `findAll`, `capture`, `replaceFirst`, `replaceAll`, `replaceAllWith`, `split`,
`escape`, and `explain`.
## Governance and algorithm
A pattern is compiled once into a flat program with relative jumps, and a search runs it with its own
resume stack rather than the call stack, so how deeply a pattern nests does not decide how much stack
a match costs. Positions are character offsets.

Two bounds keep a hostile pattern from stopping a program. A search runs at most `stepLimit`
instructions: `search` reports `StepLimit`, and `find` and `isMatch` answer no match, the safe
direction for a filter. Compiling recurses through its readers once per open group, so a group that
would nest more than 256 levels deep answers `TooDeep` at its opening bracket instead of exhausting
the evaluator's call limit. A bounded repetition is written out, capped at 1,000 optional copies.
## Grill Log
- **Q:** Walk the pattern as a tree while matching? **A:** No. _Rationale:_ the call stack would then
  depend on the pattern. _Accepted:_ a flat program with its own resume stack.
- **Q:** Bound a search by time? **A:** No. _Rationale:_ the same input must decide the same way on
  every machine. _Accepted:_ a step count.
- **Q:** Let group nesting recurse until the evaluator's call limit? **A:** No. _Rationale:_ that
  limit stops the whole program, and patterns come from configuration and forms. _Accepted:_ a
  256-level bound answered as `TooDeep`.
## Referenced by
[[src/Std/_MOC]] · [[Std Glob]] · [[architecture/STDLIB]]
