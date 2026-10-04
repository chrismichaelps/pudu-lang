---
type: module
path: "@root/test/Pudu/Eval/BindingFlowSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime]
aliases: [Eval Binding Flow Tests]
---

# Eval Binding Flow Tests

## Purpose and interface

`bindingFlowProperties`, `testBindings`, `testBranching`, `testLoops` and
`testUnwindFrameCleanup` exercise checked program evaluation through
[[Eval Test Coordinator]]. Shared runners compile source before evaluation.

## Behavior and dependencies

Bindings cover declaration order, mutation and nested shadowing. Branching
covers if/if-let, Option propagation, let-else scope, while-let, matches, guards,
ranges, alternatives and return. Unwind tests cross nested lexical blocks and
check the caller's binding after break/return. Loop tests cover counted while,
break and tuple iteration, plus pure-region condition writes, short-circuit,
checked overflow and compile-time step refusal.

Uses the shared `Pudu.Eval.Common` runners, [[Evaluator]], [[Eval Loop Kernel]],
[[grammar/pudu]] and [[architecture/SEMANTICS]]. Properties are registered in
[[Eval Test Coordinator]] and run in both evaluator modes.

## Algorithm and negative logic

Build ordinary source programs and compare exact rendered values or diagnostic
codes. No changed benchmark inputs, source-name optimization switches, snapshot
updates or acceptance of failed compilation as successful execution.

## Grill Log

- **Q:** Test only the scalar loop's final total? **A:** Also check writes in the
  terminating condition, skipped invalid arithmetic, overflow and constant
  refusal. These distinguish semantic order from a merely plausible total.
- **Q:** Force unsupported loops into the kernel? **A:** No; declarations,
  effects and transfers retain ordinary execution and its existing regressions.
- **Q:** Treat identical optimized modes as the independent oracle? **A:** No;
  compare the unchanged benchmark programs with the pre-change executable too.

## Referenced by

[[Eval Test Coordinator]] · [[src/Pudu/Eval/_MOC]] · [[src/_MOC]]
