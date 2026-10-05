---
type: module
path: "@root/src/Pudu/Eval/Loop/Step.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Loop Step]
---

# Eval Loop Step

## Purpose and interface

An internal success/refusal execution channel for [[Eval Loop Kernel]].
`Step a` composes preplanned region operations without a heap constructor around
every result. `liftStep` admits an existing IO action; `stopStep` preserves an
existing `Eval Value` refusal/transfer. `runStep` crosses back to ordinary IO
as an Either only once at the region boundary. `finallyStep` runs scratch cleanup
after either an ordinary value or a structured refusal. No effect capability,
public value, syntax or evaluator mode changes.

## Algorithm and invariants

A newtype wraps the RealWorld state token and an unboxed success/stop sum.
Functor/Applicative/Monad thread the token once; a stop never executes its next
operation. Success values and stops are forced to WHNF, preserving the original
strict Yield/Stop result boundary. liftStep unwraps the base IO action and
returns its result through the same strict channel. finallyStep threads cleanup
after both alternatives without boxing the protected result; it does not catch
or translate host exceptions. Expected Pudu errors remain structured Eval values.
No raw pointer, mutable collection, global state or unsafePerformIO is introduced.

## Dependencies and negative logic

Requires base's GHC.IO/GHC.Exts plus [[Eval Env]] and [[Eval Value]], with no
frontend dependency. [[Pudu Cabal Manifest]] explicitly registers the module.
Only a completely proven region may suppress interim Env threading; this module
provides control representation and does not grant such a proof. General calls,
effects and lexical environments retain Evaluator. MagicHash, UnboxedTuples and
UnboxedSums are local representation extensions, justified by measured Yield and
dispatch allocation, not a new language runtime or machine-code generator.

## Resolved Grill Log

- **Q:** Use exceptions to skip success-result allocation? **A:** No; preserve
  typed refusal values in an unboxed alternative, with explicit stop propagation.
- **Q:** Make successful values lazy? **A:** No; retain WHNF forcing at each
  outcome boundary so diagnostics and scratch lifetimes preserve their ordering.
- **Q:** Skip cleanup after a structured refusal? **A:** No; finallyStep runs
  the same cleanup on either alternative before crossing the region boundary.
- **Q:** Assume the representation is faster? **A:** No; compare unchanged
  workloads, allocations and diagnostic oracles; remove the experiment if it
  regresses the shared runtime.

## Referenced by

[[Eval Loop Kernel]] · [[src/Pudu/Eval/_MOC]] · [[Eval Binding Flow Tests]] ·
[[Pudu Cabal Manifest]] · [[handoffs/2026-10-01-derive-integration]]
