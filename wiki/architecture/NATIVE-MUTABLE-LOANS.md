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

Methods lend the same way (#790). A receiver call runs its arguments, then
its receiver, which lends any place it names (an element-chosen receiver's
indices run then); the finals are written back receiver first. A qualified
call `Bump.bump(&mut c, 1)` lends like a function call. A bound method value
lifts the written call, so a loaned method held as a value writes back to
its own copy of the receiver. Calls through values lend too (#794). A function type with `&mut` inputs
forms as one answering its finals beside its result; a call through such a
value holds its operands with their places, runs the callee after them, and
writes back. Lambdas and lifted method values with `&mut` parameters close
every way out over their finals.

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

Methods (#790): receiver and argument loans, qualified calls, generic and
inherited members, `?`, nested and element receivers, method values, and
an element receiver out of range after its argument.

Values (#794): named functions, parameters, lambdas, arrays, record
fields, method values, generic higher-order calls, defaults, and an element
out of range lent through a value.

Nothing in this area remains refused; trait-qualified method values in
general are tracked apart (#795).

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Loan]] · [[Backend Mutable Loan Programs]]
