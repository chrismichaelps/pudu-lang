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

Hardware-aware server-side rendering compiler and buffer coalescer. Pre-compiles static HTML document templates into contiguous, unboxed `Buffer` slices at startup. Dynamic slots are rendered directly into pre-allocated memory buffers via `Buffer.copy` (`memcpy` semantics), avoiding intermediate string allocations, UTF-8 re-encoding, and garbage collection pressure in the SSR hot path.

Provides network transport optimizations:
- `RawChunk = Static(Bytes) | Dynamic(Str) | HexFrame(Int)`: Template parts definition.
- `BytePlan = { parts: Array[RawChunk], totalStaticBytes: Int }`: Immutable compiled byte plan.
- `compile(chunks: &Array[RawChunk]) -> BytePlan`: Pre-allocates and indexes static byte sections.
- `renderToBytes(plan: &BytePlan, values: &Map[Str, Bytes]) -> Bytes`: Assembles template into contiguous `Bytes` using exact capacity allocation and memory block copying.
- `formatHexChunkHeader(len: Int) -> Bytes`: Bitwise nibble shift-and-mask (`>> 4`, `& 0x0F`) formatting of HTTP chunk length hex headers (`<hex>\r\n`) without string allocations.
- `coalesceToMss(chunks: &Array[Bytes], maxMss: Int) -> Array[Bytes]`: Batches small streaming chunks up to the TCP Maximum Segment Size (MSS, ~1460 bytes) before socket transmission, minimizing OS socket syscalls and cellular radio power transitions.

## Complexity and limits

Static compilation is paid once at server boot. Plan evaluation computes exact total byte capacity in $O(N)$ and copies chunks into a single contiguous buffer using unboxed memory blocks. `coalesceToMss` preserves chunk order and bounds peak buffer aggregation to `maxMss`. It does not parse or validate HTML syntax beyond structure declared in `RawChunk`.

## Grill Log

- **Q:** Why use `Buffer` and `Bytes` instead of `Str` for HTML templates? **A:** High-throughput SSR generates thousands of temporary strings. Contiguous unboxed byte storage and `Buffer.copy` execute direct machine `memcpy`, eliminating GC allocation and Unicode decoding overhead.
- **Q:** Why coalesce chunks to TCP MSS (~1460 bytes)? **A:** Emitting small chunks over cellular networks causes packet header bloat (40 bytes per packet), silly window syndrome, socket context switches, and triggers mobile radio battery drain. Coalescing batches output to MTU boundaries.
- **Q:** How are chunk size hex headers formatted without string allocations? **A:** Bitwise operations extract 4-bit nibbles and map them directly into ASCII byte values.
- **Q:** Does coalescing delay early flush headers? **A:** No; callers emit early flush headers as distinct immediate chunks before streaming coalesced body fragments.

## Dependencies and consumers

- [[Std Buffer]] supplies unboxed contiguous byte storage and `Buffer.copy`.
- [[Std Bytes]] supplies byte slicing and joining.
- Consumed by [[Std Html Stream]] and [[Std Http Server Stream]].

## Referenced by

[[src/Std/_MOC]] · [[2026-09-06-application-stack]]
