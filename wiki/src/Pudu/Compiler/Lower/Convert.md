---
type: module
path: "@root/src/Pudu/Compiler/Lower/Convert.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Convert]
---
# Compiler Lower Convert

## Purpose and interface

`lowerConvertInteger` lowers `convertInteger[T](value)` when the name is the
prelude's. The value runs into a local; then `CoreIntegerFits` picks
`Some(CoreIntegerConvert value)` or `None`, at the Option type the checker gave
the call.

## Resolved Grill Log

- **Q:** Where does the target kind come from? **A:** From the checked type
  of the call, `Option[T]`, rather than from re-reading the written type, so
  an alias or a qualified name means what the checker decided it means.
- **Q:** What if a program defines its own `convertInteger`? **A:** A local or
  a function of that name is found first, as the checker finds it, and this
  lowering is not used.
- Other type applications, on generic functions, lower as the call they
  wrap: the checker has already solved the copy to call at that span.

- **Q:** Why fuse `unwrapOr` here rather than make options cheaper everywhere? **A:** The standard library reads every byte as an `Int` through exactly this pattern (41 files), and each read allocated and freed an option box and made a full call. Fusing the one shape keeps the interpreter's order: the operand and then the fallback still run, once each.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## charFromCode (#562)

`lowerCharFromCode` puts the code in a local, tests 0 through 0x10FFFF outside
the surrogates, and builds `Some(CoreCharOfCode code)` or `None`.

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]

## Shared builder (#631)

Export charFromCodeCore: the held code, the Unicode scalar test and the
Some/None choice for an already lowered Int operand.
Resolved Grill Log: direct calls and charFromCode values both use it.

## Selected exact integer conversions

Resolved Grill Log: select the held argument before testing the
mathematical value against the destination. Character conversion
clamps only to a sentinel outside the scalar range, where the
existing bounds check yields None.

## Always-fitting conversions (#1004)

- `fitsWithin source target` holds when every value of the source kind is a value of the target kind (an unbounded target holds every kind).
- `convertInteger[T](value)` whose operand kind fits within `T` lowers to `Some` of the widened value, with no bounds test and no held local.
- `lowerFittingUnwrap`: `Option.unwrapOr(convertInteger[T](value), fallback)`, called bare or through a module qualifier, where the operand fits within `T`, lowers to a block that runs the operand, then the fallback, and answers the widened operand. No option is built and no call is made. The choice is read from the checked types before anything is lowered, so a call that does not qualify lowers as before.
