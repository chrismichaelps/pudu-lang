---
type: module
path: "@root/test/Pudu/Eval/LoopStepSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Loop Step Tests]
---

# Eval Loop Step Tests

## Purpose and interface

`testLoopSteps` is registered by [[Eval Test Coordinator]] and
[[Pudu Test Cabal Manifest]]. Verify [[Eval Loop Step]]'s success/refusal sequencing and cleanup
through the ordinary runtime boundary, independently of planner admission.

## Test contract and dependencies

Success composes lifted IO and value transformations in order, then clears a
scratch-like cell while retaining the returned immutable value. A shared abort
diagnostic propagates unchanged, skips subsequent work and executes cleanup.
An ordinary return transfer preserves its value and performs the same cleanup.
Check exact event traces and structured ordinary-evaluator diagnostic equality.
Requires IORef, the shared runtime/Env, Value, Source and QuickCheck; no new
dependencies, partial failures or synthetic timing thresholds.

## Resolved Grill Log

- **Q:** Accept only a normal final value? **A:** No; success, typed refusal and
  transfer each establish ordered actions, skipped continuations and cleanup.
- **Q:** Reconstruct an expected diagnostic by copying its message? **A:** No;
  compare with the same refusal evaluated directly through the ordinary runtime.

## Referenced by

[[Eval Loop Step]] · [[Eval Test Coordinator]] · [[src/Pudu/Eval/_MOC]]
