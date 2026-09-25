---
type: module
path: "@root/src/Pudu/Cache/Persist.hs"
fidelity: Active
domain: "[[Compiler Pipeline]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.72
depth_status: DEEP
coupling: 2.0
interface_stability: 0.8
tags: [module, deep, performance, cache]
aliases: [Cache Persist]
---

# Cache Persist

## Purpose

A compact binary form for compiler products that reads back against the source text of the run
reading it, fails instead of throwing, and can leave parts of a value unread until they are used.

## Interface

```haskell
class Persist a where
  persist :: Source -> a -> Builder      -- generic default for sums and products
  restore :: Decode a
encodeFor :: Persist a => Source -> a -> ByteString
decodeWith :: Persist a => Source -> ByteString -> Maybe a
persistDeferred :: Persist a => Source -> a -> Builder
restoreDeferred :: Persist a => Decode a
failDecode :: Decode a
```

## Governance

- **A span is two offsets in the source being written**, rebound on reading to the `Source` this run
  read, so a stored tree can never point into other text. A span into another source is written as a
  marker that makes the read fail; such a value is never stored as a hit.
- **Reading never throws.** A short, foreign, or malformed buffer is `Nothing`, which a cache treats
  as a miss. A buffer must be consumed exactly.
- **A sum is its constructor's position, then its fields.** How many constructors each side of a
  sum holds is a type-level number, so it is a constant in compiled code; counting it at run time
  was most of the cost of reading a stored tree.
- **Deferred blocks** are length-prefixed and decoded on first use. The decoder's step keeps its
  value lazy so a deferred block stays unread; the enclosing entry is verified whole before any
  block is read, so a block that will not read is a fault in the compiler and says to run with
  `PUDU_CACHE=off`.
- Integers are zig-zag variable-length; numbers a tree holds usually take one or two bytes. Both
  steps work on the 64 unsigned bits: the zig-zag is `(n << 1) xor (n >> 63)`, and the varint writes
  a `Word64` seven bits at a time in at most ten bytes. Every `Int` therefore round-trips — the
  bits of a `Float64` constant and `minBound` included — where shifting the signed number overflowed
  from 2^62 and wrote a value the reader rejected. Below 2^62 the bytes are unchanged.
- An `Integer` is written as its decimal text through the `Text` encoding, exact at every size; a
  module the evaluator runs carries resolved literals of any width ([[Compiler Literals]]).

## Linkage

- **Requires:** [[Source]].
- **Consumed by:** [[Syntax Tree]], [[Located Syntax]], [[Syntax Name]], [[Compiler Cache]].

## Negative Logic (Prohibited Paths)

- No file access, no hashing, no exceptions on malformed input, no spans from other sources.

## Grill Log

- **Q:** Why encode on unsigned bits? **A:** A folded `Float64` constant is stored as its IEEE bits
  in an `Int`, which is routinely beyond 2^62. _Rationale:_ an encoding must be total over its type.
  _Rejected:_ a separate float encoding, which would leave the same overflow waiting in `Int`.

- **Q:** Use a general serialization library? **A:** No. _Rationale:_ spans must be rebound to the
  reading run's source identity, and deferred blocks need a decoder whose step is lazy in its
  value. _Rejected:_ derived instances from a library that cannot carry the source.
- **Q:** Why a type-level constructor count? **A:** A count computed per node dominated warm reads
  (over 70% of time). _Rejected:_ per-branch tag bits, which grow every node.

## Referenced by

[[src/Pudu/_MOC]] · [[Compiler Cache]] · [[Syntax Tree]]
