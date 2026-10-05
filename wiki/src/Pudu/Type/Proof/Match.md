---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Proof/Match.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, trait, inference]
aliases: [Trait Evidence Matching]
---

# Trait Evidence Matching

## Purpose and interface

Own opaque Evidence and Matched/Mismatched/MatchLimit products. `matchRule` freshens
an implementation's parameters and matches its target and optional application.
`matchBound` matches full scoped evidence. `abstractGoal` copies authorized caller
holes in target and demand together for the separate call-inference boundary.
`resolveEvidence`, `stepEvidence`, `beginEvidence` and `resumeEvidence` support
bounded recursive proof without changing checker variables.

## Algorithm and invariants

Private variables use negative TypeVar identifiers allocated under a bounded
per-search counter; checker variables are nonnegative. Only registered private
variables bind. Substitute rule parameters, then structurally match both heads.
Repeated parameters stay correlated. Conditions can determine a parameter that
appears only in a trait application, such as Sequence state.

Occurs checking prevents cyclic evidence. Substitution preserves references,
tuples, functions with default arity, unsafe capabilities and applied constructors.
Failed alternatives restore prior bindings while retaining fuel and the allocation
frontier. Bare nominal target rules retain the existing constructor-wide contract.
Every allocation and structural match consumes work; exhaustion returns MatchLimit.

## Negative logic and edge cases

`overlapRules` freshens both implementation binders independently in one isolated
Evidence and matches target and complete trait heads with the same structural
matcher. Bounds never justify overlapping dispatch heads. Preserve constructor
wide bare nominal target contracts; retain exact function default arity, unsafe
capabilities and canonical trait arguments. Exhaustion yields MatchLimit rather
than guessing disjointness. Resolved Grill Log: use exact evidence matching, not
ordinary assignment unification where Never and default arity have join rules.

No caller unification, global counter, rigid-name capture, body checking or IO.
Ordinary proof holds caller variables fixed. Only explicit call inference copies
holes; canonical type owners remain fixed. No private variable escapes into compiler
products or runtime selection. The proof boundary checks complete proposals.

## Grill Log

- **Q:** Require every parameter in the target head? **A:** No; recursive evidence
  may determine it. _Rationale:_ iterator wrappers retain state through Sequence
  even when absent from their target. _Rejected:_ caller rigid-name capture or
  rejecting those existing iterators.
- **Q:** Use caller inference while searching? **A:** Use isolated Evidence.
  _Rationale:_ failed alternatives cannot affect typing. _Rejected:_ checker
  unification or resetting work when an alternative fails.
- **Q:** Copy target and demand holes separately? **A:** Use one mapping.
  _Rationale:_ a shared parameter is one unknown. _Rejected:_ losing correlations.

## Referenced by

[[Type Trait Proof]] · [[Type Implementation Rules]] · [[src/Pudu/Type/_MOC]]

## Conditional premise evidence

`assumeBound` records one full trait application for a named rigid subject in
private evidence, charging search work. `evidenceRequirements` projects the
successful evidence's deduplicated applications after local substitution.
`resumeEvidence` rolls these premises back with bindings while retaining consumed
fuel and the fresh-variable frontier. The shared proof policy is the sole caller
authorized to introduce assumptions; ordinary proof never calls this operation.

Resolved Grill Log: keep tentative inferred requirements inside the same rollback
boundary as matching. Do not retain requirements from failed candidates, refund
work or modify caller checker bounds.
