---
type: module
path: "@root/test/Pudu/Type/FrontierSpec.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, performance]
aliases: [Type Literal Frontier Spec]
---

# Type Literal Frontier Spec

## Purpose and interface

Export named property families for [[Repository Test Runner]] that prove ordered
literal selection, bounded prefix work and unchanged width/defaulting behavior.
Register this module in [[Pudu Test Cabal Manifest]].

## Algorithm and evidence

Generate unique descending creation identities, including gaps, and compare
since/interval results with full filter specifications. Empty/reversed intervals
retain the whole queue. A test-only poisoned older tail proves that both queries
stop after the boundary and do not evaluate unrelated facts; this is deterministic
work evidence rather than a timing threshold. Loaded single-source cases prove
Int16 outer operands survive Int8 if/match branches, nested branch inference and
negative literals; wrong widths still report E3018.

## Negative logic and Grill Log

- **Q:** Assert checking takes less than one second in a property? **A:** No.
  _Rationale:_ wall time depends on the host; a poisoned unused suffix proves the
  required traversal boundary directly. _Rejected:_ fragile stopwatch tests.
- **Q:** Only test the pure selector? **A:** Also exercise actual checker width
  contexts and failures. _Rationale:_ a selection optimization must retain the
  caller's inference and diagnostic timing. _Rejected:_ mirroring source logic.

No golden refresh, implicit library cache or source mutation. The poison occurs
only in tests; production functions are total over finite valid queues.

## Referenced by

[[Type Literal Frontier]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]]
