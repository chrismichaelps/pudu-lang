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
and call graph can use typed scalar values. It starts with the acyclic,
stack-bounded set from [[Backend Frame Direct]]. Each selected function calls
only other selected functions. emitFastFunctions emits C prototypes and
bodies, plus the runtime parts they require. fastEntry supplies the typed
branch of the direct cell entry in [[Backend Frame Program]].

## Invariants

- Platform signed integers, Int64, and Bool use int64_t locals. Unit
  results carry no value. Branch and jump targets follow the frame IR.
- Signed 8-, 16-, and 32-bit integers use the same locals, with exact
  intermediate arithmetic and checks against their declared bounds.
  Wrapping uses the declared modulus and saturation clamps to the declared
  bounds. The entry falls back for an out-of-width or deferred carrier.
- Float32 and Float64 pass the same encoded bits as frame cells. Arithmetic
  and predicates use the ordinary width-specific runtime helpers. The entry
  and result boundary preserve the bit pattern, including signed zero.
- Records and tuples written only by reads and projections can be passed as
  borrowed pointers. Typed callees may project booleans, floats, and further
  borrowed records or tuples. Borrowed values cannot leave as results.
- Calls between typed bodies pass their arguments as C parameters.
  Arithmetic checks keep the source spans and integer kinds of the frame
  operation. Division truncates toward zero and a nonzero remainder has the
  dividend’s sign.
- A cell entry falls back to the stack frame if the sign disagrees with the
  high bit, as can happen with a deferred positive signed literal. The frame
  path carries that magnitude until a checked operation consumes it.
- Values and operations outside the typed set keep their frame representation.
  Runtime helpers are emitted when a selected body or entry uses them.
- Each generated prototype carries an assembler label naming the Pudu
  function, its role and its index. Calls keep the indexed names.

## Resolved Grill Log

The direct stack entry owns argument conversion and can execute a frame whose
integers hold a deferred magnitude. Typed callees use int64_t after that
boundary establishes range. The graph admits no newly owned values or
suspensions, so bypassing an empty frame preserves unwind behavior. Typed calls count
toward the Pudu call-depth limit. A label on the first declaration renames
the symbol without touching any reference, so typed calls keep their indexed
names.

Resolved Grill Log: Admit floating calls without changing arithmetic or
rounding. A Float32 operation still rounds before the next instruction, and
floating comparisons keep the same behavior for unordered inputs.

Resolved Grill Log: a signed operation on operands of at most 32 bits fits
the wider intermediate even for minimum divided by minus one. Test that
result against the declared width, report at the original operation, and
only convert unsigned wrap residues within the signed intermediate range.
Typed signed shifts call the common checked bit operations using the
declared width and retain both original count diagnostic sites.

Resolved Grill Log: the caller's live frame owns each borrowed object. A
typed call can only pass that object or its borrowed descendants to other
typed calls. Integer projections keep the ordinary frame path because the
aggregate can carry a deferred integer magnitude that needs range handling.

## Referenced by

[[Backend Frame Program]] · [[Backend Frame Direct]] · [[Native Direct Call Tests]] · [[CHANGELOG]]
