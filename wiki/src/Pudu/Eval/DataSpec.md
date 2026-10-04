---
type: module
path: "@root/test/Pudu/Eval/DataSpec.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Data Tests]
---

# Eval Data Tests

## Purpose

Check observable evaluation of records, variants, tuples, arrays, maps, sets, interpolation, and
text operations. Decimal structural equality regressions cover issue #376.

## Interface

`dataProperties` registers the exported `testData`, `testArrayConcat`, `testKeyed`,
`testInterpolation`, `testTextMethods`, and `testDecimalEquality` actions for the evaluator suite.
Each returns a QuickCheck `Property` through `Pudu.Eval.Common`'s checked-source runners.
`testNumericOccurrences` also exercises the private MultiMap index with evaluated
runtime values, preserving integer kind representatives across promotion and
ordinary-map transitions. This representation boundary is not expressible as
mixed integer kinds in a well-typed Pudu Map. Ordinary fixtures remain required.

## Governance

- Assert rendered results and diagnostic codes for ordinary checked programs.
- Decimal leaves compare by numeric value in Options, user sums, records, tuples, arrays, map
  values and keys, and sets. Distinct numeric values and variant tags remain unequal.
- Negative values and zero retain numeric equality across scales, and rendering preserves scale.
- Array membership and index lookup use the same equality as aggregate comparisons.
- Existing construction, destructuring, traversal, text, and keyed collection tests remain active.

## Linkage

- **Requires:** `Pudu.Eval.Common`, QuickCheck.
- Numeric storage checks also require [[Eval MultiMap]], [[Eval Env]],
  [[Eval Value]], [[Integer Literal]], [[Diagnostic Model]] and [[Source]].
- **Consumed by:** `Pudu.EvalSpec`, the shared test runner.

## Negative Logic (Prohibited Paths)

- No scale normalization or lossy conversion in the expectation.
- No unchecked evaluator standing in for the compiler and runtime path.

## Grill Log

- **Q:** Test numeric storage with one rendered map only? **A:** Compare its lazy
  ordered view with ordinary insertion after every update; cover signed ordering,
  both host boundaries, incoming kind replacement, duplicates, snapshots,
  generic transitions, count overflow and malformed entries. Preserve exact
  diagnostics and exercise promotion directly.
  Assert the common platform pair's compact constructor, and overwrite a pair
  through platform → mixed kinds → platform while retaining each snapshot.

- **Q:** Is equality of two Options enough to fix Decimal equality? **A:** No; cover nested
  aggregates, collections and lookup operations, plus unequal values and tags. _Rationale:_
  `Eq Value` is used recursively across these carriers, and false positives matter as much as the
  reported false negative. _Rejected:_ testing only a bare Decimal comparison.
- **Q:** Can the fix erase trailing zeros? **A:** No; assert retained rendering separately.
  _Rationale:_ [[ADR-0007]] distinguishes numeric comparison from stored precision.
  _Rejected:_ rescaling operands before comparing them.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Value]]
