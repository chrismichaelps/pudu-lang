---
type: architecture
tags: [architecture, backend, native]
aliases: [Native Mutable Loans]
---
# Native Mutable Loans

`fn bump(value: &mut Int)` called as `bump(&mut n)` lends `n` to the call.
The interpreter binds the parameter to the place's value, runs the body, and
writes the parameter's final value back to the place however the body
finished: its trailing result, `return`, or `?`. Native code does the same
by copy-in/copy-out (#651).

## Callee

A `&mut T` parameter is a local of type T ([[Compiler Lower Signature]]).
`*value` reads it ([[Compiler Lower Reference]]); `*value = x` and
`(*point).x = x` assign it through [[Native Place Assignment]]. Any
expression whose checked type is `&mut T` holds a T, so type facts look
through that outer reference ([[Compiler Lower Types]]). The function's Core
result is the tuple of its own result and the final value of each loaned
parameter, in parameter order. Every way out builds that tuple after its
value has run: the trailing result, each `return`, and each `?` that
returns. A body that never returns never builds one.

## Caller

A call to such a function holds each argument in order. A `&mut place`
argument, or a local lent on to a loaned parameter, resolves its place at
its position among the arguments: indices along the place run then, once,
and the place's value is read as the argument. After the call the tuple is
held, each final value is stored through the same place, in parameter
order, and the call's value is the tuple's first member. A failure inside
the callee ends the program before any write, as it does in the
interpreter.

Methods with `&mut` parameters (including `self: &mut Self`) refuse at the
`&mut` type, and a function with loans refuses as a value: neither has a
place to write back to yet.

## Resolved Grill Log

- **Q:** Pass a pointer into the caller's frame? **A:** No; places include
  fields and elements of reference-counted values, and an in-place write
  would change every holder. Copy-out through the place rebuild keeps value
  semantics, and exclusivity (E3081, E3084) means nothing else can observe
  the place during the call.
- **Q:** Read the finals before the returned value runs? **A:** No; the
  evaluator reads them after the body has finished, so a `return` that
  changes a parameter while computing its value is seen.
- **Q:** Re-evaluate the place's indices for the store? **A:** No; the
  evaluator resolves the place once, with the argument.
- **Q:** Let `&mut T` form as T everywhere? **A:** No; only an outer
  reference. A function type with a `&mut` parameter stays unformed, so a
  lambda or function value with loans refuses instead of running without
  writeback.

## Evidence and remaining scope

[[Backend Mutable Loan Programs]]: locals, fields, elements and nested
places; early return, `?` on Result and Option, `return` without a value and
loops; several loans in one call, lending on, index order and recursion;
defaults, generic copies and shadowing; owned Str and array values lent 200
times with zero live allocations; failures before and inside the call, call
depth, and a stopping index. Both evaluators, Clang, GCC 15 and ASan/UBSan.

Remaining: methods with `&mut` parameters and `&mut self`, and calls through
function values with loans.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Loan]] · [[Backend Mutable Loan Programs]]
