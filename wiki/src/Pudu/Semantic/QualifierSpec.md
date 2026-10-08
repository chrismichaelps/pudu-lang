---
type: module
path: "@root/test/Pudu/Semantic/QualifierSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
aliases: [Module Qualifier Spec]
tags: [module, tests, resolution]
---
# Module Qualifier Spec

## Purpose and interface

`qualifierProperties` checks namespace-versus-value identity through isolated resolution and complete temporary programs. Registered in [[Repository Test Runner]] and [[src/pudu-tests-cabal|Pudu Test Manifest]].

## Algorithm and evidence

Require exact E2010 message/help/span for bare capture, return, calls, arguments and collections, indexed/type-applied targets and field shorthand. Uppercase module aliases can be shadowed by valid local constants, while selected value parameters obey their ordinary naming rules. Check qualified members/types, selected functions/constants/constructors, closure capture, ordinary shadows, duplicate declarations, missing interfaces, private selections and reflection precedence. Loaded successes execute and return the expected value; failure identity is asserted independently.

## Negative logic

Do not confuse opaque missing-interface recovery with valid compilation, or two failures with semantic agreement. Pudu command and packaged evidence supplements these registered properties in [[Module Qualifier Delivery]].

## Resolved Grill Log

- **Q:** Infer semantic agreement from two failed executions? **A:** No. Assert failure identity independently and execute successful real loaded exports. Isolated lexical checks prove their own phase boundary; temporary sources remove ambient library dependence.

## Referenced by

[[src/Pudu/Semantic/_MOC]] · [[Scoped Import Design]] · [[Module Qualifier Delivery]]
