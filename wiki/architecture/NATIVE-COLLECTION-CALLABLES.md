---
type: architecture
aliases: [Native Collection Callables]
---
# Native Collection Callables

`charFromCode`, `bytesOf`, `mapOf` and `setOf` become first-class values
after nearer locals, constants and module functions, the same way display and
show did in [[Native Rendering Callables]]. Each takes the exact solved
CoreFunctionType at the reference: one represented argument and the result
the direct call would produce. Anything else refuses with E6001.

The generated body is the direct call's own Core. Convert, Bytes and Keyed
each expose the builder their direct call already used, taking the lowered
operand and the solved result; the direct call and the value body both go
through it. No second implementation of scalar-code tests, byte packing or
key checks exists.

Keys follow the rendering rule: `$builtin:<tag>:<full canonical CoreType>`.
`mapOf` at `Map[Str, Int]` and at `Map[Int, Bool]` are two bodies with one
builtin identity, so equality and `<builtin mapOf>` rendering never depend on
the instantiation. Bodies have no environment and do not count toward source
call depth.

## Failures at the caller

The interpreter reports a builtin's refusal at the call expression, and a
call through a value is still that call: `build([inc])` with `build = setOf`
fails E7008 at `build([inc])`. A generated body only knows its own spans, so
the runtime keeps the site of the value call that entered each frame. Every
value call already passes that site for the E7002 depth check; the dispatcher
now stores it on the new frame. `CoreFailCaller code help message` lowers to
`FrameFailCaller` and reports with the caller site's file, line, excerpt and
caret, and its own code, message and help. Only builtin bodies use it; a
frame entered without a value call never reaches one.

Runtime revision 17: the frame layout and failure surface changed.

## Open type variables

`setOf == setOf` or `show(display)` leaves the builtin's type variables open,
and so does `setOf([])`. [[Compiler Lower Types]] now forms any variable left
open as unit, the rule it already applied to sum arguments: no value of such
a type exists, so the representation is never observed. This covers display
and show too, which refused these programs before.

## Resolved Grill Log

- **Q:** Could the body re-lower a synthetic source call? **A:** No; spans
  would point at nothing and the result type comes from the call's facts.
  Sharing the Core builders keeps one definition per builtin.
- **Q:** Could E7008 use the reference span? **A:** No; the interpreter names
  the call site, and a value can be stored and called far from where it was
  named. Rejected: reporting at the reference, or checking keys eagerly.
- **Q:** A global "last value call" pointer instead of a frame field?
  **A:** Rejected. Nested value calls inside argument evaluation would
  overwrite it; the frame field is exact and costs one store per call.
- **Q:** Does `charFromCode` need a held local in the body? **A:** The
  shared builder declares one, as the direct call does; an Int read costs
  nothing to hold and keeps the two paths identical.
- **Q:** Could an open variable be used at two types? **A:** No; let-bound
  values are not generalized and generic bodies use rigid parameters, so a
  variable still open in a final fact has no value at all.
- **Q:** Duplicate keys? **A:** The tree build keeps the last entry, as
  `Eval.Builtin.Collection` does; the value path inherits it unchanged.

## Evidence and remaining scope

Explicit stdout/stderr/status checked against both isolated evaluators for
aliases, generics, records, captures, arrays of builtins, simultaneous
signatures, scalar code edges, duplicate keys, shadowing, identity and
rendering; E7008 through a value at the caller's span for sets and maps;
zero live allocations; Clang, GCC 15 and ASan/UBSan focused runs. Other
builtin values, defaults and the rest of the coverage ledger stay open.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Intrinsic]] · [[Backend Collection Callable Programs]]
