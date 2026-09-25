---
type: module
path: "@root/src/Pudu/Eval/Csv.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, csv, streaming]
aliases: [Eval Csv]
---

# Eval Csv

## Purpose, interface and invariants

`Pudu.Eval.Csv` reads separated records out of bytes for [[Std Csv]], so reading a row costs native
work and one interpreted step rather than one interpreted step per character.

- `csvRecords(buffer: Bytes, delimiter: Str) -> Option[(Array[Array[Str]], Int, Int)]` answers the
  complete records at the front of `buffer`, the bytes they span, and the characters they span.
  It answers `None` when a complete record is not valid UTF-8. The delimiter must be one byte other
  than a quote or a line ending; anything else is refused with `E7004`.
- `scanRecords` is the pure scan behind it.

A record is complete at the first newline outside quotes. The rows are exactly the ones the
character scanner in `Std.Csv` gives: a quote anywhere outside quotes opens a quoted section of the
current field, two adjacent quotes inside one are one quote, a delimiter or newline inside one is
data, and a carriage return that ends a record's last field is dropped.

## Algorithm

Outside quotes the scan searches for the next quote, delimiter, or newline; inside quotes it searches
only for the next quote. The bytes between those positions are kept as slices of the buffer and each
field is joined and decoded once when it ends, so a decoded field holds none of the buffer. Structural
bytes are ASCII, so a slice never divides an encoded character.

A quote in the buffer's last byte leaves the record incomplete, because the next bytes decide whether
it closes the field or is the first of an escaped pair. A caller at the end of its input appends a
newline, which settles it. The characters spanned count every byte that does not continue a UTF-8
sequence.

## Grill Log

- **Q:** Parse chunks in parallel with a speculated quote state? **A:** Not here. _Rationale:_
  `Std.Csv.foldRows` hands each row to an interpreted step in order, and that call, not the scan,
  bounds its throughput. _Accepted:_ a sequential native scan whose remainder is carried to the
  next chunk.
- **Q:** Answer the position of an unterminated field? **A:** No. _Rationale:_ the library's
  character scanner already names it, and only a failing input pays for that scan.
- **Q:** Return the rows decoded or as byte slices? **A:** Decoded. _Rationale:_ a slice would keep
  the whole chunk alive for as long as any field of it is held.

## Dependencies and consumers

- **Requires:** [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std Csv]].

## Referenced by

[[src/_MOC]] · [[Std Csv]]
