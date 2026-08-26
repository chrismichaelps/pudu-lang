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
peekStartsLine :: Parser Bool
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
budgetExhausted :: Parser Bool
recordsAdmitted :: Parser Bool
withRecordAdmission :: Bool -> Parser a -> Parser a
isDeclarationStart :: TokenKind -> Bool
synchronizeDeclaration :: Parser ()
```

### Governance

- `BlockParser` is the capability of reading a brace-delimited block, and it lives here rather than with any one participant. Blocks, expressions, and declarations are mutually recursive, and a shared capability that lived in one of them would put that one in every cycle it exists to break.

- No parse diagnostic is emitted once the nesting budget is exhausted. The parse has given up by then, and every message after describes the wreckage rather than the mistake — without it, one hostile file was amplified into thousands of diagnostics as recovery unwound past each unmatched delimiter.

- Input that ends before a construct is closed reports `E1000`, not `E1001`. A file that ran out is a different mistake from a wrong token, and `expected }` against the last line tells the reader nothing about which brace.
- `diagnosticCount` lets a recovery rule that only makes sense on otherwise-clean input stay quiet once something has already gone wrong.

- Constructor/state fields are internal; current peek/advance are O(1) over a strict remaining-token list and lookahead is O(k), with grammar callers restricted to bounded `k`.
- Input is normalized to exactly one canonical final EOF at the supplied source end; a supplied EOF contributes only its trailing trivia, never foreign span/kind/lexeme data.
- Expectations diagnose without host failure; synthetic tokens are never returned as ordinary input.
- Textual symbol requests resolve through the closed `SymbolKind` vocabulary; parser modules cannot construct symbol kinds from raw text.
- Parser-owned error construction validates opaque diagnostic codes once in this module.
- Recursion budget exhaustion emits E1099 exactly once per parse and latches; `budgetExhausted` exposes that latch so grammar loops stop instead of re-descending into the same hostile nesting.
- `recordsAdmitted` reports whether a record construction may start at the cursor. The flag is withheld only for the expression that precedes a block and is restored on exit, so the grammar decides ambiguity by position rather than by lookahead.
- `peekStartsLine` reports whether the current token is preceded by a line terminator in its own leading trivia. Line significance is answered from preserved trivia only; no terminator token is synthesized, so [[Lexer Facade]] losslessness and the token vocabulary stay unchanged.

### Linkage

- **Requires:** [[Token]], [[Diagnostic Model]], [[Syntax Located]], [[grammar/haskell]].
- **Consumed by:** current [[Parser Name]], [[Parser Type]], [[Parser Expression]], and [[Parser Import]], plus future parser grammar modules.

## Algorithm

Normalize tokens to one source-end EOF, retain the unconsumed suffix, thread strict state, resolve textual expectations, and synchronize by advancing to declaration start/`}`/EOF with guaranteed progress.

## Negative Logic (Prohibited Paths)

- No partial indexing, global state, exception recovery, grammar-specific AST construction, unbounded recursive descent, or synthesized terminator tokens.

## Edge Cases

- Empty/missing-EOF lists are normalized; repeated advance at EOF returns EOF without moving.

## Depth

DEPTH 0.77 (DEEP). It hides every dangerous parser invariant behind a compact grammar-facing API.

## Grill Log

- **Q:** Indexed sequence or remaining-token cursor? **A:** Keep the strict remaining suffix. _Rationale:_ peek/advance are O(1), bounded lookahead is O(k), and a full parse remains linear without partial array indexing. _Rejected:_ `Seq.lookup` O(log n); repeated `drop` from the original list; unsafe mutable cursor.
- **Q:** Why latch budget exhaustion instead of emitting per exhausted branch? **A:** Keep one E1099 for the whole parse and let loops query the latch. _Rationale:_ the budget is restored while unwinding, so an iterating grammar such as [[Parser Block]] would otherwise re-enter the same depth and produce an E1099/E1001 pair per repetition. _Rejected:_ per-branch diagnostics with later deduplication, which still leaves the delimiter cascade; abandoning the parse, which loses recovered declarations.
- **Q:** How do newline-delimited statements reach the grammar? **A:** Expose one `peekStartsLine` query over the current token's preserved leading trivia. _Rationale:_ [[grammar/pudu]] delimits statements by line breaks, and trivia already carries the exact text, so grammar modules decide continuation without a lexer change. _Rejected:_ inserting virtual terminator tokens, which breaks lossless reconstruction; re-reading the source text during parsing.
- **Q:** Custom parser monad acceptable? **A:** Internal only and small. _Rationale:_ state/error recovery is domain-specific and explicit. _Rejected:_ public framework abstraction.

## Variants

- Replace the suffix with `Vector` only if profiling proves bounded lookahead dominates.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Name]] · [[Parser Type]] · [[Parser Expression]] · [[Parser Import]] · [[Parser Binding]] · [[Frontend]]
