---
type: module
path: "@root/src/Pudu/Frontend/Lexer/Trivia.hs"
fidelity: Proposed
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.56
depth_status: MEDIUM
tags: [module, medium, lexer]
aliases: [Trivia Scanner]
---

# Trivia Scanner

> `{-| @Source.Lexer.Trivia.Module — preserves whitespace and comments -}`

## Purpose

Consume one maximal whitespace or comment segment into [[Lexer Cursor]] pending trivia without classifying semantic tokens.

## Interface

```haskell
scanTrivia :: LexerCursor -> Maybe LexerCursor
```

## Governance

- A non-match returns `Nothing`; success consumes and commits at least one scalar.
- Whitespace follows the locked `base` Unicode `isSpace` classification and is emitted as one maximal `Whitespace` trivia segment.
- A line comment begins with `//`, excludes CR/LF from its `LineComment` segment, and stops at EOF or before the line terminator so the next call preserves that terminator as whitespace.
- A block comment begins with `/*`, nests on `/*`, closes on the matching `*/`, and is emitted as one exact `BlockComment` segment including delimiters.
- An unterminated block comment consumes through EOF, emits its exact trivia first, then records one error `E0003` over the full comment with message `unterminated block comment`.

## Algorithm

1. Prefer maximal whitespace, then line comment, then block comment; these prefixes are mutually exclusive at one cursor position.
2. Consume whitespace and line bodies with `consumeWhile` so long segments allocate one cursor point.
3. Scan a block comment with a strict depth counter, consuming two-scalar delimiters and maximal runs containing neither `/` nor `*`.
4. Emit via the opening mark. On EOF at positive depth, derive the same capture span and record `E0003` after trivia emission.

## Negative Logic

- No comment stripping, newline absorption into line comments, non-nesting block scan, source-prefix reslicing, or scanner backtracking.
- No numeric, identifier, symbol, quoted-literal, invalid-input, parser, or recovery behavior.

## Edge Cases

- `//` at EOF is a valid empty-body line comment.
- `/**/` is one empty-body block comment; `/*/**/*/` respects nesting.
- `/*/` and a lone `/*` are unterminated and still preserve every scalar.
- A stray `*/` is not trivia and returns `Nothing` for later token scanners.
- CRLF after a line comment remains one whitespace segment containing both scalars.

## Depth

DEPTH 0.56 (MEDIUM). The module hides exact trivia boundaries, nested-comment state, and the only unterminated-comment diagnostic path.

## Grill Log

- **Q:** Include the newline in line-comment trivia? **A:** No; leave CR/LF for the whitespace scanner. _Rationale:_ newline ownership stays uniform and CRLF remains exact. _Rejected:_ comment-specific newline attachment.
- **Q:** Recover from an unterminated block comment by discarding it? **A:** No; emit exact trivia and record `E0003`. _Rationale:_ recovery must progress without losing source. _Rejected:_ returning `Nothing`; fabricated closing text.
- **Q:** Use a regular expression or parser combinator? **A:** No; use the strict cursor and explicit nesting depth. _Rationale:_ nesting and exact spans require state while the hot path must remain linear. _Rejected:_ non-nesting regex; backtracking combinators.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
