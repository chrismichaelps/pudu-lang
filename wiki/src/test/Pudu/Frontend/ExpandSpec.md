---
type: module
path: "@root/test/Pudu/Frontend/ExpandSpec.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, frontend, macro]
aliases: [Macro Expansion Spec]
---

# Macro Expansion Spec

## Purpose

Exercise macro expansion through parsing, compilation and evaluation, with
direct syntax checks for derive declarations and compile-time loops.

## Interface

```haskell
expandProperties :: [(String, IO Property)]
```

## Contract and coverage

- Expression, identifier and block arguments expand before downstream phases;
  nested calls, precedence, Set members and Set bodies preserve their meaning.
- Argument kinds, unknown kinds, unknown calls, exact arity and recursion limits
  report their respective diagnostic once.
- Introduced block and pattern bindings cannot capture caller expressions or
  leak into surrounding scopes; successful branches keep their renamed uses.
- Derive members and compile-time loops keep their surface constructors while
  every macro call is removed. Loop elements are renamed with their body alone.
- A surviving ordinary compile-time loop reports E3090.
- Authored lambdas expand block and expression bodies, including derive
  callbacks; unknown calls still report E1047. Macro-produced lambda parameters
  mask same-named macro arguments and caller arguments remain free from
  introduced capture. Nested parameter scopes do not leak. Authored lambdas
  accept no defaults; direct shared-function AST checks verify earlier-parameter
  default scope without extending the language grammar.

## Algorithm

Most cases compile a small module and compare its evaluated value or exact
diagnostic-code list. Surface cases parse and expand directly, then count
derive declarations, compile-time loops and macro calls, traversing lambda
defaults and all function-body forms. These checks inspect syntax deliberately
before the typed residualizer consumes compile-time constructs.

## Linkage

- **Requires:** [[Macro Expansion]], [[Macro Substitution]], [[Parser]],
  [[Compiler Pipeline]], [[Syntax Tree]] and evaluator entry-point/render APIs.
- **Consumed by:** [[Repository Test Runner]] through `expandProperties`.

## Negative Logic

- No snapshot acceptance without inspecting meaning; compare values and exact
  diagnostic counts.
- No AST-only claim of executable hygiene: lambda substitution also runs through
  resolution, typing and evaluation.

## Grill Log

- **Q:** How is lambda traversal verified? **A:** Execute both body forms, inspect
  shared-function defaults directly, check unknown-call diagnostics, and inspect derive syntax before typed
  expansion. _Rationale:_ opaque lambdas can survive a shallow syntax count.
  _Rejected:_ a test that merely checks whether a module parsed.
- **Q:** How is parameter shadowing verified? **A:** Give macro and lambda
  parameters identical spellings and a distinct caller value, then compare the
  result. _Rationale:_ binder renaming alone does not mask macro substitution.
  _Rejected:_ testing only parameters with different names.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Macro Expansion]] · [[Macro Substitution]]
