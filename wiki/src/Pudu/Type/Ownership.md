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
no partial move, no escape into a holder or closure, no explicit `drop`
call, no owning task left unawaited where it is made, and no droppable value
where a type parameter stands. Answer the spans of the uses that move and the binders that own, so both
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
- A call whose result is a Task and that passes an argument needing drop is
  E4010 unless the call is the direct operand of `.await`. A receiver taken by
  value counts as an argument, so an async method taking `self` by value on a
  receiver needing drop is E4010 too. `ownedTask` tests for such a call.
- Every recorded instantiation of a generic value other than a constructor
  (`finalInstantiations`) is checked. `genericInstantiation` refuses, at the
  reference's span, each one that chose a type needing drop with E4011. This
  covers a direct call, a qualified call (`G.dup`, `Option.unwrapOr`), a
  function value (`let f = dup`), a method with its own type parameters, and a
  generic whose body produces the value. `Self` is a type parameter like any
  other: an instantiation that chose a type needing drop for it is E4011 too.
  A trait default is one body written for `Self` and the trait's parameters,
  so an implementation that inherits one records that instantiation at its own
  target and is refused there.
- A borrow does not exempt the instantiation, because a generic body can copy a
  value of a type parameter out through `&T`.
- Nothing moves out of a borrow. A dereference whose result needs drop is
  E4012, and a pattern over a borrow that binds a part needing drop is E4012
  at the binder: the owner of the borrowed value still owns it, so a copy out
  of it would be a second owner.
- An awaited call is owned by the scope that awaits it. The task it came from
  is not a holder here: `mk().await` yields the result and the awaiting scope
  drops it, so the value is not refused as something a task keeps.
- A call to a user-declared method on a receiver whose nominal type arguments
  need drop is E4011 (`genericReceiver`).
- A name with no local binder (function, constructor, module value) is not
  checked at its use, because a module value that needs drop is refused at its
  declaration (E4004). A member of a type or module qualifier (`Mode.On`) is a
  constructor or declaration, not a field move.

## Diagnostics

| Code | Meaning |
| --- | --- |
| E4001 | use of a moved value, definite or possible |
| E4002 | partial move of a droppable field |
| E4003 | explicit call to `drop` |
| E4004 | a holder, closure capture, module value or builtin operand would keep a value needing drop |
| E4005 | a droppable temporary is only read, so nothing owns it |
| E4006 | a droppable value is stored into a field, reference or record update |
| E4007 | a pattern leaves a droppable part unbound |
| E4008 | a `Drop` implementation has the wrong target, member, receiver or result |
| E4009 | taking apart a type with its own `Drop` |
| E4010 | a task that owns a value needing drop is not awaited where it is made |
| E4011 | a type that needs drop stands for a type parameter |
| E4012 | a value that needs drop is moved out of a borrow |

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

A nullary variant builds a value of a sum that needs drop, bare (`Empty`) or
qualified (`Mode.On`). At a type parameter neither a borrow (`&T`) nor a value is
exempt: a type that needs drop cannot stand for a type parameter at any
instantiation. An async method taking `self` by value is an owning task when its
receiver needs drop, so it must be awaited where it is made (E4010).

A dereference of a borrow (`*b`) whose result needs drop is E4012, and so is a
pattern over a borrow that binds a part needing drop: the owner still owns the
borrowed value, so a copy out of it would be a second owner. A trait default
inherited by an implementation whose target needs drop is E4011 at the
implementation, because the default body is written once for any type. An
awaited result that needs drop belongs to the awaiting scope and is dropped
when that scope ends.

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
- **Q:** Why must an owning task be awaited where it is made? **A:** Each
  await runs the body again, so a stored task would drop its arguments on every
  run, or never if it is not awaited. _Rationale:_ awaiting at the making site
  runs the body once and keeps one owner. _Rejected:_ memoizing task results,
  which changes cold task semantics.
- **Q:** Why refuse a droppable value at a type parameter? **A:** The generic
  body does not track values of a type parameter, so it can copy or lose one.
  _Rationale:_ every instantiation is checked, so the generic body never holds
  a value that needs drop. _Rejected:_ treating every type-parameter value as
  needing drop, which would refuse ordinary generic code that copies values
  needing no drop. _Rejected:_ exempting borrows, since a generic body can copy
  a value out through `&T`.
- **Q:** Is `Self` exempt because the receiver's own move rules own it? **A:**
  No. The receiver rules decide who owns the value at the call; they do not
  decide what a body written once for `Self` may hold. _Rationale:_ a trait
  default runs for every implementing type, so it cannot track a value of a
  type it does not know. _Rejected:_ keeping `Self` out of the recorded
  instantiation, which let a default hand out a value it never owns.
- **Q:** Why refuse a move out of a borrow instead of copying the value? **A:**
  The owner of the borrowed value still owns it, and a copy would be a second
  owner of one value that needs drop. _Rationale:_ the borrow rules already
  say a borrow is for reading. _Rejected:_ dropping the copy at the end of the
  borrowing scope, which would run a destructor for a value the owner also
  destroys.
- **Q:** Why is an awaited result owned by the awaiting scope? **A:** The await
  is the point where the task's result becomes the caller's value. _Rationale:_
  the value exists once, and the scope that holds it is where it is dropped.
  _Rejected:_ refusing it as a task that keeps a value needing drop, which
  refused the only spelling that hands the result over at all.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Drop]] · [[Type Ownership Flow]] · [[Type Ownership Pattern]] · [[Type Ownership Declaration]] · [[Type Check]] · [[Ownership Marks]]
