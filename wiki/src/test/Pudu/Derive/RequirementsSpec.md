---
type: module
path: "@root/test/Pudu/Derive/RequirementsSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, tests]
aliases: [Derive Requirement Spec]
---

# Derive Requirement Spec

## Purpose and interface

`requirementProperties` checks conditional requirement inference through the
actual shared trait proof. Generated nesting laws preserve full trait arguments;
explicit failures cover concrete absence, unauthorized parameters, error types,
cycles, higher-kind composite subjects and exhausted depth/work.

## Evidence and invariants

Nested ordinary Box implementations lift their generic leaf premise to the
authorized target parameter. Existing scoped bounds discharge that premise.
Failed alternatives discard every tentative inferred bound; successful
alternatives publish only their own requirements. Ordinary proof still refuses
the same unbounded generic subject before and after requirement inference, so
inference does not mutate caller assumptions. Duplicate requirements collapse.

## Grill Log

- **Q:** Test only one direct generic field? **A:** Generate nested conditional
  evidence and force rollback through a later concrete failure. _Rejected:_ an
  oracle that mirrors a rigid-subject constructor check without solver evidence.
- **Q:** Gate on timing? **A:** Assert bounded outcomes and semantic evidence.
  _Rejected:_ host-specific latency assertions or unresolved requirements escaping.

## Linkage and references

Requires [[Type Trait Proof]], [[Trait Evidence Matching]] and [[Type Env]].
Referenced by [[src/_MOC]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]].
