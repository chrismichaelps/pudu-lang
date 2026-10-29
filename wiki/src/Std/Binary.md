---
type: module
path: "@root/lib/Std/Binary.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, serialization]
aliases: [Std Binary]
---
# Std Binary

## Purpose and interface

Derived binary encoding for save games, network snapshots and cooked assets. `Encode.pack` turns a value
into a `Node` and `Decode.unpack` reads one back with `Result[T, BinaryError]`; records and sums opt in
with `derives Binary.Encode, Binary.Decode`, and the derives unroll per type at compile time. A
`Node` is `Whole(Int)`, `Real(Float64)`, `Flag(Bool)`, `Text(Str)`, `Raw(Bytes)`, `Reals(Bytes)`
(packed binary64), `Items`, `Absent`/`Present`, `Fields`/`Choice` (written) or `Record`/`Picked`
(read, keyed by field name). `encode`/`decode` hand a whole tree to [[Eval Binary]] in one native
pass. `write(value)` frames the encoding as `PBIN`, a 16-bit version (1) and the payload's CRC-32;
`read(bytes)` refuses `NotBinary`, `UnsupportedVersion(n)` and `ChecksumMismatch` first.

`Float64` keeps its exact bits, so NaN payloads and signed zero survive. An `Array[Float64]` and
`Lanes` travel as one contiguous `Reals` block: an array picks its form from its first element
(`packMany`), and reading dispatches on the node (`unpackReals`). `Option` is `Absent` or
`Present`, and its `missing()` is `None`, so only an `Option` field may be absent.

A record writes its fields under their wire names (the field name, or `@binary("name")`); `@skip`
fields are neither written nor read and take `missing()`. Reading ignores names it does not know
and gives an absent field `missing()`, refusing `MissingField` otherwise, so adding an optional
field and removing any field keep old and new data readable both ways. A sum writes the variant's
wire name; an unknown one is `UnknownVariant(name)`. `BinaryError` carries the `path` of field
names and `[index]` steps, and `Corrupt(message)` for anything the native reader refused, or
`WrongKind(expected)`.

## Grill Log

- **Q:** Must the derive trait be named after its implementation method? **A:** No; the public
  derive spelling is `Binary.Encode, Binary.Decode`, while their methods remain `pack`/`unpack`.
  Canonical trait identity distinguishes these from JSON's derives. Distinct method names keep
  both implementations usable until the shared-member compiler repair (#734) is delivered.

- **Q:** May a skipped sum payload field read a supplied wire value? **A:** No; record and sum
  derives both ignore it and call `missing()`, even when the bytes contain the field. The sum
  decoder checks `@skip` before lookup. This preserves transient cache exclusion across shapes.

- **Q:** Share method names with `Std.Json`? **A:** No; one type derives both, and two traits with
  the same member names for one type collide today (pudu-lang#734). `pack`/`unpack` keep a type
  usable with both.
- **Q:** Decode an absent field from an empty node? **A:** No; text and bytes have legitimate
  empty values, so a dropped field would silently read as empty. Absence goes through `missing()`.
- **Q:** Write arrays of floats element by element? **A:** No; a game's float arrays are bulk data.
  One `Reals` block is one native copy each way.

## Referenced by

[[src/Std/_MOC]] · [[Eval Binary]] · [[Binary Facade Smoke]]

Validation: [[Binary Codec Properties]] · [[Binary Facade Gate]] · [[Std Binary Fixture]] · [[Binary Serialization Benchmark]].
