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

Own an opaque strict remaining-token cursor, bounded recursion/recovery budget, diagnostic accumulation, expectations, safe advancement, and `Located` construction so grammar modules contain grammar rather than state mechanics.

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

- Constructor/state fields are internal; current peek/advance are O(1) over a strict remaining-token list and lookahead is O(k), with grammar callers restricted to bounded `k`.
- Input is normalized to exactly one canonical final EOF at the supplied source end; a supplied EOF contributes only its trailing trivia, never foreign span/kind/lexeme data.
- Expectations diagnose without host failure; synthetic tokens are never returned as ordinary input.
- Textual symbol requests resolve through the closed `SymbolKind` vocabulary; parser modules cannot construct symbol kinds from raw text.
- Parser-owned error construction validates opaque diagnostic codes once in this module.
- Recursion budget exhaustion emits E1099 once for the active branch.

### Linkage

- **Requires:** [[Token]], [[Diagnostic Model]], [[Syntax Located]], [[grammar/haskell]].
- **Consumed by:** current [[Parser Name]] and [[Parser Type]], plus future parser grammar modules.

## Algorithm

Normalize tokens to one source-end EOF, retain the unconsumed suffix, thread strict state, resolve textual expectations, and synchronize by advancing to declaration start/`}`/EOF with guaranteed progress.

## Negative Logic (Prohibited Paths)

- No partial indexing, global state, exception recovery, grammar-specific AST construction, or unbounded recursive descent.

## Edge Cases

- Empty/missing-EOF lists are normalized; repeated advance at EOF returns EOF without moving.

## Depth

DEPTH 0.77 (DEEP). It hides every dangerous parser invariant behind a compact grammar-facing API.

## Grill Log

- **Q:** Indexed sequence or remaining-token cursor? **A:** Keep the strict remaining suffix. _Rationale:_ peek/advance are O(1), bounded lookahead is O(k), and a full parse remains linear without partial array indexing. _Rejected:_ `Seq.lookup` O(log n); repeated `drop` from the original list; unsafe mutable cursor.
- **Q:** Custom parser monad acceptable? **A:** Internal only and small. _Rationale:_ state/error recovery is domain-specific and explicit. _Rejected:_ public framework abstraction.

## Variants

- Replace the suffix with `Vector` only if profiling proves bounded lookahead dominates.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Name]] · [[Parser Type]] · [[Frontend]]
