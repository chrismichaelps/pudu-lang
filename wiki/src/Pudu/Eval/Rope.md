---
type: module
path: "@root/src/Pudu/Eval/Rope.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, text, performance]
aliases: [Eval Rope]
---
# Eval Rope
## Purpose
Hold a text built by `+` as the chunks it was appended from, so a loop that builds text a piece at
a time copies at most a small tail per step instead of everything written so far.
## Interface
`ropeOf` wraps a text, `ropeAppend` appends one rope's text to another, and `ropeText` answers the
whole text. [[Eval Value]] keeps plain text in `FlatText` and a rope in `RopeText`; the `StrValue`
pattern reads either as its whole text and builds `FlatText`, so no reader sees the difference.
## Governance and algorithm
The whole text is a lazy field joined from the chunks the first time it is read and kept, so a text
built by appending and read once is joined once. Appending never reads the left side's text. The
last chunk grows by copy while it and the piece fit in 1024 bytes; past that it is finished and the
piece begins a new chunk, so short pieces gather into a few large chunks rather than one node each.
The right operand is read whole, as a piece.
## Grill Log
- **Q:** Keep text strict and teach the evaluator to recognise `x = x + y`? **A:** No. _Rationale:_ a
  text is appended to through fields, tuples, returns, and helpers as often as through one local, and
  a syntactic special case would miss them. _Rejected:_ in-place mutation, which values shared
  between bindings forbid.
- **Q:** Wrap every text in a rope? **A:** No. _Rationale:_ a decoded document holds hundreds of
  thousands of texts that are never appended to, and a box per text is memory with no return.
  Only `+` produces `RopeText`. _Rejected:_ one node per piece, which costs more than the bytes.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Value]] · [[Eval Operator]]
