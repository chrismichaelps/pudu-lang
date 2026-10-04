---
type: module
path: "@root/src/Pudu/Eval/Loop/Kernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance]
aliases: [Eval Loop Kernel]
---

# Eval Loop Kernel

## Purpose and interface

`pureLoop` attempts a kernel for a pure while-expression subgraph.
Captured, proven MultiMap forwarding closures or the two primitive builtin tags
are the only admitted calls, and no call is required. Return Nothing for unsupported syntax; otherwise an Evaluator Value
executes the kernel. This is a shared intrinsic optimization in both evaluation
modes, not a mode override or use of the general compiled-body cache.

## Algorithm and invariants

Plan literals, bare names, identity borrow, unary/binary scalar operations,
assignment to bare bindings, blocks with expression statements only, and if.
Operators delegate to existing applyUnary/combine/expectBool helpers; logical
operators preserve short-circuiting. Every call must resolve to the proven
MultiMap primitives with exactly three arguments. No other function, effect,
lending, declaration, transfer, nested loop or data constructor is accepted.
Module callees are resolved once
only when their first segment is unshadowed; assignments cannot target any callee
prefix. Snapshot referenced bindings into temporary runtime slots. Reads/writes
use these local slots, preserving left-to-right evaluation; immutable MultiMap
values and original snapshots remain ordinary values. On successful exit write
only assigned bindings back into their original frames. An abort exposes no state.
Keep the original while condition span for Bool refusal and the existing constant
step-limit boundary. Native wrapper calls retain closure tally and call-depth
entry/exit with their original call and inner primitive spans.

## Failures and negative logic

Unsupported or unresolved regions use the existing loop evaluator. No source
name, benchmark size, key distribution or loop trip count enables the kernel.
No public collection mutation, skipped occurrences, changed workload, or source
rewriting. Effects/callbacks/transfers cannot observe deferred local writes because
these constructs are outside the kernel's admitted region.

## Dependencies and consumers

Requires [[Eval Env]], [[Eval Frame]], [[Eval Match]], [[Eval MultiMap]],
[[Eval Operator]], [[Eval Value]], [[Syntax Tree]] and GHC runtime arrays.
Consumed only by [[Eval Loop]].

## Grill Log

- **Q:** Require a MultiMap call in a fully pure scalar subgraph? **A:** No.
  _Rationale:_ the complete-region proof already excludes every observing effect,
  callback, declaration and transfer. Requiring an unrelated primitive leaves
  scalar loops repeating the same safe name/dispatch work. Every admitted call
  still requires the original captured primitive proof. _Rejected:_ admitting
  arbitrary functions, benchmark recognition, or partial planning/execution.
- **Q:** Match the supplied benchmark's exact loop? **A:** No; admit the stated
  expression grammar independently of loop size, condition, integers or names.
- **Q:** Change arithmetic or constant-folding policy? **A:** No; use shared
  operators and the original iteration refusal with the same threshold.
- **Q:** Let unsupported behavior run partway through a kernel? **A:** No; validate
  the complete region before any execution and fall back as a whole.
- **Q:** Mutation of collection values? **A:** No; only lexical variable slots are
  written, as in the existing compiled frame. Collection updates stay persistent.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[src/_MOC]] · [[Eval Loop]] · [[Eval MultiMap]]

## Static dispatch allocation

Prepare statement sequencing and three-argument forwarding once per eligible
region. Identity borrow/dereference nodes reuse their operand code. Bool results
are read directly, with shared expectBool reserved for refusal; integer operators
are selected once with shared checked-result and generic fallback semantics.
Resolved Grill Log: remove transient IO-action/argument-list spines, preserving
left-to-right execution, short-circuiting and every source span.

## Shared compile-time boundaries

[[Compile Time Limits]] supplies the existing depth/iteration constants to both
evaluation and derive residualization. Runtime loop policy and thresholds remain
unchanged. Resolved Grill Log: one phase-neutral declaration prevents nested
compiler expansion and ordinary constant evaluation from drifting apart.

## Dependency layers

While syntax → complete expression plan → temporary lexical slots → shared
scalar/primitive semantics → original-frame commit. Unsupported syntax returns
to the ordinary tree/compiled loop as a whole. The native-call presence bit is
removed from Plan because eligibility no longer depends on it. No value shape,
call proof, diagnostic, step policy or persistent collection representation changes.

Resolved Grill Log: the dependency cut removes repeated syntax/name work only
after all observable boundaries are excluded. Validate success, short-circuit,
condition writes, overflow, bounded constant refusal and effect/transfer fallback.
