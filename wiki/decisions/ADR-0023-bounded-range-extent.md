---
type: decision
status: ACCEPTED
date: 2026-09-19
tags: [decision, language, ranges, diagnostics]
aliases: [ADR-0023-bounded-range-extent]
---

# ADR-0023: A Range Has an Extent Only When Bounded

## Context

A range stores an optional start, an optional end, and whether its written end is inclusive.
`length()` originally answered zero whenever either end was absent. That made `1..`, `..5`, and
`..` indistinguishable from the empty bounded range `3..3`, while `isEmpty()` correctly answered
false for the open forms. The two methods therefore made contradictory claims about one value.

The evaluator also admitted a sequence pattern over a tuple even though the checker rejects it. A
sequence pattern assigns one element type to every named position and to its rest; tuple positions
may have different types. This path was unreachable from a checked program, but leaving the two
phases inconsistent made the evaluator an unreliable semantic oracle.

## Decision

`Range[Int].length()` has a value only when the range has both a start and an end. On `a..`, `..b`,
or `..`, it reports runtime diagnostic `E7004` at the method call with:

```text
length needs a range with both ends
help: check isBounded first, or give the range a start and an end
```

`isBounded()` is the predicate for this boundary. `isEmpty()` remains false for an unbounded range,
and `contains(value)` remains defined because each absent end removes a restriction rather than
requiring enumeration. Methods that enumerate values already require both ends and retain `E7004`.

A sequence pattern applies to an array only. A tuple is destructured with a tuple pattern. The
evaluator follows the same boundary even when called directly by a test or a future compiler phase.

## Compatibility

Before:

```pudu
let span = 1..
span.length() // 0
```

After:

```pudu
let span = 1..
if span.isBounded() { span.length() } else { 0 }
```

The old zero was observable successful behavior, so this is a breaking semantic correction and
advances the independent semantic revision to `1.0.0-draft`. Migration is mechanical: use
`isBounded()` before asking for an extent, or supply both ends. No syntax, type, or public standard
library declaration changes.

## Diagnostics and conformance

- `E7004` is the existing runtime boundary diagnostic for a value outside an operation's admitted
  range; no new diagnostic code is introduced.
- Interpreter tests assert the code, message, help, and method-call span for all three open forms.
- A direct evaluator regression asserts that an array sequence pattern matches and the same pattern
  over a tuple does not.
- The current native backend does not lower range methods independently. When it does, its
  `length`, `isEmpty`, `isBounded`, and `contains` observations must match the interpreter before the
  lowering is admitted.

## Consequences

- No range method presents an unknown extent as a known number.
- The checker and evaluator agree on which values a sequence pattern can match.
- Code that depended on the accidental zero now receives an actionable refusal instead of silently
  conflating an unbounded value with an empty one.

## Rejected

- **Keep zero for an absent end.** It contradicts `isEmpty()` and turns missing information into a
  valid measurement.
- **Return `Option[Int]` from `length()`.** That would change the method type for every bounded
  range even though only open ranges lack an answer.
- **Give an absent start an implicit zero.** `..5` is meaningful as a slice only because the value
  being sliced supplies the bound; a standalone range has no such value.
- **Let the evaluator match tuples as sequences.** It would preserve phase disagreement and claim
  one element type for a shape that does not have one.

