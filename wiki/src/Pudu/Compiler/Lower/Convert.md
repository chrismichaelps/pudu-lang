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
