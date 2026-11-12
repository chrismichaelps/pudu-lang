---
type: architecture
tags: [backend, native, text]
aliases: [Native Text Views]
---
# Native Text Views

Project the six [[Eval TextView]] primitives into portable native C11.
Size is bytes; byteAt returns exact UInt8, even inside a scalar. Slices
share the existing owner and require ordered scalar-boundary positions.
Search offsets are bytes, empty needles retain interior positions, and
reverse search includes overlaps. scalarAt returns the scalar and UTF-8
width only at a scalar start strictly before the end.

## Resolved Grill Log

- Reuse owned text and ordinary Option/tuple carriers; no pointer ABI,
  source API, inference or interpreter fallback. Arguments are held once
  left-to-right before receiver-last CoreTextMethod reads. Stop immediately
  on Never. Exact solved signatures govern direct calls and builtin values.
- Add internal byte-size/index/byte-read/slice-validity/slice/search/scalar
  read/width tags. Optional reads are guarded; searches run once into an
  Int local with -1 for absence, then construct the checked Option.
- Scalar validity combines bounded index and scalar-boundary checks.
  Reuse UTF-8 decode/width and retained text_view kernels. Bounds are
  checked as magnitudes before host indexing; searches compare against
  length minus needle length, avoiding addition overflow.
- Keep existing deep Lower.Text and Runtime.Text.Methods modules. A bounded
  [[Backend Frame Text Views]] translator owns byte-method carrier validation
  and C helper selection; the main Value dispatcher remains below 500 lines.
  Pass saved-slot rendering to avoid an import cycle. Legacy Str methods
  retain their existing path and evaluation order.
- Granular helpers must compile warning-free even for standalone builtin
  entries. Slices retain owners through parent/source release. Explicit
  output, failure, malformed-frame and counted-cleanup evidence is required
  with both evaluators, Clang/GCC and sanitizers before promotion.

## Referenced by

[[architecture/_MOC]] · [[Native Text View Delivery]] · [[Compiler Lower Text]]
