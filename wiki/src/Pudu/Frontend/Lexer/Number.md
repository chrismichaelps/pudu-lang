---
type: module
path: "@root/src/Pudu/Frontend/Lexer/Number.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.64
depth_status: MEDIUM
tags: [module, medium, lexer]
aliases: [Number Scanner]
---

# Number Scanner

> `{-| @Source.Lexer.Number.Module — validates textual numeric literals -}`

## Purpose

Consume one ASCII numeric candidate, preserve its exact spelling, classify integer/float shape, and recover malformed owned candidates without converting magnitude.

## Interface

```haskell
scanNumber :: LexerCursor -> Maybe LexerCursor
```

## Governance

- Only ASCII `0..9` begins a number. A non-match returns `Nothing`; every match commits a positive-width token.
- Decimal/base digit runs admit `_` only between valid digits. Bases are lowercase `0b`, `0o`, and `0x`; the post-prefix candidate consumes ASCII alphanumeric/underscore text so invalid base digits cannot silently split.
- Decimal fraction ownership begins only when `.` is followed immediately by an ASCII digit. This preserves dot/member and `1..2` range boundaries.
- `e`/`E` begins an owned exponent after a decimal integer/fraction; one optional sign is admitted, and a valid separated decimal digit run is required.
- Valid base/decimal integers emit `IntegerLiteral`; a valid fraction or exponent emits `FloatLiteral`. Payload and lexeme both retain exact source text; no host numeric conversion occurs.
- An invalid owned candidate emits `Invalid` with identical text and records one `E0004` `Error` over the complete token: `malformed numeric literal`.

## Algorithm

1. Mark the initial digit and choose prefixed-base or decimal scanning.
2. Consume maximal relevant runs with `consumeWhile`; validate separators with a strict text fold tracking digit count and whether the prior scalar was a digit.
3. For decimal input, conditionally consume fraction and exponent components while retaining a cumulative validity flag.
4. Capture once from the opening mark, emit the textual kind, and add E0004 only for invalid candidates.

## Negative Logic

- No `read`, `Int`, `Integer`, floating conversion, magnitude bound, suffix typing, leading-sign ownership, uppercase base prefix, hex float, recovery rewind, or parser policy.
- No range/dot swallowing when `.` is not followed by a decimal digit.

## Edge Cases

- `0`, `1_000`, `0b10_01`, `0o7`, `0xFF`, `1.0`, `1e9`, and `1.0E-9` are valid.
- `0x`, `0b2`, `1_`, `1__2`, `1e`, `1e+`, and `1e_2` are invalid E0004 tokens.
- `1.`, `1.foo`, `1..2`, and `1..=2` stop the integer before punctuation.
- Arbitrarily long magnitudes remain textual and linear in source length.

## Depth

DEPTH 0.64 (MEDIUM). The module owns numeric candidate boundaries, separator validation, range ambiguity, exact recovery, and diagnostic compatibility without semantic conversion.

## Grill Log

- **Q:** Convert literals while lexing? **A:** No; retain text. _Rationale:_ inference needs arbitrary-precision intent and host bounds must not reject source. _Rejected:_ `read Int`; eager floating conversion.
- **Q:** Let `1.` start a float? **A:** No; require a digit after the dot. _Rationale:_ dot/member and range punctuation must remain deterministic. _Rejected:_ scanner backtracking after consuming dot.
- **Q:** Split malformed base digits into later tokens? **A:** No; once a base prefix is owned, consume its alphanumeric candidate and emit one E0004. _Rationale:_ the earliest phase can explain the defect accurately and still advance. _Rejected:_ `0` plus identifier `xg`.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
