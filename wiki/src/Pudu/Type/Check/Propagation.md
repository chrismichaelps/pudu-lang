---
type: module
path: "@root/src/Pudu/Type/Check/Propagation.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, checker, lint]
aliases: [Check Propagation]
---

# Check Propagation

## Purpose and interface

`reportRedundantPropagation` emits `W3003` for a `match` whose every failure arm rebuilds the
failure it received while the enclosing function carries the same carrier, as
[[ADR-0011-propagation-over-re-matching]] states. `markBodyResult` and `markResultSpine` record
which expressions stand in result position, before the checker reaches them.

## Algorithm

The result spine starts at a function or closure body's tail (or its expression body) and at every
`return` operand, and continues through block tails, both branches of `if` and `if let`, and every
`match` arm body. Spans are recorded in checker state top-down, so a match learns its position when
it is checked. An arm `=> Err(e)`, `=> { Err(e) }` or bare `=> None` passes a failure through only
on the spine; an arm written `=> { return Err(e) }` leaves the function wherever it stands. A
guarded arm, a transformed payload or a changed carrier is a decision.

## Grill Log

- **Q:** Judge a value-form failure arm by the enclosing return type alone? **A:** No; a match
  bound with `let` keeps `None` and continues, and the suggested `?` would return early instead,
  changing behavior. Only result position makes the value the function's answer.
- **Q:** Walk every function body a second time to find positions? **A:** No; the spine is marked
  as the checker enters bodies and `return` statements, which it visits anyway.

## Referenced by

[[Type Check Statement]] · [[Type Env]] · [[grammar/pudu]]
