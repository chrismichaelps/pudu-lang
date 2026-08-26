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
parseCapabilityAnnotation :: Parser [Located Capability]
invalidPrefix             :: Token -> Parser (Located Expression)
labelWithoutLoop          :: Token -> Parser (Located Expression)
reservedPrefix            :: Token -> Text -> Parser (Located Expression)
reservedKeywordGuidance   :: Keyword -> Maybe Text
skipToLineBoundary        :: Parser ()
invalidAtCurrent          :: Parser (Located Expression)
isRecoveryBoundary        :: TokenKind -> Bool
unaryOperators            :: [SymbolKind]
mergedOrLeft              :: Span -> Span -> Span
```

### Governance

- Recovery always makes forward progress or stops at a boundary it did not consume. `invalidPrefix`
  advances one token unless the token closes a group or ends the file, so an unrecognised expression
  start can never loop.
- `skipToLineBoundary` consumes the rest of a line and never the next line's first token. That is
  what turns `task my_task() -> Int { 42 }` into one `E1041` instead of a cascade of downstream
  errors about tokens the reader never meant as expressions.
- A reserved keyword in expression position gets a message naming the canonical form — `enum` and
  `struct` point to `type`, `task` and `spawn` point to `async` and `scope`, `mut` points to `var`.
  A generic "expected expression" would be true and useless.
- An absent capability list is not an empty one. Writing no parentheses grants every capability;
  writing `()` grants none. The two cannot share a representation, so the parser distinguishes them
  rather than normalising.
- The capability vocabulary is closed, and a name outside it is `E1044` where it was written.
- `unaryOperators` is consulted only where an operand is expected. `&` and `*` are binary operators
  too, and position is the only thing that separates the readings.

### Linkage

- **Requires:** [[Parser State]], [[Syntax Tree]], [[Token]], [[Source Text]].
- **Consumed by:** [[Parser Expression]].

## Algorithm

Direct dispatch on token kind, with one bounded consume loop for the capability list and one for
line-boundary recovery. Nothing here recurses into expression parsing, which is why it can be a
separate module at all.

## Negative Logic (Prohibited Paths)

- No expression, block, or pattern parsing — this module is what those fall back to, and depending
  on them would make the fallback part of the cycle it exists outside of.
- No unbounded consumption. Every loop stops at EOF, at a line boundary, or at an exhausted budget.

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

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Expression]] · [[grammar/pudu]]
