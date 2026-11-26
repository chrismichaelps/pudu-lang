---
type: module
path: "@root/src/Pudu/Type/Ownership/Flow.hs"
fidelity: Active
domain: "[[Ownership]]"
subsystem: "[[Type Checker]]"
grammar: "[[grammar/haskell]]"
tags: [module, ownership, type]
aliases: [Type Ownership Flow]
---

# Type Ownership Flow

## Purpose

Hold the move state the ownership walk carries through a body: scopes, binder
identities, definite and possible moves, loop transfers and closure
boundaries. This is the control-flow half of [[Type Ownership]]; the rules
that decide what moves live beside it.

## Interface

`Walk`, `Facts`, `Mode`, `runWalk`, `lift`, `facts`, `typeAt`, `refuse`,
`bindBinder`, `ownTemporary`, `withScope`, `withClosure`, `resolveBinder`,
`movedAt`, `markMoved`, `reinitialize`, `stop`, `branches`, `loopWith`,
`LoopShape`, `breakTo`, `continueTo`, `withFreshFlow`.

## Algorithm

`Facts` is what checking settled: expression types by span, declared-method
receivers with whether each is taken by value, and the prelude values a call
only reads. `Mode` says whether a position consumes its value or reads it.

A `Walk` is a state monad over `Checker`. The state holds a scope stack, the
next binder identity, the current move map (`IntMap Moved`), the enclosing
loops, whether the walk is reporting, the spans already reported, and the
moving and owning span sets `runWalk` returns.

- `bindBinder` introduces a name and, when its settled type needs drop, marks
  its binder span as owning.
- `resolveBinder` searches outward and says whether the search crossed a
  closure boundary; crossing is what makes a capture.
- `markMoved` records a definite move at the use span and adds it to the
  moving set. `movedAt` answers definite or possible. `reinitialize` deletes
  the move.
- `stop` makes the flow absent: nothing after an unconditional transfer runs.
- `branches` runs each alternative from the same start and joins the ends. A
  move definite on both ends stays definite; anything else becomes possible.
- `loopWith` walks the turn once silently, then again from the join of entry,
  fallthrough and every `continue`. A conditional loop leaves with the head
  state; an unconditional loop leaves only through `break`. The reporting
  walk is the second one, so a move in the body is seen as a possible move at
  the head.
- `withFreshFlow` gives a closure or nested function its own moves and loops;
  the outer flow returns unchanged.

## Negative Logic

`refuse` reports once per span and code, and only on a reporting walk. A loop
body walked silently reports nothing. A transfer outside any loop records
nothing and still stops the flow.

## Edge Cases

A `break` with a value is a transfer after the value is in hand. A labeled
transfer reaches the nearest loop with that label, skipping inner loops. A
closure's captures are read through the closure scope; its own moves never
reach an outer loop.

## Resolved Grill Log

- **Q:** Why store binder identities instead of names in the move map? **A:**
  Shadowing is legal, and a name-keyed map would let an inner binding inherit
  an outer move. _Rationale:_ ownership belongs to the binding, not the
  spelling.
- **Q:** Why is a join of definite and possible a possible move? **A:** The
  use may see either path, so the checker must reject it. _Rationale:_
  definite-only joins would accept a use after a conditional move.
- **Q:** Why walk a loop twice rather than iterate to a fixed point? **A:** A
  loop body's moves are discovered on the first pass; the second pass reports
  them against the joined head. _Rationale:_ one back edge is the whole
  language's loop shape, and two passes decide it without a solver.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Ownership]] · [[Type Ownership Pattern]] · [[Type Check]]
