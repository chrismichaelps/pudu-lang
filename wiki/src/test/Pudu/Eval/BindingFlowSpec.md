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
`testPureCalls` covers closed function bodies in loops and their fallback boundary.
Its direct kernel probe compiles one source snapshot, extracts its ordinary
closure and while AST, then checks admission, the exact allowed/refused depth
boundary, call tally and structured diagnostic equality with ordinary dispatch.
This proves the optimized path actually runs rather than silently falling back.
Requires [[Eval Env]], [[Eval Value]], [[Compiler Pipeline]] and [[Diagnostic Model]]
for that bounded probe; no runtime production semantics are duplicated.

## Behavior and dependencies

Bindings cover declaration order, mutation and nested shadowing. Branching
covers if/if-let, Option propagation, let-else scope, while-let, matches, guards,
ranges, alternatives and return. Unwind tests cross nested lexical blocks and
check the caller's binding after break/return. Loop tests cover counted while,
break and tuple iteration, plus pure-region condition writes, short-circuit,
checked overflow and compile-time step refusal.
Indexed pure loops additionally cover receiver/index evaluation order, snapshots,
short-circuit skips, scalar bounds refusal and an explicit admission probe.

Uses the shared `Pudu.Eval.Common` runners, [[Evaluator]], [[Eval Loop Kernel]],
[[grammar/pudu]] and [[architecture/SEMANTICS]]. Properties are registered in
[[Eval Test Coordinator]] and run in both evaluator modes.

## Algorithm and negative logic

Build ordinary source programs and compare exact rendered values or diagnostic
codes. No changed benchmark inputs, source-name optimization switches, snapshot
updates or acceptance of failed compilation as successful execution.

## Grill Log

- **Q:** Add indexing without testing the execution path? **A:** Compile and
  extract a while AST, assert pureLoop returns a plan, then run it. Source tests
  also compare ordered receiver/index writes, immutable snapshots and refusal.

- **Q:** Test only the scalar loop's final total? **A:** Also check writes in the
  terminating condition, skipped invalid arithmetic, overflow and constant
  refusal. These distinguish semantic order from a merely plausible total.
- **Q:** Force unsupported loops into the kernel? **A:** No; declarations,
  effects and transfers retain ordinary execution and its existing regressions.
- **Q:** Treat identical optimized modes as the independent oracle? **A:** No;
  compare the unchanged benchmark programs with the pre-change executable too.
- **Q:** Test only a record-loop total? **A:** Also exercise nested argument
  calls, lexical free values, local callee shadowing/replacement, defaults, callbacks,
  lending, overflow and declaration fallback. Register the family explicitly.
- **Q:** Cover only the unrolled argument counts? **A:** Exercise zero and four
  parameters as well as nested calls; verify a skipped failing branch too.
- **Q:** Can clearing scratch invalidate a returned member value? **A:** Test
  a bound method returned from the final loop call and invoked after loop exit.
  Its receiver must remain an ordinary immutable value, independent of scratch.

## Referenced by

[[Eval Test Coordinator]] · [[src/Pudu/Eval/_MOC]] · [[src/_MOC]]

The closure fixture constructs `Closure` with an empty witness list, the
field static selection added; behavior and assertions are unchanged.
