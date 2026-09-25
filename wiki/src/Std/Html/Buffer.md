---
type: module
path: "@root/lib/Std/Html/Buffer.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, html, buffer, performance, memory, zero-copy]
aliases: [Std Html Buffer]
---

# Std Html Buffer

## Purpose and interface

Server-side byte-plan compiler and application-output coalescer. It retains static template bytes, resolves
dynamic byte slots per response, allocates the exact final capacity, and copies each part into that
destination through `Buffer.copy`.

Provides byte assembly and output batching primitives:
- `RawChunk = Static(Bytes) | Dynamic(Str)`: Template parts definition.
- `BytePlan = { parts: Array[RawChunk], totalStaticBytes: Int }`: Immutable compiled byte plan.
- `compile(chunks: &Array[RawChunk]) -> BytePlan`: Retains source parts and sums static bytes.
- `PreparedChunk = StaticBlock(Bytes, Int) | DynamicBlock(Str)`: Opt-in compact parts with cached
  static lengths.
- `CompactBytePlan = { parts: Array[PreparedChunk], totalStaticBytes: Int }`: Joined static runs and
  their retained byte counts.
- `compileCompact(chunks: &Array[RawChunk]) -> CompactBytePlan`: Joins only adjacent static chunks,
  flushing before every dynamic slot.
- `renderToBytes(plan: &BytePlan, values: &Map[Str, Bytes]) -> Bytes`: Assembles template into contiguous `Bytes` using exact capacity allocation and memory block copying.
- `renderCompactToBytes(plan: &CompactBytePlan, values: &Map[Str, Bytes]) -> Bytes`: Uses cached
  static block lengths while preserving the same missing-dynamic-as-empty behavior.
- `AssembleError = MissingSlot(Str) | InvalidStaticSize(Int, Int) | SizeOverflow(Int, Int) |
  CopyFailed(Int, Int) | LengthMismatch(Int, Int)`: Checked assembly refusals with expected/observed
  or cursor/length context.
- `renderChecked(plan: &BytePlan, values: &Map[Str, Bytes]) -> Result[Bytes, AssembleError]`: Resolves
  every dynamic slot before allocation, validates public metadata, and propagates copy refusal.
- `renderCompactChecked(plan: &CompactBytePlan, values: &Map[Str, Bytes]) -> Result[Bytes,
  AssembleError]`: Applies the same contract to retained compact block lengths.
- `Segments = { parts: Array[Bytes], byteLength: Int }`: Validated byte parts in document order and
  their exact combined length.
- `segmentsChecked` and `segmentsCompactChecked`: Resolve and validate a plan without joining its
  byte parts, so a transport can retain segmentation and exact length without another encoding pass.
- `formatHexChunkHeader(len: Int) -> Bytes`: Bitwise nibble shift-and-mask (`>> 4`, `& 0x0F`) formatting of HTTP chunk length hex headers (`<hex>\r\n`) without string allocations.
- `coalesceToMss(chunks: &Array[Bytes], maxMss: Int) -> Array[Bytes]`: Legacy compatibility
  batching. It joins adjacent small chunks but can return an input chunk larger than `maxMss`, so
  callers must not treat the parameter as an enforced bound.
- `CoalesceError = { maximum: Int }`: Typed refusal carrying a zero or negative output limit.
- `coalesceBounded(chunks: &Array[Bytes], maxBytes: Int) -> Result[Array[Bytes], CoalesceError]`:
  Preserves all non-empty input bytes in order while ensuring every returned application-output
  chunk is at most a positive `maxBytes`.

## Complexity and limits

Static compilation is paid once at server boot. Plan evaluation computes exact total byte capacity
in $O(N)$ and copies chunks into a single contiguous buffer. `coalesceBounded` visits each input and
emitted slice once, shares backing storage for slices of oversized input, and copies only when
`Bytes.join` must combine multiple pieces in one output chunk. Its positive limit bounds each
application-output chunk; it does not claim or control TCP packet, TLS-record, or HTTP frame
boundaries. Empty input chunks contribute no output, and a nonpositive limit returns
`CoalesceError` carrying that limit. The legacy `coalesceToMss` contract remains unchanged and is
not a hard bound.
The module does not parse or validate HTML syntax beyond structure declared in `RawChunk`.

Compact compilation pays one `Bytes.join` per non-empty adjacent static run and retains the joined
bytes plus one cached length. Per response it visits one static part per run and reads the cached
length instead of visiting every source fragment and asking each for its length. A dynamic slot is a
hard boundary; equal or repeated names remain separate output positions. The legacy `BytePlan`,
`compile`, and `renderToBytes` contracts remain unchanged.

Checked assembly performs two bounded phases. Resolution walks in document order, looks up each
unique dynamic name once, and records one byte part per output position; a repeated name therefore
reuses its resolved value but remains repeated in output. Missing names fail before allocation, while
a supplied empty value is a present zero-length part. Capacity begins with the plan's declared static
total so overflow can be refused before allocation, then the actual static lengths are summed and
compared with that declaration. Compact plans additionally compare every retained `StaticBlock`
length with its bytes. Writing uses only the resolved parts, propagates any `Buffer.copy` refusal, and
requires the final cursor to equal the allocated length before exposing bytes.
The checked renderers consume the same validated `Segments` representation exposed by the segmented
APIs; validation and length accounting therefore have one contract for segmented and contiguous
delivery.

## Grill Log

- **Q:** Why use `Buffer` and `Bytes` instead of `Str` for HTML templates? **A:** The response
  boundary needs bytes and exact byte lengths; copying into one destination avoids a second text
  encoding pass.
- **Q:** Correct `coalesceToMss` in place? **A:** No; callers may depend on its legacy return shape.
  The bounded contract is additive and explicit.
- **Q:** Does `maxBytes` promise a TCP packet or transport frame boundary? **A:** No; it limits only
  the byte arrays returned to the application. Lower layers may split or combine them.
- **Q:** Silently reinterpret a zero or negative limit? **A:** No; `coalesceBounded` returns a
  `CoalesceError` with the supplied value.
- **Q:** Copy every slice from an oversized input? **A:** No; `Bytes.slice` shares its source
  storage. A copy is paid only when multiple pieces must be joined into one output chunk.
- **Q:** How are chunk size hex headers formatted without string allocations? **A:** Bitwise operations extract 4-bit nibbles and map them directly into ASCII byte values.
- **Q:** Does bounded coalescing imply early-flush behavior? **A:** No; callers choose which groups
  to coalesce and must send intentional flush boundaries separately.
- **Q:** Replace `BytePlan` or add fields to its public record? **A:** No; that would break manual
  construction and exhaustive source matches. Compact byte plans use an additive type and functions.
- **Q:** Join static bytes on every response? **A:** No; `compileCompact` joins once and stores each
  block's exact byte length beside it.
- **Q:** Join across `Dynamic` when the value is absent? **A:** No; presence is request-specific and
  a dynamic position remains an ordering boundary even when one request supplies no bytes.
- **Q:** Change permissive callers to fail on missing slots? **A:** No; `renderToBytes` and
  `renderCompactToBytes` retain compatibility. Checked assembly is additive and callers migrate
  explicitly.
- **Q:** Treat missing and empty as the same output? **A:** No; an absent map entry is
  `MissingSlot`, while present empty bytes are a valid zero-length value.
- **Q:** Trust public size metadata because `compile` produced it? **A:** No; callers can construct
  both public plan records and compact variants directly, so checked assembly recomputes and compares
  every static length before allocation succeeds.
- **Q:** Advance after a refused copy? **A:** No; checked writing returns `CopyFailed` immediately and
  never exposes its partial destination.
- **Q:** Recompute length when a caller wants segmented output? **A:** No; resolution returns the
  validated parts and exact length together, and contiguous completion consumes that same shape.

## Dependencies and consumers

- [[Std Buffer]] supplies unboxed contiguous byte storage and `Buffer.copy`.
- [[Std Bytes]] supplies byte slicing and joining.
- Consumed by [[Std Html Stream]] and [[Std Http Server Stream]].

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]] · [[2026-09-20-html-plan-compaction]] ·
[[2026-09-20-html-byte-plan-errors]] · [[2026-09-20-encoded-ssr-responses]] ·
[[2026-09-20-bounded-html-output]]
