---
type: module
path: "@root/src/Pudu/Backend/Runtime/Bytes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Bytes Runtime]
---
# Native Bytes Runtime

## Purpose and interface

Export bytesRuntimeParts and bytesRuntimeDependencies. A byte sequence is a
box whose one cell is a text view: the same counted storage text uses, read as
bytes. Slicing, `take` and `drop` answer views of that storage, as
`Eval.Bytes` answers `ByteString` slices.

| Part | Provides |
| --- | --- |
| bytes_wrap, bytes_from_text, bytes_as_text | transfer or retain a text view in a byte box |
| bytes_pack | `bytesOf`: an `Array[UInt8]` packed into fresh storage |
| bytes_clamp, bytes_length, bytes_at | bounds, size and guarded byte access |
| bytes_slice, bytes_take, bytes_drop | clamped views retaining their storage |
| bytes_concat, bytes_reverse, bytes_to_array | newly allocated sequence results |
| bytes_index_of, bytes_contains, bytes_starts_with, bytes_ends_with | content searches |
| bytes_is_text | the strict UTF-8 test `toText` answers by |
| bytes_show | `0x` and lowercase hex pairs |

## Semantics

Bounds clamp into the sequence and a reversed pair reads as empty. `indexOf`
of an empty needle is 0 and of an absent one -1. UTF-8 is valid when every
sequence is the shortest form of a scalar value: no overlong forms, no
surrogates, nothing past U+10FFFF, nothing truncated.

## Resolved Grill Log

- **Q:** Why a box around a text view rather than a second text type? **A:**
  Ownership then follows the boxed path every other aggregate uses, and the
  view still shares storage with what it was cut from.
- **Q:** Is the UTF-8 test the decoder's? **A:** It accepts exactly the
  well-formed sequences, which is what the strict decoder accepts.

## Dependencies and consumers

[[Native Runtime]] · [[Backend Runtime Array]]

## Referenced by

[[Backend Emit Bytes]] · [[Backend Frame Program]] · [[src/Pudu/Backend/_MOC]]
