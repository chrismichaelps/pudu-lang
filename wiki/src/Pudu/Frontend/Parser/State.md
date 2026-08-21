---
type: module
path: "@root/src/Pudu/Frontend/Parser/State.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.77
depth_status: DEEP
coupling: 2.0
interface_stability: 1.0
tags: [module, deep]
aliases: [Parser State]
---

# Parser State

## Purpose

Own an opaque indexed token cursor, bounded recursion/recovery budget, diagnostic accumulation, expectations, safe advancement, and `Located` construction so grammar modules contain grammar rather than state mechanics.

## Interface

### Signatures

```haskell
data ParserState
newtype Parser a = Parser (ParserState -> (a, ParserState))

instance Functor Parser
instance Applicative Parser
instance Monad Parser

initialParserState :: Source -> [Token] -> ParserState
runParser :: Source -> Parser a -> [Token] -> (a, [Diagnostic])
peekToken :: Parser Token
peekKind :: Parser TokenKind
lookaheadKind :: Int -> Parser TokenKind
isAtEnd :: Parser Bool
advanceToken :: Parser Token
matchKind :: (TokenKind -> Bool) -> Parser (Maybe Token)
matchKeyword :: Keyword -> Parser (Maybe Token)
isSymbol :: Text -> TokenKind -> Bool
matchSymbol :: Text -> Parser (Maybe Token)
expectKeyword :: Keyword -> Text -> Parser Token
expectSymbol :: Text -> Text -> Parser Token
expectIdentifier :: Text -> Parser (Located Text)
emitParseDiagnostic :: Diagnostic -> Parser ()
emitParseError :: Text -> Span -> Text -> Maybe Text -> Parser ()
currentSpan :: Parser Span
withRecursionBudget :: Parser a -> Parser (Maybe a)
isDeclarationStart :: TokenKind -> Bool
synchronizeDeclaration :: Parser ()
```

### Governance

- Constructor/state fields are internal; tokens are stored in an indexed immutable sequence for O(1) cursor access.
- Input is normalized to exactly one final EOF at the supplied source end; empty and missing-EOF lists never fabricate source identity.
- Expectations diagnose without host failure; synthetic tokens are never returned as ordinary input.
- Textual symbol requests resolve through the closed `SymbolKind` vocabulary; parser modules cannot construct symbol kinds from raw text.
- Parser-owned error construction validates opaque diagnostic codes once in this module.
- Recursion budget exhaustion emits E1099 once for the active branch.

### Linkage

- **Requires:** [[Token]], [[Diagnostic Model]], [[Syntax Located]], [[grammar/haskell]].
- **Consumed by:** current [[Parser Name]] and future parser grammar modules.

## Algorithm

Index tokens, append/truncate to one source-end EOF, clamp cursor, thread strict state, resolve textual expectations, and synchronize by advancing to declaration start/`}`/EOF with guaranteed progress.

## Negative Logic (Prohibited Paths)

- No partial indexing, global state, exception recovery, grammar-specific AST construction, or unbounded recursive descent.

## Edge Cases

- Empty/missing-EOF lists are normalized; repeated advance at EOF returns EOF without moving.

## Depth

DEPTH 0.77 (DEEP). It hides every dangerous parser invariant behind a compact grammar-facing API.

## Grill Log

- **Q:** List cursor or indexed sequence? **A:** Store a compact array/vector-like sequence; initial implementation may use `Seq` from `containers` for indexed access. _Rationale:_ avoids repeated list traversal while staying dependency-light. _Rejected:_ repeated `drop`; unsafe mutable cursor.
- **Q:** Custom parser monad acceptable? **A:** Internal only and small. _Rationale:_ state/error recovery is domain-specific and explicit. _Rejected:_ public framework abstraction.

## Variants

- Replace `Seq` with `Vector` after admitting/pinning the dependency and benchmarking.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Name]] · [[Frontend]]
