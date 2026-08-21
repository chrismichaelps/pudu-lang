---
type: module
path: "@root/src/Pudu/Frontend/Lexer/Identifier.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.49
depth_status: MEDIUM
tags: [module, medium, lexer]
aliases: [Identifier Scanner]
---

# Identifier Scanner

> `{-| @Source.Lexer.Identifier.Module — classifies Unicode names and keywords -}`

## Purpose

Consume one maximal Pudu identifier and classify an exact reserved word as `Keyword` without normalization.

## Interface

```haskell
scanIdentifier :: LexerCursor -> Maybe LexerCursor
```

## Governance

- A start scalar is `_` or Unicode `Letter` under the locked `base` classification.
- Continuation scalars are `_`, Unicode `Letter`, or exactly general category `DecimalNumber`; other numeric categories and combining marks are not admitted in v0.1.
- The scanner consumes one maximal identifier with `consumeWhile` after its validated start.
- Exact case-sensitive `keywordFromText` success emits `Keyword`; every other admitted name emits `Identifier` carrying the exact lexeme.
- `_` is an identifier token here; wildcard meaning belongs to the parser.

## Algorithm

1. Reject without mutation when `peekScalar` is not an identifier start.
2. Mark, consume the maximal continuation prefix, and capture exact text.
3. Classify through the closed keyword table, then emit the token through the same mark.

## Negative Logic

- No ASCII-only digit predicate, case folding, Unicode normalization, contextual keyword rules, constant/type casing validation, interning, or parser policy.
- No numeric, trivia, symbol, quoted-literal, or invalid-character scanning.

## Edge Cases

- `_`, `_2`, `é2`, `变量٣`, and astral Unicode letters are identifiers when their scalar categories match.
- `module` is a keyword; `Module`, `module2`, and non-ASCII lookalikes are identifiers.
- A combining mark terminates an identifier under the deliberate v0.1 rule.
- A decimal digit cannot start an identifier even when it may continue one.

## Depth

DEPTH 0.49 (MEDIUM). The module centralizes Unicode category boundaries and closed keyword classification while leaving naming policy to later phases.

## Grill Log

- **Q:** Use `isAlphaNum` for continuation? **A:** No; admit `Letter` plus exactly `DecimalNumber`. _Rationale:_ `isAlphaNum` accepts numeric categories broader than the grammar. _Rejected:_ ASCII digits only; all Unicode numbers.
- **Q:** Normalize identifiers before keyword lookup? **A:** No. _Rationale:_ the grammar promises exact source identity and no normalization policy exists. _Rejected:_ NFC/NFKC or case-folded keywords.
- **Q:** Treat `_` as a special token? **A:** No; emit an identifier and let pattern parsing assign wildcard meaning. _Rationale:_ lexical shape is context-free. _Rejected:_ parser-context lexer modes.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
