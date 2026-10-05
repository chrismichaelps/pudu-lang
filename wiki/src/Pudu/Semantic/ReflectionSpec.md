---
type: module
path: "test/Pudu/Semantic/ReflectionSpec.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, tests, derive]
aliases: [Reflection Resolution Spec]
---

# Reflection Resolution Spec

## Purpose and interface

`reflectionProperties` exercises resolved metadata references and rigid loop scopes
through the actual compiler, asserting diagnostic codes and reference identities.

## Algorithm and cases

Selected reflection values and types, first-class module values, and function values
must be refused with one E2018 per use. A type parameter shadowing a module qualifier
in the type namespace must not hide the value import. A local ordinary parameter
shadowing a selected value retains lexical behavior. Repeated loop constraints and
bounds on enclosing parameters reuse the original parameter rather than diagnosing
a duplicate or shadow. Unknown names still diagnose normally.

## Negative logic

Do not infer success from two failing evaluators agreeing. Assert actual diagnostic
sets and resolved reference identity through the compiler.

## Grill Log

- **Q:** Test only qualified calls? **A:** Cover every resolved value/type path and
  both namespaces. _Rationale:_ bypasses occur where syntax does not look like a
  call. _Rejected:_ only reproducing the implementation's happy path.

## Linkage and backlinks

Requires [[Compiler Pipeline]], [[Name Resolution]] and [[Resolve Reflection]].
Referenced by [[src/Pudu/Semantic/_MOC]] and the full test runner.
