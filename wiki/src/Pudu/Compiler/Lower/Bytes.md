---
type: module
path: "@root/src/Pudu/Compiler/Lower/Bytes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Bytes]
---
# Compiler Lower Bytes

## Purpose and interface

`lowerBytesOf` lowers `bytesOf(array)` and `lowerBytesMethod` the built-in
methods of a byte sequence, receiver before arguments.

## Resolved Grill Log

- `at` and `toText` answer `Option`, built in Core from a test and a read, so
  no C code needs an Option's layout. `at` tests the index against the length
  after both have run.
- `Str.toBytes()` is lowered by [[Compiler Lower Text]] and reuses the text's
  storage.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## strided (#846)

`strided(offset, width, stride)` answers None for a negative offset or width, a
stride below one or a width wider than the stride, and otherwise Some of
`BytesStridedOf` ([[Core Byte Operations]]). The receiver, then the operands, run
once into locals before the shape test, as every receiver call runs (#828).

## Option result layouts

Use the fixed Option payload of at, strided, or toText when the source span does not carry that layout. The payloads are UInt8, Bytes, and Str respectively.

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]

## Total operand selection

Resolved Grill Log: split the collected operands with a nonempty pattern
headed by the receiver. An empty operand list refuses at the call span; no partial
`init` or `last` is needed to select the receiver.

## Shared builder (#631)

Export bytesFromArray, the CoreBytesMethod BytesOfArray node the direct call
and the bytesOf value body both produce.
Resolved Grill Log: a UInt8 array always fits, so the value body has no
failure path.

## Selected receiver layouts (#956)

Resolved Grill Log: Select the held byte receiver before evaluating method arguments and use the payload type of the selected conversion.

## Selected invocation arguments (#956)

Resolved Grill Log: Use the selected argument slots after all arguments run. An incompatible argument takes the byte method’s invocation diagnostic.

## Selected construction input

Select the held argument to byte construction before invoking the
existing packer. A held non-array reports the constructor's arity or
shape diagnostic after argument effects. Direct and stored calls
share the builder and point at the relevant invocation.

Resolved Grill Log: only a proven byte array enters the raw packer.
Element validation remains a separate requirement for other arrays.

Arrays with wider held element layouts are validated in index order.
Accept mathematical integers in the byte range, including wider
integer kinds. Report the first incompatible element or out-of-range
value. Empty arrays succeed for any held element layout.

Resolved Grill Log: hold the source and each loaded element once.
Only validated bytes reach the existing packer.

## Integer counts and byte groups

Byte offsets and simple view bounds use clamped positions. Strided
groups compare original width and stride before clamping the validated
shape to the carrier used by the byte runtime.

Resolved Grill Log: two different large positive values remain ordered.
A reversed width and stride yields None even when neither fits Int.
