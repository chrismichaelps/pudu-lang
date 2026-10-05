---
type: module
path: "@root/test/Pudu/Eval/FunctionClosureSpec.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Function Closure Tests]
---

# Eval Function Closure Tests

## Purpose

Exercise checked evaluation of ordinary functions, closures, defaults, recursion, and user
implementations over built-in values. Decimal dispatch regressions cover issue #371.

## Interface

`functionClosureProperties` registers `testFunctions`, `testClosures`, `testBuiltinImpls`, and
`testDecimalImpls` for the shared evaluator suite. Each action returns a QuickCheck `Property`.
`testSlotScopes` registers binding-order, lexical-scope and capture admission
regressions, including shorthand fields and retained checked overflow.

## Governance

- Use `Pudu.Eval.Common`'s checked source runners so accepted and rejected expressions pass
  through the compiler before evaluation.
- Assert observable rendered values rather than internal closure storage.
- Check direct, bounded generic, trait-qualified, and type-qualified Decimal dispatch, including
  negative arithmetic and retained trailing zeros. An absent member stays `E3005`, and `toText`
  retains its universal fallback.
- Retain existing integer, text, array, Option, Result, and user-sum dispatch regressions.

## Linkage

- **Requires:** `Pudu.Eval.Common`, QuickCheck.
- **Consumed by:** `Pudu.EvalSpec`, the shared test runner.

## Negative Logic (Prohibited Paths)

- No unchecked replacement runtime or mocked dispatch.
- No equality comparison of captured environments, which can contain recursive closures.

## Grill Log
- **Q:** What proves slot admission preserves lexical order? **A:** Execute
  captured-name initializers, reads before a later binder, reads after an inner
  scope, early captures and record shorthand. Compare exact values and retained
  runtime failures in both evaluator modes. _Rejected:_ only checking that slot
  construction returned a map or exercising a single self-shadowing spelling.

- **Q:** Is a single direct Decimal call sufficient? **A:** No; a generic receiver and the two
  qualified forms discover the same runtime owner through distinct call paths. _Rationale:_ the
  reported failure occurs through a bound, and qualification must preserve the same contract.
  _Rejected:_ testing only `nominalNameOf` directly.
- **Q:** Should the regression permit every Decimal member? **A:** No; preserve the existing
  missing-member diagnostic and universal rendering fallback. _Rationale:_ owner discovery adds
  access to declared implementations without introducing an open built-in method surface.
  _Rejected:_ an arbitrary fallback method or a default success value.

## Referenced by

The lexical scope matrix also mutates a local after capturing it and writes an
outer binding through a nested block. Resolved Grill Log: these examples detect
accidentally shared capture cells and discarded parent writes when block-local
storage changes; they run against both evaluator modes.

[[src/Pudu/Eval/_MOC]] · [[Eval Operator Access]]
