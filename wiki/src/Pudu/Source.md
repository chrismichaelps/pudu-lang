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

data Source -- constructor hidden; content-bounded O(name length) Show, no Eq
data Span   -- constructor hidden; O(1) Eq and content-bounded O(name length) Show

data Position = Position
  { positionLine :: !Int
  , positionColumn :: !Int
  }
  deriving stock (Eq, Ord, Show)

newSource :: SourceName -> Text -> IO Source
sourceName :: Source -> SourceName
sourceText :: Source -> Text
sourceLength :: Source -> Offset
unOffset :: Offset -> Int
emptySpan :: Source -> Span
zeroOffset :: Offset
offsetFromInt :: Int -> Maybe Offset
advanceOffset :: Int -> Offset -> Maybe Offset
mkSpan :: Source -> Offset -> Offset -> Maybe Span
zeroWidthSpan :: Source -> Offset -> Maybe Span
mergeSpans :: Span -> Span -> Maybe Span
spanSource :: Span -> SourceName
spanStart :: Span -> Offset
spanEnd :: Span -> Offset
offsetPosition :: Source -> Offset -> Maybe Position
```

### Governance

- Offsets are zero-based Unicode scalar indices in the decoded `Text` representation for v0.1, not raw UTF-8 bytes; the distinction is recorded here to avoid false byte-offset claims.
- Spans are half-open `[start,end)` and retain an opaque `Unique` minted once at source ingestion. Equal display names or content do not make separately ingested snapshots mergeable.
- Lines/columns are one-based for user display.
- Constructors validate ordering and source bounds; raw record constructors are not exported.
- `newSource` computes scalar length once. Span checks and `sourceLength` use the cached strict field, so token emission cannot rescan the full source for every span.
- Public accessors are total. Accessors, cached length, span equality, and `mergeSpans` are O(1); content-free `Show` is O(source-name length); `offsetPosition` is O(prefix scalars).
- `newSource` is the only identity-minting effect. All span construction, traversal, merging, and later compiler phases remain pure.

### Linkage

- **Requires:** [[Source Text]], [[grammar/haskell]].
- **Consumed by:** [[Diagnostic Model]], [[Token]], and later compiler phases.

## Algorithm

1. At ingestion, mint an opaque process-unique snapshot identity and store it with source name, decoded text, and strict cached scalar length.
2. Construct a canonical zero-width span at offset zero from an explicit source snapshot.
3. Construct non-negative offsets and reject negative advancement or `Int` overflow before addition.
4. Validate span offsets as non-negative, ordered, and no greater than the cached source length.
5. Merge only spans carrying the same opaque snapshot identity, choosing minimum start and maximum end in O(1).
6. Convert an offset with a strict `Text` fold over the prefix, counting CRLF as one break without allocating an intermediate character list.

## Negative Logic (Prohibited Paths)

- Do not expose invalid raw span construction.
- Do not compare/merge spans from different source snapshots, even when their display names match.
- Do not derive structural `Eq` for `Source`, or structural `Ord`/unbounded `Show` for `Span`; these would traverse or reveal source content.
- Do not cache mutable line maps in this value; introduce an immutable index module only after profiling proves need.
- Do not use `String` indexing.

## Edge Cases

- Empty source permits only span `0..0` and position `1:1`.
- Offset exactly at source end is valid.
- Advancing by a negative amount or beyond `maxBound :: Int` returns `Nothing` without wrapping.
- CRLF counts as one line break for display; lone CR and LF each count as line breaks.
- Combining characters count as scalar columns, not grapheme clusters; renderer may improve display width later without changing semantic spans.
- Every separate `newSource` call creates a distinct snapshot. Spans merge only when derived from the same `Source` value, even when another source has identical name and content.

## Depth

DEPTH 0.61 (MEDIUM). A small interface hides validation and position conventions. Deletion would scatter off-by-one/source-identity policy through every phase. Initial position lookup is linear and intentionally simple for EXPLORING maturity.

## Grill Log

- **Q:** Bytes, scalars, or graphemes for stored offsets? **A:** Unicode scalar indices for v0.1 because Haskell `Text` traversal and lexer semantics align; document artifact tooling conversions later. _Rationale:_ correctness before premature byte-index optimization. _Rejected:_ pretending `Text` offsets are UTF-8 bytes; grapheme indices (wrong for compiler tokens).
- **Q:** Should invalid spans clamp? **A:** No; return `Nothing`. _Rationale:_ clamping hides compiler defects and corrupts diagnostics. _Rejected:_ permissive normalization.
- **Q:** Should position lookup be indexed now? **A:** No; keep linear until diagnostic rendering benchmarks justify a source index. _Rationale:_ no measured workload. _Rejected:_ eager line tables in every source.
- **Q:** Can offset arithmetic rely on machine `Int` wraparound? **A:** No; validate the delta and remaining headroom before addition. _Rationale:_ wrapped offsets could forge apparently valid spans. _Rejected:_ add first and validate the wrapped result.
- **Q:** Recompute `Text.length` for every span? **A:** No; cache scalar length in the hidden immutable source value. _Rationale:_ lexer token emission must remain linear rather than rescan the source per token. _Rejected:_ repeated full-text length checks; exposing an unchecked cached field.
- **Q:** Materialize a `[Char]` to compute positions? **A:** No; fold `Text` strictly with CRLF state. _Rationale:_ position rendering should allocate no source-sized list. _Rejected:_ `Text.unpack` traversal.
- **Q:** Is display name or source content sufficient identity? **A:** No; `newSource` mints an opaque runtime `Unique` at ingestion and spans copy that compact identity. _Rationale:_ editors reuse names, content equality is O(source), hashes can collide, and caller-supplied numeric IDs are forgeable. _Rejected:_ comparing only `SourceName`; content-backed equality; unchecked IDs; global unsafe counters.
- **Q:** Does IO identity pollute compiler phases? **A:** No; only source ingestion mints identity. _Rationale:_ loading/inserting a source is already a boundary operation, while every consumer receives an immutable value and remains pure. _Rejected:_ source-sized equality in hot paths to preserve a superficially pure constructor.

## Variants

- An immutable `SourceIndex` can provide logarithmic byte/scalar/line conversions without changing `Span` once profiling establishes the need.

## Referenced by

[[src/Pudu/_MOC]] · [[Diagnostic Model]] · [[Token]]
