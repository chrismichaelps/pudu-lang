---
type: module
path: "@root/src/Pudu/Frontend/Lexer/Cursor.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.68
depth_status: DEEP
coupling: 3.0
interface_stability: 0.8
tags: [module, deep, lexer]
aliases: [Lexer Cursor]
---

# Lexer Cursor

> `{-| @Source.Lexer.Cursor.Module — owns linear lossless source traversal -}`

## Purpose

Centralize strict Unicode-scalar traversal, snapshot-safe captures, non-overlapping token/trivia emission, and deterministic lexical completion for the [[Frontend]].

## Interface

### Signatures

```haskell
data LexerCursor -- constructor hidden
data CursorMark  -- constructor hidden
data LexerOutput -- constructor hidden; Eq and Show

newCursor :: Source -> LexerCursor
cursorOffset :: LexerCursor -> Offset
cursorAtEnd :: LexerCursor -> Bool
peekScalar :: LexerCursor -> Maybe Char
cursorStartsWith :: Text -> LexerCursor -> Bool
consumeScalars :: Int -> LexerCursor -> LexerCursor
markCursor :: LexerCursor -> CursorMark
captureSince :: CursorMark -> LexerCursor -> Maybe (Text, Span)
emitTrivia :: CursorMark -> TriviaKind -> LexerCursor -> Maybe LexerCursor
emitToken :: CursorMark -> TokenKind -> LexerCursor -> Maybe LexerCursor
recordDiagnostic :: Diagnostic -> LexerCursor -> Maybe LexerCursor
pendingTriviaCount :: LexerCursor -> Int
completeCursor :: LexerCursor -> Maybe LexerOutput
outputTokens :: LexerOutput -> [Token]
outputDiagnostics :: LexerOutput -> [Diagnostic]
```

### Governance

- The cursor is immutable and strict. It owns one [[Source]] snapshot, its current zero-width point, its last committed point, the unconsumed `Text` suffix, reversed token/diagnostic/trivia accumulators, and a strict pending-trivia count.
- `CursorMark` is opaque and carries a snapshot-bound zero-width point plus the suffix at that point. Capture validates snapshot identity and forward ordering before taking only the consumed prefix from the mark suffix.
- Token and trivia emission require a positive-width capture beginning exactly at the last committed point. Successful emission advances the committed point, preventing gaps, overlap, duplication, and mark reuse.
- Emitting `Invalid rejected` additionally requires `rejected` to equal the exact captured text.
- Token emission rejects `EndOfFile`; completion alone creates the zero-width EOF token and attaches ordered pending trivia exactly once in the returned output.
- Diagnostics must belong to the cursor snapshot and end no later than the current point. Related locations remain governed by [[Diagnostic Model]] and may refer to other sources.
- Completion succeeds only at physical EOF with no uncommitted source. It reverses accumulated tokens once and canonicalizes diagnostics with `sortDiagnostics` once.

### Linkage

- **Requires:** [[Source]], [[Token]], [[Diagnostic Model]], [[Performance Constitution]], [[grammar/haskell]].
- **Consumed by:** category scanners and the public lexer facade in later dependency-ordered issues.

## Algorithm

1. Initialize current and committed points with `emptySpan`, retain the original source and full text suffix, and initialize strict empty accumulators.
2. Peek without consuming, or consume at most the requested positive scalar count by tail-recursive `Text.uncons`; zero and negative requests are unchanged, and oversized requests stop exactly at EOF.
3. Mark by copying the current point and suffix. Capture only when the mark is from the same snapshot and not later than the cursor, returning the mark suffix prefix whose scalar length equals the offset delta.
4. Emit only when the mark equals the committed point and capture width is positive. Cons trivia onto the pending accumulator; cons tokens with reversed pending trivia restored and then clear the pending state.
5. Cons validated diagnostics without sorting. At EOF, create one EOF token from the current point, attach remaining trivia, reverse tokens, and sort diagnostics.

## Complexity

- Construction, offset/end queries, scalar peek, mark, pending count, and accumulator insertion are O(1).
- Consuming `n` scalars is O(min(n, remaining scalars)) with no accepted-token backtracking.
- Prefix testing is O(prefix scalars); capture is O(captured scalars) and never drops from the full source prefix.
- Completion is O(tokens + trivia + diagnostics log diagnostics), paid once.

## Negative Logic (Prohibited Paths)

- No source-wide `Text.length`, `Text.drop` from offset zero, repeated list append, or diagnostic sorting in the scan loop.
- No exported cursor/mark constructors or caller-supplied offsets, spans, lexeme text, trivia text, or EOF tokens.
- No capture from another snapshot, a later mark, or an emission mark different from the committed point.
- No zero-width ordinary token/trivia emission, skipped source, overlapping source ownership, or second EOF in one output.
- No `Invalid` token whose retained rejected text differs from its captured lexeme.
- No scanner classification, escape decoding, recovery policy, or diagnostic-code selection in this module.

## Edge Cases

- Empty input completes immediately as one zero-width EOF token with no trivia.
- Non-positive consumption is unchanged; oversized consumption reaches EOF without offset overflow.
- Unicode supplementary scalars and combining marks each advance one scalar offset.
- Equal-name/equal-content source snapshots cannot share marks, captures, emissions, or primary diagnostics.
- A later-state mark is rejected against an earlier cursor even when both belong to one source.
- Completion before EOF or with an uncommitted consumed suffix returns `Nothing`.
- Trailing comments/whitespace are emitted as pending trivia and become EOF leading trivia in original order.
- Invalid input retains the exact rejected source segment in both its kind payload and lexeme.
- Diagnostics emitted in arbitrary order return in the canonical [[Diagnostic Model]] render order.

## Depth

DEPTH 0.68 (DEEP). This module hides traversal, snapshot identity, segment ownership, accumulator ordering, and EOF finalization behind one narrow phase boundary. Removing it would duplicate correctness and performance invariants across every scanner.

## Grill Log

- **Q:** Store a full source and numeric offset only? **A:** Also retain the unconsumed suffix and zero-width point. _Rationale:_ scanners need O(1) peeking and captures must not repeatedly traverse from source offset zero. _Rejected:_ `Text.drop offset source` for every token; unpacked character lists.
- **Q:** Let marks expose offsets? **A:** No; bind an opaque mark to a zero-width source span and suffix. _Rationale:_ `mergeSpans` validates opaque snapshot identity while offset ordering rejects future marks. _Rejected:_ forgeable public offset/source-name pairs; content equality.
- **Q:** Is snapshot and forward validation enough for emission? **A:** No; require the mark to equal the last committed point. _Rationale:_ otherwise callers can reuse an old mark, overlap tokens, or skip text while still producing valid spans. _Rejected:_ trusting scanner call order; validating only `mark <= current`.
- **Q:** Accept lexeme/trivia text from scanners? **A:** No; derive exact text and span together from the mark suffix. _Rationale:_ independent caller fields can disagree and break losslessness. _Rejected:_ `emitToken kind text span`; source reslicing by consumers.
- **Q:** May an `Invalid` payload differ from its captured lexeme? **A:** No; reject the emission. _Rationale:_ invalid-token recovery promises exact rejected-text retention. _Rejected:_ trusting duplicated caller text; silently rewriting the payload.
- **Q:** Permit ordinary EOF emission? **A:** No; completion owns EOF. _Rationale:_ one finalizer can attach trailing trivia once and guarantee terminal ordering. _Rejected:_ scanner-created EOF; implicit EOF without a token.
- **Q:** Append tokens and diagnostics in source order? **A:** Cons in the hot loop and restore order once. _Rationale:_ repeated list append is quadratic. _Rejected:_ difference-list machinery before measurement; repeated sorting.
- **Q:** Validate diagnostic related spans against the cursor source? **A:** No; validate only the primary span. _Rationale:_ related context may legitimately cross sources. _Rejected:_ rejecting imported/macro-related locations; accepting a foreign primary diagnostic.
- **Q:** Use mutable buffers or byte offsets now? **A:** No. _Rationale:_ strict suffix traversal is linear and matches the v0.1 scalar-offset contract; lower-level representation requires benchmarks. _Rejected:_ premature `ST`; mislabeled `Text` indices as UTF-8 bytes.

## Variants

- A measured lexer may replace the suffix representation with a compact byte/scalar index or local mutable buffer behind this interface, provided exact scalar spans and lossless output remain observationally identical.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
