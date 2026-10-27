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
methods of a byte sequence, arguments before the receiver.

## Resolved Grill Log

- `at` and `toText` answer `Option`, built in Core from a test and a read, so
  no C code needs an Option's layout. `at` tests the index against the length
  after both have run.
- `Str.toBytes()` is lowered by [[Compiler Lower Text]] and reuses the text's
  storage.

## Dependencies and consumers

[[Compiler Lower Array]] · [[Compiler Lower State]] · [[Compiler Lower Types]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]

## Total operand selection

Resolved Grill Log: split the collected operands with a nonempty pattern on
the reversed list. An empty operand list refuses at the call span; no partial
`init` or `last` is needed to select the receiver.

## Shared builder (#631)

Export bytesFromArray, the CoreBytesMethod BytesOfArray node the direct call
and the bytesOf value body both produce.
Resolved Grill Log: a UInt8 array always fits, so the value body has no
failure path.
