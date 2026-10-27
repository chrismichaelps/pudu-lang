---
type: module
path: "@root/src/Pudu/Compiler/Lower/Match.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Match]
---
# Compiler Lower Match

## Purpose and interface

Export `lowerMatch`, `lowerLetElse`, `ifLetArms` and `whileLetLoop`: the subject once, then each arm's pattern, guard and body
in a scope of its own, as `CoreMatch`.

- Patterns: wildcard, binding, literal, range, tuple, constructor, record
  (including record variants, filling unnamed fields with wildcards) and
  alternatives. Alternatives bind the same names to the same locals.
- An integer literal pattern is built at the subject's kind; one the kind
  cannot hold never matches, as `sameValue` compares by value. A float literal
  of another width never matches.
- A discarded match evaluates each arm and drops it, so an arm may end in
  `print`.

## Grill Log

- **Q:** How do `if let` and `while let` lower? **A:** As a match, through `ifLetArms` and `whileLetLoop`. `if let P = e { A } else { B }` is the arms `case P => A` and `case _ => B`, so the subject runs once and the bindings live only in `A`. Without `else`, or as a statement, every arm's value is dropped, which is the evaluator's unit result. `while let` is a `loop`, carrying the label, whose body matches the subject read afresh each turn and whose fallback arm breaks. Rejected: dedicated Core forms, since a match already carries every pattern, scope and refusal (#540).

- **Q:** How does a record pattern's written type match? **A:** Against the record's display name, since Core names it by canonical key (#539).

- **Q:** Why build integer literals at the subject's kind? **A:** The
  evaluator compares integers by value whatever their kinds, so a literal
  outside the kind's range is a pattern that never matches, not a refusal.
- **Q:** What when arms disagree on type? **A:** The checker already joined
  them; a disagreement here is a native boundary and refuses with E6001.

## Referenced by

[[Compiler Lower Body]] · [[Compiler Frame Match]] · [[src/_MOC]]

## Refutable bindings

`lowerLetElse` evaluates the subject once and lowers the fallback before
introducing the pattern's locals. The fallback must lower to Never. The success
arm is unit and binds into the enclosing scope, so subsequent statements may
read those locals. The fallback is a wildcard arm and retains return, break,
continue, effects and source spans. A Never subject is preserved directly.

Resolved Grill Log: reuse CoreMatch and its existing frame pattern tests; do
not wrap the rest of the source block in a generated syntax scope or re-read
the subject. Lowering the fallback before binding protects shadowed outer
names even if an earlier pattern component matched before a later one failed.
Unsupported subject carriers and patterns retain located E6001 refusals.
