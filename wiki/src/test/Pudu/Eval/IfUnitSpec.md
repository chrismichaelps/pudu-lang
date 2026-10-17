---
type: module
path: "@root/test/Pudu/Eval/IfUnitSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, runtime, conformance]
aliases: [Eval If Unit Tests]
---

# Eval If Unit Tests

## Purpose and interface

`ifUnitProperties` is issue #490's regression family for ordinary if-without-else.
Normal completion yields unit regardless of the taken block's final value;
return, break, continue and runtime failures retain their existing behavior.
The family is registered in [[Repository Test Runner]] and [[Pudu Test Cabal Manifest]].

## Behavior and dependencies

Every source example passes the ordinary compiler before execution. Tests run
in both tree and compiled evaluation modes, restoring the previous mode after
each run. Exact rendered values, captured stdout and diagnostic codes are
compared with independently stated expectations. Taken and skipped branches
cover integer, Boolean, text and print Result values. Composition covers local
bindings, assignment, explicit returns, unit call arguments, nested blocks and
loop break operands, aggregates and nested conditionals. Condition counters prove
single evaluation; condition failures and branch failures keep their diagnostics.
Annotated dynamic contexts reject unit with the same observed E3001 as an ordinary
unit expression; with-else still admits differing concrete implementations.
With-else retains its selected scalar value and if-let retains unit.

A direct `pureLoop` probe extracts an ordinary checked while AST. Its unit slot
forces boxed execution; the test requires successful kernel admission, runs the
plan and reads the final original-frame bindings. Thus a fallback walker cannot
hide a defect in the optimized region. Constant tests inspect the actual folded
plain-data values, rather than merely accepting successful compilation.

Requires [[Evaluator]], [[Eval Env]], [[Eval Value]], [[Eval Loop Kernel]],
[[Compiler Pipeline]], [[Syntax Tree]], [[Eval Binding Flow Tests]],
[[grammar/pudu]] and [[architecture/SEMANTICS]]. Uses the same checked-source
and direct-kernel patterns as `Pudu.Eval.Common` and the binding-flow tests.

## Algorithm and negative logic

All loops are finite. No production code, type-policy duplication, generated C,
handmade executable AST, snapshot refresh or blanket exception suppression is
part of this family. Diagnostics cannot stand in for successful evaluation.
Output capture and evaluator-mode selection restore process state on exceptions.
An if's checked unit type alone is not treated as proof of its runtime value.

## Resolved Grill Log

- **Q:** Which behavior is normative? **A:** Ordinary no-else if yields unit on normal completion, matching its checked type and if-let. Branch control transfers and failures are not converted to unit.
- **Q:** Is comparing tree and compiled results sufficient? **A:** No; both may share the same defect. Every assertion has an explicit expected value, diagnostic or output.
- **Q:** Can the kernel case silently use fallback? **A:** No; it invokes `pureLoop` directly, requires a plan, and checks committed frame state after execution. A unit binding excludes the integer-only execution path.
- **Q:** Can constant compilation succeed with the wrong value? **A:** Yes; inspect `compileFolded` after thawing its value and require unit.
- **Q:** Should with-else results also be discarded? **A:** No; regression cases retain the chosen Int, Bool and text values.

## Referenced by

[[Native C11 Backend Delivery]] · [[Eval Binding Flow Tests]]
