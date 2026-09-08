---
type: module
path: "@root/src/Pudu/Frontend/Parser/Expression/Recovery.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.35
depth_status: SHALLOW
coupling: 2.0
interface_stability: 0.85
tags: [module, shallow, parser]
aliases: [Parser Expression Recovery]
---

# Parser Expression Recovery

## Purpose

Own what [[Parser Expression]] does when an expression cannot be read, plus the closed vocabularies
it recovers against: unsafe capabilities and unary operators.

## Interface

```haskell
data AmbiguityRecovery = PreserveStatement | RecoverOwner

parseCapabilityAnnotation :: Parser [Located Capability]
invalidPrefix             :: Token -> Parser (Located Expression)
prefixDiagnostic          :: Token -> (Text, Maybe Text)
labelWithoutLoop          :: Token -> Parser (Located Expression)
reservedPrefix            :: Token -> Text -> Parser (Located Expression)
reservedKeywordGuidance   :: Keyword -> Maybe Text
reportAmbiguousLineBreak  :: AmbiguityRecovery -> Parser ()
skipToLineBoundary        :: Parser ()
invalidAtCurrent          :: Parser (Located Expression)
isRecoveryBoundary        :: TokenKind -> Bool
unaryOperators            :: [SymbolKind]
continuesAcrossLineBreak  :: TokenKind -> Bool
isPrefixCapableBinary     :: TokenKind -> Bool
mergedOrLeft              :: Span -> Span -> Span
```

### Governance

- A token the lexer marked `Invalid` has already been diagnosed, and precisely — `"{}"` is an interpolation with no expression — so the parser adds nothing over it. Recovery still happens; only the second, vaguer message goes.

- Recovery always makes forward progress or stops at a boundary it did not consume. `invalidPrefix`
  advances one token unless the token closes a group or ends the file, so an unrecognised expression
  start can never loop.
- `skipToLineBoundary` consumes the rest of a line and never the next line's first token. That is
  what turns `task my_task() -> Int { 42 }` into one `E1041` instead of a cascade of downstream
  errors about tokens the reader never meant as expressions.
- A reserved keyword in expression position gets a message naming the canonical form — `enum` and
  `struct` point to `type`, `task` and `spawn` point to `async` and `scope`, `mut` points to `var`.
  A generic "expected expression" would be true and useless.
- When an unexpected binary operator appears in expression position without a left operand,
  diagnostics state directly that the operator requires a left-hand operand rather than dumping
  mechanical grammar First-sets (`start with a literal, name...`).
- When a colon appears after an expression inside parentheses (e.g. `(1: Type)`), diagnostics
  advise that type annotations belong on bindings (`let name: Type = value`).
- An absent capability list is not an empty one. Writing no parentheses grants every capability;
  writing `()` grants none. The two cannot share a representation, so the parser distinguishes them
  rather than normalising.
- The capability vocabulary is closed, and a name outside it is `E1044` where it was written.
- `unaryOperators` is consulted only where an operand is expected. `&` and `*` are binary operators
  too, and position is the only thing that separates the readings.
- `continuesAcrossLineBreak` derives continuation from that same closed vocabulary: a binary
  symbol continues from the next line exactly when it has no prefix reading.
- `isPrefixCapableBinary` names the three overlapping spellings, `-`, `&`, and `*`, so owner
  recovery can consume a consecutive ambiguous run without treating prefix-only `!` or `~` as a
  continuation decision.
- `reportAmbiguousLineBreak` owns `E1055` at the ambiguous operator. `PreserveStatement` explains
  that parentheses make a separate prefix statement; `RecoverOwner` instead asks the writer to
  rewrite the enclosing expression, because calls, groups, collections, conditions, match arms,
  and lambda bodies have no sibling-statement position at that boundary.

### Linkage

- **Requires:** [[Parser State]], [[Syntax Tree]], [[Token]], [[Source Text]].
- **Consumed by:** [[Parser Expression]], [[Repl Session]].

## Algorithm

Direct dispatch on token kind, with bounded consume loops for the capability list and line-boundary
recovery. Nothing here recurses into expression parsing, which is why this can remain a separate
module.

## Negative Logic (Prohibited Paths)

- No expression, block, or pattern parsing — this module is what those fall back to, and depending
  on them would make the fallback part of the cycle it exists outside of.
- No unbounded consumption. Every loop stops at EOF, at a line boundary, or at an exhausted budget.
- No mechanical dumping of grammar First-sets in diagnostics.

## Grill Log

- **Q:** Why split this out of [[Parser Expression]]? **A:** It is the part with no recursion.
  _Rationale:_ recovery, the capability vocabulary, and the unary operator list depend only on the
  token stream, so they can leave without the capability-passing that the rest of the module's
  mutual recursion would require. _Rejected:_ leaving a 1060-line module because splitting the
  recursive parts is harder.
- **Q:** Why does recovery stop at `,` `)` `]` `}` without consuming them? **A:** They belong to the
  construct that is still being parsed. _Rationale:_ consuming a closing delimiter during recovery
  leaves its opener unmatched and turns one error into two. _Rejected:_ consuming to the next
  statement.
- **Q:** Why replace generic grammar dumps with intent-aware diagnostics? **A:** Reciting internal
  First-sets (`start with a literal, name...`) is unhelpful when a developer typed a binary operator
  or tried inline type ascriptions. _Rationale:_ context-sensitive messages (`binary operator '<<' requires a left-hand expression`) point directly to the syntactic intent. _Rejected:_ keeping the generic First-set dump.
- **Q:** Why export prefixDiagnostic? **A:** The REPL session needs to diagnose orphaned leading operators before assembling candidate buffers, preventing them from accidentally fusing with prior statement lines. _Rationale:_ share the single canonical intent-aware diagnostic between parser recovery and prompt validation. _Rejected:_ duplicating prefix diagnostic strings in Repl.Session.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Expression]] · [[Repl Session]] · [[grammar/pudu]]

