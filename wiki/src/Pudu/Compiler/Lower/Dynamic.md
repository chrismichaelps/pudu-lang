---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Dynamic.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Dynamic]
---
# Compiler Lower Dynamic

Export dynamicSums, isDynamic, widen, widenBlock, widenTo, writtenType and
pathText. `dynamicSums` gives every trait a sum over its implementing types:
one variant per implementation without parameters of its own, named by the
owner's key and holding the value. The sum is filed under the trait's own
identity inside a `dynamic` module no program can declare, which is what
[[Compiler Lower Types]] forms a `dynamic Trait` to.

`widen` answers a value as an expected type holds it: itself when the types
agree, its variant when the expected type is dynamic and the value's type is
one of the implementing types. A literal whose members are expected dynamic
(an array, tuple, record, variant, block, `if` or `match`) is built again
with each member widened, to any depth. `widenBlock` widens a block's
result and `widenTo` answers the widened value beside its type.

`writtenType` forms a written type with the given names rigid; resolution
has already made every path canonical. [[Compiler Lower Method]] reads
implementation heads through it.

## Resolved Grill Log

A closed sum is the whole dispatch table: lowering sees every implementation
of the program, so a method call is a match over the held type and needs no
table of function addresses. Widening happens only where a dynamic type is
expected, the one direction checking allows. An implementation with its own
parameters names no single type and is not a variant; widening a value of
such a type leaves it as it is, and the site refuses on the type mismatch.
A value that is not a literal and holds an implementing type inside another
type is not converted.

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower Method]] · [[Compiler Lower Generic]] · [[Compiler Lower Array]] · [[Compiler Lower Record]] · [[Compiler Lower Sum]] · [[Compiler Lower Match]] · [[Compiler Lower Call]] · [[Native Type Abstractions]]
