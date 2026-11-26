---
type: handoff
status: ACTIVE
issue: 1028
aliases: [Drop Moves Unwind Delivery]
---

# Drop Moves Unwind Delivery

Architect → Backend Engineer → Test Engineer. Branch
`feature/1028-drop-moves-unwind` starts from `dev`. This pass owns
[[Type Ownership]], [[Eval Drop]], [[Compiler Lower Drop]],
[[Backend Drop Programs]] and the native frame drop table.

## Next action

Open the #1028 pull request to dev with focused and full validation evidence,
then request the independent wiki-parity review.

## Delivered

Checker: a whole-module ownership walk after types settle. A value needing drop
has one owner; a by-value use moves it, a read after a definite or possible
move is E4001, a partial move is E4002, an
explicit `drop` call is E4003, a holder, capture or module value is E4004, a
read-only temporary is E4005, a field store is E4006, an unbound droppable
pattern part is E4007 and a malformed `Drop` implementation is E4008, and taking apart a `Drop` type is E4009. The
moving uses and owning binders travel in the settled module as `::move` and
`::owned`.

Interpreter: owned locals, parameters and temporaries drop on `Done`,
`Unwound` and `Aborted`, newest first, with a type's own `drop` before its
parts. A replacement drops the old value before the store; `let _ = value`
drops immediately; a stop during cleanup still runs the remaining drops.

Native: one glue function per needs-drop type and a per-function drop table
that runs before frames unwind. `dropSuccessPrograms` and `dropStopPrograms`
match interpreter traces, the success corpus is counted for allocations, and
`OwnershipSpec` asserts the code, span, message and help of E4001–E4009.
Async functions and async lambdas hand owned parameters to their task, which
drops them when it ends.

## Referenced by

[[handoffs/_MOC]] · [[NATIVE-EMISSION]] · [[NATIVE-OWNERSHIP]] · [[Type Ownership]] · [[Eval Drop]] · [[Compiler Lower Drop]]
