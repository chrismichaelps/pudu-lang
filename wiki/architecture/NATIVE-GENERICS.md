---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, generics]
aliases: [Native Generics]
---
# Native Generics

Native code has no polymorphic values, so each generic body is lowered once per
distinct list of type arguments it is called at.

## Contract

- **Type arguments come from checking.** The callee's span holds the
  instantiated function type; for a method, the receiver's type goes in front
  of the callee's bound inputs. [[Compiler Lower Generic]] matches the scheme
  against it.
- **Bindings flow.** Each argument is formed in the caller's facts, so a copy
  calling another generic passes its own bindings through. Facts inside a copy
  that name its rigid parameters form through [[Compiler Lower Types]].
- **Bounds dispatch statically.** A bounded call such as `value.name()` on a
  `T: Named` receiver forms `T` and picks the concrete method, so trait
  dictionaries never exist at run time.
- **Generic records.** `CoreRecordType` carries type arguments as
  `CoreSumType` does, so each instantiation gets its own layout and helpers.
- **No silent drop.** Lowering that stops always records a refusal. A
  specialization with an unrepresentable argument refuses at the callee, and
  [[Compiler Lower Body]] refuses any statement that stops without one.

## Not yet

Higher-kinded parameters, static members selected through a type parameter,
function values and `dynamic` values refuse with E6001.

## Delivered (#552)

[[Backend Generic Programs]] passes against hand-written answers and both
interpreter modes under Clang, GCC 15 and ASan/UBSan, with counted cleanup.
The fixture sweep found two Std programs that built natively to an empty
`main`; both refuse now, and EmitSpec keeps a regression case for it.

## Resolved Grill Log

- Specialize rather than box: every observable behavior depends only on the
  concrete types, and the checker already settled them.
- A parameter no value holds stands for unit, as with unconstrained sum
  arguments.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Generic]] · [[Backend Generic Programs]]
