---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Frame/Fast.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, backend, emit, native, frames, performance]
aliases: [Backend Typed Integer Calls]
---

# Backend Typed Integer Calls

## Purpose and interface

fastFunctions selects the named direct callees whose lowered blocks, slots,
and call graph can use signed 64-bit C values. It starts with the acyclic,
stack-bounded set from [[Backend Frame Direct]]. Each selected function calls
only other selected functions. emitFastFunctions emits C prototypes and
bodies, plus the runtime parts they require. fastEntry supplies the typed
branch of the direct cell entry in [[Backend Frame Program]].

## Invariants

- Platform signed integers, Int64, and Bool use int64_t locals. Unit
  results carry no value. Branch and jump targets follow the frame IR.
- Calls between typed bodies pass their arguments as C parameters.
  Arithmetic checks keep the source spans and integer kinds of the frame
  operation. Division truncates toward zero and a nonzero remainder has the
  dividend’s sign.
- A cell entry falls back to the stack frame if the sign disagrees with the
  high bit, as can happen with a deferred positive signed literal. The frame
  path carries that magnitude until a checked operation consumes it.
- Values and operations outside the typed set keep their frame representation.
  Runtime helpers are emitted when a selected body or entry uses them.

## Resolved Grill Log

The direct stack entry owns argument conversion and can execute a frame whose
integers hold a deferred magnitude. Typed callees use int64_t after that
boundary establishes range. The graph admits no owned values or suspensions,
so bypassing an empty frame preserves unwind behavior. Typed calls count
toward the Pudu call-depth limit.

## Referenced by

[[Backend Frame Program]] · [[Backend Frame Direct]] · [[Native Direct Call Tests]] · [[CHANGELOG]]
