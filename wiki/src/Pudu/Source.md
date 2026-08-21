---
type: module
path: "@root/src/Pudu/Source.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.61
depth_status: MEDIUM
coupling: 1.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Source]
---

# Source

> `{-| @Source.Text.Module — preserves stable source locations -}`

## Purpose

Represent immutable [[Source Text]] identity and half-open spans while centralizing offset validation and user-facing line/column lookup.

## Interface

### Signatures

```haskell
newtype SourceName = SourceName { unSourceName :: Text }
  deriving stock (Eq, Ord, Show)

newtype Offset = Offset { unOffset :: Int }
  deriving stock (Eq, Ord, Show)

data Source -- constructor hidden; caches decoded scalar length

data Span = Span
  { spanSource :: !SourceName
  , spanStart :: !Offset
  , spanEnd :: !Offset
  }
  deriving stock (Eq, Ord, Show)

data Position = Position
  { positionLine :: !Int
  , positionColumn :: !Int
  }
  deriving stock (Eq, Ord, Show)

mkSource :: SourceName -> Text -> Source
emptySpan :: SourceName -> Span
zeroOffset :: Offset
offsetFromInt :: Int -> Maybe Offset
advanceOffset :: Int -> Offset -> Maybe Offset
mkSpan :: Source -> Offset -> Offset -> Maybe Span
zeroWidthSpan :: Source -> Offset -> Maybe Span
mergeSpans :: Span -> Span -> Maybe Span
offsetPosition :: Source -> Offset -> Maybe Position
sourceLength :: Source -> Offset
```

### Governance

- Offsets are zero-based Unicode scalar indices in the decoded `Text` representation for v0.1, not raw UTF-8 bytes; the distinction is recorded here to avoid false byte-offset claims.
- Spans are half-open `[start,end)` and cannot cross source identities.
- Lines/columns are one-based for user display.
- Constructors validate ordering and source bounds; raw record constructors are not exported.
- `mkSource` computes scalar length once. Span checks and `sourceLength` use the cached strict field, so token emission cannot rescan the full source for every span.

### Linkage

- **Requires:** [[Source Text]], [[grammar/haskell]].
- **Consumed by:** the next diagnostic-model slice and later compiler phases.

## Algorithm

1. Store source identity, decoded text, and its strict cached scalar length without mutation.
2. Construct a canonical zero-width span at offset zero for synthetic source identities.
3. Construct non-negative offsets and reject negative advancement or `Int` overflow before addition.
4. Validate span offsets as non-negative, ordered, and no greater than the cached source length.
5. Merge only same-source spans, choosing minimum start and maximum end.
6. Convert an offset with a strict `Text` fold over the prefix, counting CRLF as one break without allocating an intermediate character list.

## Negative Logic (Prohibited Paths)

- Do not expose invalid raw span construction.
- Do not compare/merge spans from different source names.
- Do not cache mutable line maps in this value; introduce an immutable index module only after profiling proves need.
- Do not use `String` indexing.

## Edge Cases

- Empty source permits only span `0..0` and position `1:1`.
- Offset exactly at source end is valid.
- Advancing by a negative amount or beyond `maxBound :: Int` returns `Nothing` without wrapping.
- CRLF counts as one line break for display; lone CR and LF each count as line breaks.
- Combining characters count as scalar columns, not grapheme clusters; renderer may improve display width later without changing semantic spans.

## Depth

DEPTH 0.61 (MEDIUM). A small interface hides validation and position conventions. Deletion would scatter off-by-one/source-identity policy through every phase. Initial position lookup is linear and intentionally simple for EXPLORING maturity.

## Grill Log

- **Q:** Bytes, scalars, or graphemes for stored offsets? **A:** Unicode scalar indices for v0.1 because Haskell `Text` traversal and lexer semantics align; document artifact tooling conversions later. _Rationale:_ correctness before premature byte-index optimization. _Rejected:_ pretending `Text` offsets are UTF-8 bytes; grapheme indices (wrong for compiler tokens).
- **Q:** Should invalid spans clamp? **A:** No; return `Nothing`. _Rationale:_ clamping hides compiler defects and corrupts diagnostics. _Rejected:_ permissive normalization.
- **Q:** Should position lookup be indexed now? **A:** No; keep linear until diagnostic rendering benchmarks justify a source index. _Rationale:_ no measured workload. _Rejected:_ eager line tables in every source.
- **Q:** Can offset arithmetic rely on machine `Int` wraparound? **A:** No; validate the delta and remaining headroom before addition. _Rationale:_ wrapped offsets could forge apparently valid spans. _Rejected:_ add first and validate the wrapped result.
- **Q:** Recompute `Text.length` for every span? **A:** No; cache scalar length in the hidden immutable source value. _Rationale:_ lexer token emission must remain linear rather than rescan the source per token. _Rejected:_ repeated full-text length checks; exposing an unchecked cached field.
- **Q:** Materialize a `[Char]` to compute positions? **A:** No; fold `Text` strictly with CRLF state. _Rationale:_ position rendering should allocate no source-sized list. _Rejected:_ `Text.unpack` traversal.

## Variants

- An immutable `SourceIndex` can provide logarithmic byte/scalar/line conversions without changing `Span` once profiling establishes the need.

## Referenced by

[[src/Pudu/_MOC]]
