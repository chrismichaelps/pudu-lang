---
type: module
path: "@root/src/Pudu/Eval/TextView.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, text, view]
aliases: [Eval TextView]
---

# Eval TextView

## Purpose, interface and invariants

`Pudu.Eval.TextView` gives `Std.StringView` byte-addressed access to a `Str`
without copying it. Offsets count UTF-8 bytes from the start of the text.

- `callTextByteSize`: the text's length in bytes. Constant time.
- `callTextByteSlice`: `Some` of the bytes `start` up to `end`, sharing the
  source's storage; `None` unless `0 <= start <= end <= size` and both offsets
  fall on a scalar boundary. Constant time.
- `callTextByteFind`: the byte offset of the first occurrence of `needle` at or
  after `from`; `None` when absent or when `from` is outside `0..=size`. An
  empty needle is found at `from`.
- `callTextByteFindLast`: the byte offset of the last occurrence, overlapping
  matches included; an empty needle is found at `size`.
- `callTextScalarAt`: `Some((scalar, width))` for the scalar starting at a byte
  offset, `width` being its encoded length; `None` past the end or inside a
  scalar.

Each `call*` wrapper reads its arguments and calls one pure function —
`byteSlice`, `byteFind`, `byteFindLast` or `scalarAt` — which are exported so
the model property in `test/Pudu/Eval/TextViewSpec.hs` can compare them with a
byte-level reference over random mixed-width text at every offset, and so a
native lowering has one definition to match.

A match of a well-formed needle always starts on a scalar boundary, because
its first byte is a leading byte. Searching therefore needs no alignment
check of its own, and a `from` inside a scalar is admitted.

## Grill Log

- **Q:** Count offsets in scalars like `Str` methods do? **A:** No. A scalar
  position costs a walk from the start, so every view operation would cost
  the length of the text before it. Byte offsets make slicing and size
  constant-time, which is what a view is for. _Rejected:_ scalar offsets.
- **Q:** Clamp a slice that splits a scalar? **A:** No; answer `None`. Rounding
  to the nearest boundary would silently change which text the caller gets.
- **Q:** Copy the slice out? **A:** No; the slice names a stretch of the same
  array, and the source stays alive as long as the slice does.
- **Q:** Use the library's non-overlapping index list for `findLast`? **A:** No;
  it skips overlapping matches (`"aa"` in `"aaa"` is last found at 1, not 0).
  The last match is found by comparing backwards from the end.

## Dependencies and consumers

- **Requires:** [[Eval Env]], [[Eval Value]].
- **Consumed by:** [[Eval Builtin]], [[Std StringView]].

## Referenced by

[[src/_MOC]] · [[Std StringView]]
