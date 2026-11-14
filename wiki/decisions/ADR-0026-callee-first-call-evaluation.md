---
type: decision
status: Accepted design; implementation pending
date: 2026-11-05
tags: [decision, semantics, calls, conformance]
aliases: [Callee First Call Evaluation]
---
# ADR-0026 — Evaluate the callee before supplied arguments

## Context and decision

The grammar and semantic call contract already require callee-first evaluation.
Current tree evaluation instead evaluates arguments before reading a function
variable, computing a callee or evaluating a method receiver. Native value and
member lowering deliberately copied that behavior. Agreement between these
engines does not satisfy the normative contract.

Retain the established rule. Evaluate a runtime callee expression exactly once,
retain its value, then evaluate supplied arguments exactly once left-to-right.
For a method call, evaluate and retain the receiver and its lent place before
arguments, including all indices needed to reach that receiver. A function-valued
field selected as a callee is likewise read before arguments. A later argument
cannot replace the selected function or receiver by mutating its original binding.

Type/module/trait-qualified paths with no runtime receiver have no callee effects.
Their immutable declaration and type witnesses are selected without re-reading a
mutable caller binding after arguments. Trait dispatch may use an already-evaluated
first argument to choose the implementation; this is pure type-directed selection,
not a delayed runtime callee expression. Preserve lexical shadowing, method-over-
field call selection, explicit type arguments and canonical provider identity.

After supplied values exist, bind parameters and evaluate omitted defaults in
parameter order in the declaration's environment. Enter the called body and charge
its call depth at the existing invocation boundary. Computing a nested callee can
itself enter a call first. A transfer, propagation or diagnostic while computing
the callee skips every argument; one during an argument skips subsequent arguments
and invocation. Ordinary unwind cleanup releases retained callable/receiver values.
Mutable loans retain their existing writeback order by parameter position on every
body exit; evaluating the receiver first does not reorder those writebacks.

## Compatibility and ownership

This is semantic clarification 2.0.1-draft, correcting observable engine behavior.
Programs relying on argument effects changing the selected callee or receiver must
write those effects before the call explicitly. No syntax, type rule, callable
identity, diagnostic code, default scope or public API is added.

Runtime ownership covers Eval.Call and its path/argument preparation, Eval.Compile
and loop-region admission. Backend ownership covers Lower.Lambda, Lower.Loan,
Lower.Call/Method/Text and Core/frame operand sequencing. Transformation ownership
covers constant/derive evaluation and any independent call planner. Existing mirrors
must resolve their specific contract before implementation; the issue is not ready
for a source assignment until that inventory is complete. Preserve other work.

## Evidence and delivery

Use independent expected output for computed callees, mutable function bindings,
function fields, builtin values, bound/unbound and trait-qualified methods,
receiver/index snapshots, defaults and mutable loans. Cover all operand positions,
failures/transfers, E7002 timing and counted owned-value cleanup. Assert actual loop
kernel admission or fallback where applicable. Verify tree, compiled and native
execution, strict Clang/GCC/sanitizers, then clean repository gates and final-head CI.
Explain every changed old expectation. Partition under the mandatory review limit,
keeping intermediate issue references open until all engines and mirrors agree.
Independent semantic and wiki review remains a merge requirement.

## Resolved Grill Log

- Preserve argument-first behavior? No: it contradicts the existing language rule.
- Read a function variable after arguments? No: retain its pre-argument value.
- Evaluate a receiver twice to recover its place? No: retain both once.
- Invoke before evaluating arguments? No: preparation and invocation are distinct.
- Change defaults or loan writeback order? No: only callee/receiver preparation moves.
- Treat engine agreement as proof? No: expected order comes from this contract.

## Referenced by
[[decisions/_MOC]] · [[architecture/SEMANTICS]] · [[Call Order Repair Delivery]]
