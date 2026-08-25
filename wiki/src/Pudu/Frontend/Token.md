---
type: module
path: "@root/src/Pudu/Frontend/Token.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.58
depth_status: MEDIUM
coupling: 1.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Token]
---

# Token

> `{-| @Source.Token.Module — classifies lossless lexical units -}`

## Purpose

Define the closed keyword, symbol, token-kind, and trivia vocabulary shared by the [[Frontend]], while preserving exact source spelling and locations for parsing, recovery, and tooling.

## Interface

### Signatures

```haskell
data Keyword
  = KwModule | KwImport | KwExport | KwAs
  | KwLet | KwVar | KwConst | KwMut
  | KwFn | KwAsync | KwReturn
  | KwIf | KwElse | KwMatch | KwCase
  | KwFor | KwIn | KwWhile | KwLoop | KwBreak | KwContinue
  | KwType | KwEnum | KwStruct | KwTrait | KwImpl | KwWhere
  | KwAwait | KwTask | KwSpawn | KwComptime | KwMacro
  | KwTrue | KwFalse | KwNull | KwUnsafe | KwWith | KwScope
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data SymbolKind
  = SymLeftParen | SymRightParen
  | SymLeftBracket | SymRightBracket
  | SymLeftBrace | SymRightBrace
  | SymComma | SymDot | SymColon | SymPipe
  | SymAssign | SymFatArrow | SymThinArrow | SymQuestion
  | SymBang | SymMinus | SymAmpersand | SymStar | SymSlash | SymPercent | SymPlus
  | SymWrapMultiply | SymSaturatingMultiply
  | SymWrapAdd | SymWrapSubtract | SymSaturatingAdd | SymSaturatingSubtract
  | SymRangeExclusive | SymRangeInclusive
  | SymLeftShift | SymRightShift | SymCaret | SymTilde | SymAt
  | SymLess | SymLessEqual | SymGreater | SymGreaterEqual
  | SymEqual | SymNotEqual | SymLogicalAnd | SymLogicalOr
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data TokenKind
  = Identifier !Text
  | IntegerLiteral !Text
  | FloatLiteral !Text
  | StringLiteral !Text
  | CharLiteral !Char
  | Keyword !Keyword
  | Symbol !SymbolKind
  | EndOfFile
  | Invalid !Text
  deriving stock (Eq, Ord, Show)

data TriviaKind = Whitespace | LineComment | BlockComment
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data Trivia = Trivia
  { triviaKind :: !TriviaKind
  , triviaText :: !Text
  , triviaSpan :: !Span
  }
  deriving stock (Eq, Show)

data Token = Token
  { tokenKind :: !TokenKind
  , tokenLexeme :: !Text
  , tokenSpan :: !Span
  , tokenLeadingTrivia :: ![Trivia]
  }
  deriving stock (Eq, Show)

keywordFromText :: Text -> Maybe Keyword
keywordText :: Keyword -> Text
symbolFromText :: Text -> Maybe SymbolKind
symbolText :: SymbolKind -> Text
```

### Governance

- `Keyword` exactly matches the reserved ASCII words in [[grammar/pudu]]; matching is case-sensitive and performs no normalization.
- `SymbolKind` exactly matches punctuation and operators admitted by the v0.1 grammar. Unknown punctuation is not a symbol and is handled later as invalid input.
- Literal payloads preserve decoded or category-specific data only where later scanners define it; `tokenLexeme` always preserves exact source spelling.
- Trivia text and spans are lossless. Leading trivia belongs to the following token; the later cursor makes EOF own final trailing trivia.
- Data constructors are phase-owned and exported for efficient exhaustive parser/scanner matching. Relational source/span invariants are centralized by the later cursor rather than duplicated in shallow token constructors.
- Keyword and symbol reverse lookup uses one bounded, immutable vocabulary. Adding a constructor forces an exhaustive text mapping and a round-trip test.

### Linkage

- **Requires:** [[Source]], [[Source Text]], [[Frontend]], [[grammar/pudu]], [[grammar/haskell]].
- **Consumed by:** the dependency-ordered lexer modules, [[Parser State]], [[Parser Expression]], [[Parser Import]], and later parser/tooling work inside [[Frontend]].

## Algorithm

1. Map each closed keyword constructor to one exact lowercase ASCII spelling.
2. Map each closed symbol constructor to one exact operator or delimiter spelling.
3. Build bounded reverse lookups from the exhaustive constructor ranges; unknown or case-changed text returns `Nothing`.
4. Carry semantic category/payload, exact lexeme, snapshot-safe span, and ordered leading trivia as separate fields.

## Negative Logic (Prohibited Paths)

- No free-form textual symbol accepted as a valid `Symbol` token.
- No keyword case folding, Unicode normalization, prefix matching, or contextual reclassification.
- No discarded lexeme/trivia text and no consumer source slicing when the exact text is already carried.
- No parser recovery policy, scanning behavior, diagnostics, numeric conversion, or string decoding in this module.
- No partial table indexing or fallback empty spelling for an admitted constructor.

## Edge Cases

- `with` and `scope` are reserved for structured concurrency and round-trip like every other keyword.
- `Module`, `WITH`, empty text, prefixes, and whitespace-padded text are not keywords.
- Ambiguous symbol prefixes remain distinct exact values: `.`, `..`, `..=`, `-`, `->`, `=`, `==`, `<`, `<<`, `<=`, `>`, `>>`, and `>=`. The longest-match scanner in [[Lexer Symbol]] resolves `<` vs `<<` and `>` vs `>>` by consuming the longer spelling first.
- `_` is not punctuation; the identifier scanner owns wildcard/underscore classification.
- Semicolon is not canonical Pudu syntax and is not admitted as a symbol.
- `Invalid` retains rejected text so later recovery can always advance without losing source fidelity.

## Depth

DEPTH 0.58 (MEDIUM). A compact closed interface centralizes the language's lexical vocabulary and lossless representation. Deleting it would scatter keyword/operator spellings and trivia ownership across scanners, parser, and formatter.

## Grill Log

- **Q:** Textual symbols or one constructor per admitted symbol? **A:** Use closed `SymbolKind` constructors. _Rationale:_ the v0.1 grammar is fixed, exhaustive matching prevents parser spelling drift, and compact constructors avoid repeated text comparison after lexing. _Rejected:_ free-form `Symbol Text`; dozens of unrelated `TokenKind` constructors with no symbol subdomain.
- **Q:** Duplicate mapping tables for both directions? **A:** Make constructor-to-text exhaustive and derive bounded reverse lookup from the constructor range. _Rationale:_ a new constructor cannot silently acquire an empty spelling, and properties prove uniqueness/round-trip. _Rejected:_ two independently maintained maps; partial array indexing.
- **Q:** Normalize literal payloads here? **A:** No; category scanners own decoding rules while exact lexemes remain mandatory. _Rationale:_ the token model must not invent scanner semantics. _Rejected:_ eager host numeric conversion; lexeme-only literals that force rescanning.
- **Q:** Hide token/trivia constructors? **A:** No at this internal compiler phase boundary. _Rationale:_ scanners and parser require exhaustive, allocation-minimal construction/matching; the cursor owns cross-field source invariants. _Rejected:_ shallow smart constructors that cannot validate text against an opaque span.
- **Q:** Leading or trailing trivia? **A:** Leading trivia, with EOF owning final trivia. _Rationale:_ formatting and insertion attach comments predictably to the next construct while preserving complete reconstruction. _Rejected:_ mixed attachment heuristics; discarded trivia.

## Variants

- A later compact tag representation may replace constructor storage only after lexer/parser allocation benchmarks demonstrate value; the public semantics and exact mappings remain unchanged.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Source]] · [[Parser State]] · [[Parser Expression]] · [[Parser Import]] · [[Parser Binding]] · [[Frontend]]
