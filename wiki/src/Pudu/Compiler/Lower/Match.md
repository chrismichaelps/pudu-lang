---
type: module
path: "@root/src/Pudu/Compiler/Lower/Match.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Match]
---
# Compiler Lower Match

## Purpose and interface

Export `lowerMatch`: the subject once, then each arm's pattern, guard and body
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
