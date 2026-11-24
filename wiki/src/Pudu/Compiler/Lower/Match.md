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

## Generic records (#552)

Pattern update only: `CoreRecordType` has an argument list; behavior is unchanged.

## Pattern export (#554)

Resolved Grill Log: export `lowerPattern`, which [[Compiler Lower For]] uses for
its binder.

## Sequence patterns (#558)

Resolved Grill Log: `[a, ..rest, z]` lowers to `CoreArrayPattern` with the
front items, the rest (absent, skipped, or bound to a local) and the back
items. A rest name an earlier alternative already bound reuses its local.

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

## Checked paths (#798)

Constructor and record patterns name their variant or record through
`writtenLabel`, so canonical keys and `::sum::` paths from checking match.

## Sequence patterns in `let` (#846)

`let [a, ..rest] = subject`, nested in tuples or records at any depth, tests
only the sequence's length. The subject runs once, then the pattern binds on a
match arm whose wildcard stops with E7013 at the pattern, naming the record,
tuple or array it was given. `hasSequencePattern` finds the test anywhere
inside, and `lowerLetSequence` leaves an ordinary `let` untouched. Resolved
Grill Log: reuse CoreMatch rather than generate a comparison per element; the
interpreter's E7013 message and hint are preserved.

## Checked aggregate arm joins (#956)

Resolved Grill Log: when the arm carriers differ, use the checked result
carrier if widening every reachable arm succeeds. An aggregate can contain
dynamic members at any depth, and guards remain outside the widened result.

## Nominal narrowing of dynamic values (#956)

Resolved Grill Log: checked record and constructor patterns carry a
canonical owner. Match the outer dynamic tag by that owner, then reuse
the ordinary pattern for the payload. A named sum additionally tests its
own variant tag. Identical display names across declarations never select
the same dynamic alternative. The existing pattern path owns guard,
fallback, nesting and binding behavior.

## Narrowing through the payload owner (#956)

Resolved Grill Log: use the checked pattern owner to select the held
nominal type and test that alternative's tag. Tag spelling remains internal
to the dynamic layout.

## Narrowing multiple instantiations of one owner (#956)

Resolved Grill Log: a nominal test selects every tag of that owner and
reuses the same bound locals across those alternatives. Refuse a binding
if a payload would need an incompatible local carrier. Matching an
ordinary field shared by every instantiation uses its declared layout.

## Runtime layouts in products (#956)

Resolved Grill Log: Match arms with differing native product layouts project to their shared layout after each guard and body. Pattern types still come from the subject carrier.

## Runtime layouts in sum payloads (#956)

Resolved Grill Log: Normalize compatible selected sum carriers before lowering source patterns. Each payload binder gets its actual slot type.

## Held shapes in refutable patterns

Resolved Grill Log: select the held shape before lowering match arms.
Structurally impossible arms skip their guards and bodies. Sequence
binding failure names the held subject, and let-else uses its fallback
when the selected pattern is impossible.

## Escaping refutable bindings

Resolved Grill Log: each held subject layout and written alternative
gets private pattern locals. A successful arm projects those values
to shared enclosing slots after the complete pattern matches.
Failure sees only the original scope.

## Nested alternative binding layouts

Resolved Grill Log: isolate captures in every alternative and project
new names to shared slots after that alternative matches. Use the
same projection for selected runtime tags and written alternatives.
A guard runs once after the first structural success.

## Statically impossible loop binders

Resolved Grill Log. Export the structural impossibility check to
[[Compiler Lower For]]. The same check that skips unreachable match arms
also skips a loop body whose binder cannot match the retained element.

## Canonical owner checks on held patterns

Resolved Grill Log. Executable constructor and named-record paths carry
canonical owners. Check that owner before inspecting same-label variants
or same-named records. A named sum payload path applies only to a named
variant. Preserve the evaluator's short-name matching for paths without
a resolved owner. [[Backend Rendering Callable Programs]]
