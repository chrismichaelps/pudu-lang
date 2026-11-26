---
type: module
path: "@root/src/Pudu/Type/Ownership.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Type Checker]]"
grammar: "[[grammar/haskell]]"
tags: [module, ownership, type]
aliases: [Type Ownership]
---

# Type Ownership

## Purpose

Check every body of a checked module for the ownership rules a value needing
drop requires: one owner, a move at each by-value use, no use after a move,
no partial move, no escape into a holder or closure, and no explicit `drop`
call. Answer the spans of the uses that move and the binders that own, so both
engines can act on the same facts.

## Interface

`checkOwnership :: Module -> Checker (Set Span, Set Span)`. The first set is
the moving uses, the second the owning binders. `Type.Check` runs it for the
whole module after literal finalization and obligation discharge.

## Algorithm

The walk reads the facts checking already settled: every expression's type,
the receivers of declared methods with whether each is taken by value, and the
prelude values a call only reads. It keeps a scope stack, a map from binder
identity to definite or possible moves, and a flow state that becomes absent
after an unconditional transfer.

- A binder whose settled type needs drop owns its value.
- A by-value use of an owning local moves it; a read after a definite move is
  E4001, and a read after a possible move is E4001 with the uncertain wording.
- Assignment to a local reinitializes it, so a moved writable local becomes
  usable again.
- Branches join moves; a move on only some paths is possible. A loop body is
  walked twice, so a move in the body is a use after a move on the next turn.
- A closure body sees the names it captures; capturing an owning value is
  E4004.
- A `Drop` implementation is checked for shape before any body runs.

## Diagnostics

| Code | Meaning |
| --- | --- |
| E4001 | use of a moved value, definite or possible |
| E4002 | partial move of a droppable field, or taking apart a type with its own `Drop` |
| E4003 | explicit call to `drop` |
| E4004 | a holder, closure capture, module value or builtin operand would keep a value needing drop |
| E4005 | a droppable temporary is only read, so nothing owns it |
| E4006 | a droppable value is stored into a field, reference or record update |
| E4007 | a pattern leaves a droppable part unbound |
| E4008 | a `Drop` implementation has the wrong target, member, receiver or result |

Every refusal carries a help that names the safe alternative. The walk reports
once per span and code.

## Negative Logic

Values that need no drop are not tracked: they keep the reading semantics
every program had before ownership mattered. A builtin that only reads its
operands does not consume them. A receiver taken by reference is read, not
moved; only a receiver taken by value consumes.

## Edge Cases

A conditional move followed by a use is refused even when one branch does not
move, because the use may see the moved value. A move inside a loop is refused
on the next turn. A `let _ = value` is a statement whose subject is consumed
and owned; it is not a binding named `_`.

## Resolved Grill Log

- **Q:** Why run ownership after type checking rather than during it? **A:**
  The walk needs the settled type of every expression, including generic
  instantiations and selected methods. _Rationale:_ deciding a move before the
  call's receiver is known would guess.
- **Q:** Why walk a loop body twice? **A:** The first pass discovers the moves
  a later turn can see; the second reports them with the final scope state.
  _Rationale:_ a move in a loop is exactly the case a single pass misses.
- **Q:** Why is a module value refused instead of dropped at exit? **A:** A
  module value outlives every function, so there is no ownership end to drop
  at. _Rationale:_ a process-lifetime resource needs an explicit close, not an
  implicit one.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Drop]] · [[Type Ownership Flow]] · [[Type Ownership Pattern]] · [[Type Ownership Declaration]] · [[Type Check]] · [[Ownership Marks]]
