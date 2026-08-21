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

- `"` begins a string and `'` begins a character literal. A non-match returns `Nothing`; every match consumes and commits positive width.
- String escapes are `\n`, `\r`, `\t`, `\\`, `\"`, `\0`, and `\u{HEX}`. Character literals additionally admit `\'`.
- A Unicode escape contains one through six ASCII hexadecimal digits and a closing `}`. It is decoded through unbounded `Integer`, then rejected when empty, overlong, non-hexadecimal, surrogate-valued, or above U+10FFFF before conversion to `Char`.
- A valid string emits decoded `StringLiteral` text; a valid character emits one decoded-scalar `CharLiteral`. Exact source spelling remains in `tokenLexeme`.
- Raw `{` or `}` in a string is reserved interpolation syntax: the whole literal becomes `Invalid` and each raw brace records E0008 `string interpolation is reserved`.
- EOF or a raw CR/LF before the matching delimiter terminates recovery without consuming the newline. The consumed quoted segment becomes `Invalid` with E0002 `unterminated string literal` or `unterminated character literal`.
- Unknown escapes record E0005 `invalid escape sequence`; malformed Unicode escapes record E0006 `invalid Unicode escape`; a closed character payload other than exactly one scalar records E0007 `character literal must contain exactly one Unicode scalar value`.
- One primary quoted defect does not trigger a redundant character-cardinality diagnostic. Independent raw braces may each retain their own exact E0008 span.

## Algorithm

1. Mark and consume the opening delimiter, then traverse through the strict cursor with a reversed decoded-scalar accumulator.
2. Consume ordinary scalar runs one scalar at a time, dispatch escapes at `\\`, reject raw string braces, and stop before newline or at EOF.
3. For `\u{...}`, consume the bounded escape candidate, validate digit syntax and scalar range using `Integer`, and convert only a proven scalar value.
4. On a closing delimiter, validate character cardinality when no earlier defect exists, emit the decoded kind or exact `Invalid`, and attach diagnostics already derived from snapshot-bound submarks.
5. On unterminated input, emit the complete consumed segment and record E0002 over that exact segment.

## Negative Logic

- No interpolation parsing, doubled-brace escape, multiline literal, byte string, raw-string delimiter, numeric host-bound conversion, scanner rewind, fabricated closing delimiter, or source-text loss.
- No parser, type, encoding-ingestion, or unknown-token fallback behavior.

## Edge Cases

- `""`, `"a\\nb"`, `"\\u{1F4A1}"`, `'x'`, `'\\n'`, `'\\''`, and `'\\u{10FFFF}'` are valid.
- `"\\q"` and `'\\q'` are E0005 invalid tokens.
- `"\\u{}"`, `"\\u{1234567}"`, `"\\u{D800}"`, `"\\u{110000}"`, and `"\\u{12G}"` are E0006 invalid tokens.
- `''` and `'ab'` are E0007 invalid tokens.
- `"a{b"` and `"a}b"` are E0008 invalid tokens.
- `"abc`, `'x`, and either form before CR/LF are E0002 invalid tokens; the newline remains for trivia scanning.

## Depth

DEPTH 0.68 (MEDIUM). The module hides delimiter ownership, escape decoding, scalar-range validation, bounded recovery, decoded/exact duality, and five diagnostic paths behind one scanner entry point.

## Grill Log

- **Q:** Decode Unicode escapes through `Int`? **A:** No; validate syntax and range through `Integer`, then convert only a proven scalar. _Rationale:_ hostile digit runs must not overflow or wrap. _Rejected:_ `read Int`; unchecked `chr`.
- **Q:** Split malformed content after an opening quote? **A:** No; own through the matching delimiter or unterminated boundary and emit one exact invalid token. _Rationale:_ quoted context is the earliest phase with accurate ownership and must always advance. _Rejected:_ returning the opening quote to E0099; tokenizing the body independently.
- **Q:** Admit doubled braces before interpolation exists? **A:** No; reject every raw string brace with E0008 until interpolation segments and brace escapes land together. _Rationale:_ accepting provisional text would make later syntax source-incompatible. _Rejected:_ silently treating braces as ordinary text.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
