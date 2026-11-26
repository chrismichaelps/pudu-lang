---
type: module
path: "@root/test/Pudu/Type/Check/OwnershipSpec.hs"
fidelity: Active
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, type, ownership]
aliases: [Type Check Ownership Spec]
---

# Type Check Ownership Spec

## Purpose

Prove the checker's ownership rules for values needing drop: moves, use after
a move, partial moves, escapes into holders and closures, explicit `drop`
calls, pattern ownership and the shape of a `Drop` implementation.

## Interface

`moveProperties` contributes three groups to the runner.

## Algorithm

The spec compiles complete modules with a `Res` type that implements `Drop`,
a `Holder` record with a droppable field, a generic `make[T](f: fn() -> T)`,
and a trait `Keep` with `async fn keep(self: Self)` implemented for `Res`.

The first group checks codes:

- borrowing and moving once is clean;
- a definite use after a move is E4001;
- a use after a move on only some paths is E4001;
- a move in a loop is E4001 on the next turn;
- assigning a moved writable local makes it usable again;
- moving a droppable field alone is E4002;
- taking apart a `Drop` type is E4009;
- an explicit `drop` call is E4003;
- an array, a closure capture and a module value are E4004;
- a read-only temporary is E4005;
- a field store is E4006;
- an unbound droppable pattern part is E4007;
- a wrong `Drop` member or receiver is E4008;
- an owning task not awaited where it is made (`storedTask`) is E4010;
- a droppable value at a type parameter is E4011 at each instantiation: a
  direct call (`generic`), a borrow (`genericBorrow`, `peek(&r)`), a function
  value (`genericValue`, `let f = dup; f(Res)`), and a value a closure produces
  (`genericProduced`, `make(|| Res{...})`);
- a generic call at a type that needs no drop is clean (`genericPlain`:
  `dup(3)` and `make(|| 4)`);
- an owning async method called on a droppable receiver and not awaited where
  it is made (`selfTask`, `r.keep()`) is E4010;
- a dereference that would move a value needing drop out of a borrow
  (`derefMove`, `let c = *b`) is E4012;
- a pattern over a borrow that binds a part needing drop (`borrowedMatch`,
  `match b { case Some(x) => ... }`) is E4012;
- a trait default inherited by an implementation whose target needs drop
  (`traitDefault`, `impl Twice for Res {}`) is E4011 at the implementation;
- an async result that needs drop, awaited where it is made (`awaitedResult`,
  `let a = mk().await`), is clean;
- a bare and a qualified nullary variant (`nullary`) are clean.

The second group asserts the exact contract for one fixture per code, E4010,
E4011 and E4012 included: code,
span start, message and help, through `diagnosticContract`. The E4011 needle is
the `dup(...)` call; the E4012 needles are the `*b` dereference and the `x`
bound by the pattern over a borrow.

The third group checks that a `Drop` implementation with another member or a
shared `self` is E4008.

## Negative Logic

No snapshot is accepted. The span is the start of the construct the reader
must point at; the help must name the safe alternative. A fixture that grows a
second diagnostic fails the contract property.

## Edge Cases

The field-store fixture writes into a mutable record field, not a local. The
pattern fixture matches `Some(_)` over `Option[Res]` so the wildcard is the
unbound part, not the whole value. The borrowed fixtures borrow a value and
then try to take a part of it, so the refusal is about the borrow and not
about the borrower's own owner.

## Resolved Grill Log

- **Q:** Why both code-level and full-contract properties? **A:** The code
  list catches a new refusal appearing; the contract catches a refusal moving
  to the wrong span or losing its help. _Rationale:_ a code-only test would
  pass a diagnostic the reader cannot act on.
- **Q:** Why is a move in a loop refused on the next turn? **A:** The loop
  head joins the entry state with the back edge, so the second turn may see
  the moved value. _Rationale:_ the rule is the ordinary join, not a special
  loop rule.
- **Q:** Why does `let _ = value` drop immediately rather than bind `_`? **A:**
  A wildcard keeps nothing; a binding named `_` would own the value until the
  scope end. _Rationale:_ the source spelling says the value is discarded.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Ownership]] · [[Type Check Pattern Spec]] · [[Backend Drop Programs]]
