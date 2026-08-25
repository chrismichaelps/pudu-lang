---
type: module
path: "@root/src/Pudu/Frontend/Lexer/Quoted.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.68
depth_status: MEDIUM
tags: [module, medium, lexer]
aliases: [Quoted Scanner]
---

# Quoted Scanner

> `{-| @Source.Lexer.Quoted.Module — decodes bounded quoted literals -}`

## Purpose

Consume one string or character literal, preserve its exact lexeme, decode admitted escapes without host overflow, and retain malformed quoted input as one advancing token with precise diagnostics.

## Interface

```haskell
scanQuoted :: LexerCursor -> Maybe LexerCursor
```

## Governance

- A brace stays reserved inside a string so interpolation can be added later without changing what
  existing programs mean, but `\{` and `\}` escape one. Until the escape existed, no JSON, shell
  snippet, or code template could be written as a literal at all — the reservation was costing more
  than the future feature is worth.

- A brace stays reserved inside a string so interpolation can be added later without changing what
  existing programs mean, but `\{` and `\}` escape one. Until the escape existed, no JSON, shell
  snippet, or code template could be written as a literal at all — the reservation was costing more
  than the future feature is worth.

- `"` begins a string and `'` begins a character literal. A non-match returns `Nothing`; every match consumes and commits positive width.
- String escapes are `\n`, `\r`, `\t`, `\\`, `\"`, `\0`, and `\u{HEX}`. Character literals additionally admit `\'`.
- A Unicode escape contains one through six ASCII hexadecimal digits and a closing `}`. It is decoded through unbounded `Integer`, then rejected when empty, overlong, non-hexadecimal, surrogate-valued, or above U+10FFFF before conversion to `Char`.
- A valid string emits decoded `StringLiteral` text; a valid character emits one decoded-scalar `CharLiteral`. Exact source spelling remains in `tokenLexeme`.
- Raw `{` or `}` in a string is reserved interpolation syntax: the whole literal becomes `Invalid` and each raw brace records E0008 `string interpolation is reserved`.
- EOF or a raw CR/LF before the matching delimiter terminates recovery without consuming the newline. The consumed quoted segment becomes `Invalid` with E0002 `unterminated string literal` or `unterminated character literal`.
- Unknown escapes record E0005 `invalid escape sequence`; malformed Unicode escapes record E0006 `invalid Unicode escape`; a closed character payload other than exactly one scalar records E0007 `character literal must contain exactly one Unicode scalar value`.
- One primary quoted defect does not trigger a redundant character-cardinality diagnostic. Independent raw braces may each retain their own exact E0008 span.

## Algorithm

Mark the delimiter, accumulate maximal ordinary chunks, dispatch escapes and raw braces, and stop before newline/EOF. Validate `\u{...}` through `Integer`; on close, validate character cardinality and emit decoded or exact-invalid output. Unterminated recovery emits the consumed segment with E0002.

## Negative Logic

- No interpolation parsing, doubled-brace escape, multiline/raw/byte string, host-bound numeric conversion, rewind, fabricated delimiter, parser/type/ingestion, unknown-token fallback, or source loss.

## Depth

DEPTH 0.68 (MEDIUM). Owns delimiter boundaries, scalar-safe escape decoding, recovery, decoded/exact duality, and five diagnostic paths.

## Grill Log

- **Q:** Decode Unicode escapes through `Int`? **A:** No; validate syntax and range through `Integer`, then convert only a proven scalar. _Rationale:_ hostile digit runs must not overflow or wrap. _Rejected:_ `read Int`; unchecked `chr`.
- **Q:** Split malformed content after an opening quote? **A:** No; own through the matching delimiter or unterminated boundary and emit one exact invalid token. _Rationale:_ quoted context is the earliest phase with accurate ownership and must always advance. _Rejected:_ returning the opening quote to E0099; tokenizing the body independently.
- **Q:** Admit doubled braces before interpolation exists? **A:** No; reject every raw string brace with E0008 until interpolation segments and brace escapes land together. _Rationale:_ accepting provisional text would make later syntax source-incompatible. _Rejected:_ silently treating braces as ordinary text.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
