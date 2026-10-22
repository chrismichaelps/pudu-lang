---
type: architecture
status: RESOLVED_DESIGN
tags: [architecture, backend, references]
aliases: [Native Shared References]
---
# Native Shared References

Shared-reference parameters are a prerequisite for ordinary user methods and
library functions. The current evaluator represents borrowing and dereference
as identities over Value; references have no separate runtime value constructor.
Native admission must preserve that actual representation and observable
behavior while continuing to use checked reference facts.

## Checked representation

Project only ReferenceTypeValue False target into the target's existing native
carrier, using the ordinary canonical type projection recursively. Shared
references to unrepresented types remain unrepresented. Mutable reference
types are not erased: their calls owe place writeback under
[[ADR-0022-lending-a-place]], which this slice does not implement.

A bounded compiler-owned reference lowerer handles unary `&` and dereference
of a shared reference. It lowers the operand exactly once, preserves Never
transfers, checks exact complete-span reference facts, rejects effect-only
print Result carriers, and returns the underlying Core expression. Retain the
operand's original span so a failing call or operation does not gain a new
borrow-expression diagnostic location. No second checker, new Core value,
pointer, C dereference, runtime ABI or synthetic allocation is introduced.

Shared carriers retain the existing native ownership/refcount rules through
locals, parameters, results, branches, loops, calls and aggregate reads.
Source ownership/type checking still precedes lowering. This does not establish
Drop, mutable loans, resources or unsupported pointee families; those remain
obligations of [[Native Emission Coverage]].

## Validation and evidence

The checked probe at the delivery evidence directory reads a field through
&Point, returns an &Int parameter, dereferences it, and passes &Str. Both tree
and compiled evaluation print `9`, `7`, `hello`, each followed by a newline and
exit 0. The native baseline refuses &Point at its parameter type with E6001.
Eval.Operator.applyUnary explicitly preserves its operand for & and *.

Conformance must cover those cases, borrowed scalar/tuple/record/sum/text
values, exact operand order, borrowed parameters/results, nested calls and
transfers, missing reference facts, mutable-reference refusals, print-carrier
refusals, exact runtime failures and counted cleanup. Compare hand-written
answers and tree/compiled/native behavior under Clang, GCC and sanitizers;
run the complete clean repository gates.

## Resolved Grill Log

- Reuse value carriers because the evaluator itself has no reference tag;
  do not invent pointer identity or C aliasing behavior.
- Admission requires solved shared-reference facts. An erased Core type alone
  cannot prove that a dereference was a valid shared-reference operation.
- Mutable references require call/place writeback, so identity-only lowering
  of &mut is rejected despite the evaluator's unary identity operation.
- Preserve Never and the operand's source provenance; borrowed evaluation may
  still fail or transfer before a reference is produced.
- Existing print is effect-only Core unit with a hidden Result carrier; a
  borrow must not make that carrier escape as genuine unit.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Types]] · [[Compiler Lower Scalar]]
