---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Implementation.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, trait]
aliases: [Type Implementation Rules]
---

# Type Implementation Rules

## Purpose and interface

`ImplementationRule` preserves a formed target, trait application, rigid parameters
and conditional requirements. `matchImplementation` matches a complete concrete
target and optional complete trait application, returning substituted requirements.
The model is pure with no checker or syntax dependency.

## Algorithm and invariants

Match canonical nominal identity and complete arguments. Bind only the rule's
parameters; repeated parameters select the same type. References, tuples, applied
constructors, capabilities and complete function contracts match structurally.
Bare nominal targets retain the existing constructor-wide contract; specialized
and explicitly applied heads match exact arguments. Substitute selected parameters
through every conditional subject and trait.
The pure fast path requires every implementation parameter selected by heads before
conditions are returned. An unselected rule parameter cannot capture a caller's
same-spelled rigid parameter or borrow that caller's unrelated capability.

## Negative logic and edge cases

No inference mutation, guessed implementation, basename comparison or unconditional
acceptance of conditional rules. Errors and unresolved arguments do not supply
evidence. Identity-only queries serve dynamic widening; complete applications serve Scheme
bounds and derive field obligations. [[Trait Evidence Matching]] handles parameters
determined by recursive conditions. Kind/bound formation
remains formation's responsibility.

## Grill Log

- **Q:** Store only target and trait owners? **A:** No; retain formed heads and
  conditions. _Rationale:_ Box[Int] is different from Box[Bool], and parameter
  bounds must hold at use. _Rejected:_ owner-only relationships or checking method
  bodies during trait proof.

## Referenced by

[[Type Formation]] · [[Type Env]] · [[Type Trait Proof]] · [[src/Pudu/Type/_MOC]]

## Static field owner selection (#457)

`selectImplementationTarget` exposes the pure target-head parameter selections used by
`matchImplementation`. Retain structural matching, repeated-parameter agreement and canonical
identity; return partial selections without changing the proof function's completeness guard.
Resolved Grill Log: static owner selection and conditional proof share one matcher; method bounds
are still discharged by ordinary scheme instantiation. Never match by parameter position alone.
