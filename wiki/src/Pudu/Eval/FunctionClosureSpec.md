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

- **Q:** Is a single direct Decimal call sufficient? **A:** No; a generic receiver and the two
  qualified forms discover the same runtime owner through distinct call paths. _Rationale:_ the
  reported failure occurs through a bound, and qualification must preserve the same contract.
  _Rejected:_ testing only `nominalNameOf` directly.
- **Q:** Should the regression permit every Decimal member? **A:** No; preserve the existing
  missing-member diagnostic and universal rendering fallback. _Rationale:_ owner discovery adds
  access to declared implementations without introducing an open built-in method surface.
  _Rejected:_ an arbitrary fallback method or a default success value.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Operator Access]]
