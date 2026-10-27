---
type: architecture
aliases: [Native Stopping Builtins]
---
# Native Stopping Builtins

`panic` and `convertInteger` without a type argument never return: the first
stops with E7007, the second with E7012. Native builds refused both; the
interpreter runs them.

A direct `panic(message)` runs its argument, then fails with E7007 whose
message is that text, at the call, with no help. `convertInteger(value)`
without a type argument runs its argument, then fails E7012 "convertInteger
needs the type to convert to" with the interpreter's type-argument help.
Both are `Never` to the code around them.

As values they use [[Native Collection Callables]]' caller failures: the body
is `CoreFailCaller` over the parameter (panic) or the fixed text
(convertInteger), so the error points at the call made through the value.
Identity and `<builtin panic>` / `<builtin convertInteger>` rendering stay per
tag, keyed by the full solved signature like the other builtin values.

Checking never binds `panic` (#634), so its reference, and any binding made
from it, is typed as the error type. Direct calls do not care. A value takes
`fn(Str) -> Never` when nothing else is known, and a let binding takes it
from an annotation written exactly that way; any other position where the
real signature differs (`fn(Int) -> Never`, a parameter of another type, an
array of panics) refuses with E6001 instead of guessing. Those wait on #634.
The interpreter accepts `panic(5)` and `panic()`; native does too, running
the arguments and refusing E7007 "panic" with the help "panic takes one
string argument".

An empty message renders as `compiler diagnostic <code>`, which is what
`Pudu.Diagnostic.nonEmptyMessage` does for every diagnostic; the native
reporter now applies the same rule to any message whose length is zero.
Runtime revision 18.

## Resolved Grill Log

- **Q:** Should panic's message get help text? **A:** No; the interpreter
  gives help only when the argument is not a string, which checking rules
  out.
- **Q:** Is the empty-message rule panic-specific? **A:** No; it is how every
  interpreter diagnostic is built, so it belongs in `pudu_fail_report`.
  Rejected: special-casing panic in lowering.
- **Q:** Does an untyped convertInteger value need its argument? **A:** The
  argument is evaluated by the caller before the call, as in the
  interpreter, and released by normal frame cleanup; the body never reads it.
- **Q:** Where do the lowerings live? **A:** A small Stop module: they share
  nothing with conversions beyond the name, and Body stays under its size
  budget.

- **Q:** Should native trust any annotation on a let-bound panic? **A:** No;
  calls through it are unchecked, so a wrong parameter type would be passed
  through the frame as if it were Str. Only panic's own signature is taken.

## Evidence and remaining scope

Exact stdout/stderr/status against both evaluators for panics in entries,
nested and generic functions, loops after partial output, multi-line and
empty messages, panics through values, records and captures, and
convertInteger refusals direct and through values after argument effects.
Counted cleanup, Clang, GCC 15 and ASan/UBSan focused runs. Other builtin
values and the rest of the coverage ledger stay open.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Stop]] · [[Backend Stopping Builtin Programs]]
