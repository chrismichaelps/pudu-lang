---
type: module
path: "@root/src/Pudu/Frontend/Lexer/Symbol.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
tags: [module, medium, lexer]
aliases: [Symbol Scanner]
---

# Symbol Scanner

> `{-| @Source.Lexer.Symbol.Module — matches closed punctuation deterministically -}`

## Purpose

Emit one admitted [[Token]] symbol using bounded longest-prefix matching over the closed vocabulary.

## Interface

```haskell
scanSymbol :: LexerCursor -> Maybe LexerCursor
```

## Governance

- Candidates derive from every bounded `SymbolKind` and its exhaustive `symbolText`; no second spelling table exists.
- Candidates are grouped by first character and ordered by descending scalar length once, in a
  constant table. The first exact prefix within the group wins, so `..=`, `..`, `.`, `->`, `==`,
  and related prefixes are deterministic, and a symbol is decided against the two or three spellings
  sharing its first character rather than all of them.
- A non-match returns `Nothing`; a match consumes exactly its spelling and emits `Symbol` through the opening mark.

## Algorithm

1. Search the bounded longest-first immutable candidate list with `cursorStartsWith`.
2. Consume the matched spelling length and emit its constructor.

## Negative Logic

- No free-form punctuation, fallback invalid token, parser context, backtracking, duplicated mapping table, or trie before measurement.

## Edge Cases

- `..=` wins over `..` and `.`; `==` wins over `=`; `->` wins over `-`.
- `_`, `;`, backslash, and unknown punctuation do not match.
- Every closed symbol constructor round-trips through this scanner.

## Depth

DEPTH 0.45 (MEDIUM). The module is small but centralizes the parser-visible longest-match law over one closed vocabulary.

## Grill Log

- **Q:** Handwrite a prefix decision tree? **A:** No; derive a bounded longest-first list from `SymbolKind`. _Rationale:_ constructor additions remain exhaustive and vocabulary size is fixed. _Rejected:_ duplicated branch spellings; premature trie.
- **Q:** Emit invalid punctuation here? **A:** No; the total facade owns fallback recovery. _Rationale:_ this scanner recognizes one category only. _Rejected:_ category-order coupling.

## Referenced by

[[src/Pudu/Frontend/Lexer/_MOC]] · [[Frontend]]
