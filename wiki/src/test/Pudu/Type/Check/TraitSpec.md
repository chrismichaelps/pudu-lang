---
type: module
path: "@root/test/Pudu/Type/Check/TraitSpec.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, trait]
aliases: [Type Trait Dispatch Spec]
---

# Type Trait Dispatch Spec

## Purpose and interface

`traitProperties` registers ordinary trait dispatch, inherited defaults,
parameter/where bounds, ambiguous members, coherence and generic qualified calls.
The module also exports its focused test actions to the test coordinator.

## Algorithm and evidence

Compile source programs through the common compiler harness. Assert accepted
methods, inherited default composition, exact result mismatches, missing members,
rigid forwarding, trait-qualified provider selection and concrete generic results.
The coherence matrix covers duplicate heads, alpha-renaming, concrete arguments,
structural targets, orphan ownership, transparent aliases and binder shadowing.
Inspect diagnostic messages, help and primary spans for duplicate/orphan cases;
retain exact ordered code lists for each matrix case.

## Edge cases and negative logic

Opaque isolated imports defer interface-dependent checks. Local nominal or sum
ownership admits an imported trait; an alias or type parameter cannot manufacture
ownership. A parameter shadowing a local trait is independently an invalid trait
head (E3048) and an orphan (E3014), with the existing unused-import warning.
This added diagnostic is a checked semantic delta, not a snapshot refresh.
Do not replace real source compilation with method-map inspection or accept an
ambiguous provider through installation order.

## Grill Log

- **Q:** Remove the orphan assertion when bound validation adds a head error?
  **A:** Retain both independently explained errors. _Rationale:_ a parameter is
  neither a trait declaration nor a nominal owner. _Rejected:_ silently skipping
  invalid heads to preserve an incomplete diagnostic list.
- **Q:** Check dispatch only by return values? **A:** Check compiler signatures,
  exact diagnostics and qualified provider selection. _Rationale:_ runtime values
  alone can hide an incorrectly accepted generic method. _Rejected:_ smoke-only
  tests or implementation-mirroring fixtures.

## Referenced by

[[Type Check Coherence]] · [[Type Check Bound]] · [[Type Check Method]] ·
[[src/Pudu/Type/_MOC]]
