---
type: module
path: "@root/test/Pudu/Derive/RecordSpec.hs"
fidelity: Active
domain: "[[Compilation Artifact]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, test]
aliases: [Derive Record Kernel Spec]
---

# Derive Record Kernel Spec

## Purpose and interface

`recordResidualProperties` validates the pure record kernel against complete loaded
programs using the actual Std.Meta facade. Arbitrary user traits check their derive
definitions before instantiation. Replace explicit oracle stub impls with generated
impls, then check and execute the transformed AST in tree and compiled modes.
The graph driver is not implemented by this test adapter and remains a separate gate.

## Evidence and algorithm

Cover declaration order, attribute names/skip, actual owner-specific field reads,
heterogeneous field capabilities, mutable writes, strict attribute fallback
evaluation, multiple target instantiations, generic targets,
canonical aliases and selected imports, lexical shadowing, nested closures and
patterns. Assert separate generated identities and structured field obligations.
Refuse wrong shape, unknown sequences, escaping metadata and exhausted limits.
Test only admitted templates; malformed generic definitions fail before the kernel.

## Negative logic and edge cases

No known trait-name dispatch, source-string generation, fake offsets or runtime
Meta fallback. Preserve source and dependency products; restore PUDU_EVAL after
mode comparisons. Stub impls are test oracles and are removed before checking
and executing the generated implementations.

## Grill Log

- **Q:** Let the parser accepting a derives clause prove expansion works? **A:** No;
  inspect the generated Impl, check it and compare real evaluation outcomes.
  _Rationale:_ ignored requests previously passed frontend-only fixtures.
  _Rejected:_ main returning zero as evidence of generated methods.

## Referenced by

[[src/_MOC]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[Derive Record Residualizer]]
