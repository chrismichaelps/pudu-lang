---
type: module
path: "@root/src/Pudu/Frontend/Parser/Expression/Control.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, parser]
aliases: [Parser Expression Control]
---

# Parser Expression Control

## Purpose

Parse the branching and looping expression forms — `if`, `match`, `while`, `loop`, `for`, and the
labels that name them.

## Interface

```haskell
data ExpressionParsers = ExpressionParsers
  { expressionOf :: BlockParser -> Parser (Located Expression)
  , scrutineeOf  :: BlockParser -> Parser (Located Expression)
  , expressionAt :: BlockParser -> Int -> Parser (Located Expression)
  }
parseIf       :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseMatch    :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseLabelled :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseWhile, parseLoop, parseFor
  :: ExpressionParsers -> BlockParser -> Maybe (Located Text) -> Parser (Located Expression)
```

### Governance

- **The capability record is what breaks the cycle.** Control forms contain expressions and
  expressions contain control forms, so one of the two directions has to be an argument rather than
  an import. [[Parser Expression]] hands its own entry points in, exactly as it already hands in the
  block parser, and no Haskell module cycle forms — which is what keeps the frontend free of
  `hs-boot` files.
- Two ways of reading an expression are needed, not one. A **scrutinee** refuses a record
  construction, because `if READY { ... }` would otherwise be ambiguous with the block that follows
  it; an ordinary expression admits one. The distinction is [[grammar/pudu]]'s, and it is why the
  record carries both.
- `expressionAt` exists for `else if`: the branch is parsed at the loosest precedence so a chain
  nests as one construct rather than as an expression statement followed by a stray `if`.
- A label is `@name` before the loop it names, and only a loop may carry one. A label followed by
  anything else is `E1053`, reported at the label — the part the reader deletes to make the program
  legal again.
- `match` requires at least one arm (`E1051`). A match with none is a scrutinee evaluated for
  nothing, and admitting it would make the exhaustiveness checker's job undefined.
- Arm iteration is bounded by required token progress and stops on an exhausted budget, so a hostile
  arm list neither loops nor cascades.

### Linkage

- **Requires:** [[Parser State]], [[Parser Pattern]], [[Parser Expression Recovery]],
  [[Syntax Tree]], [[Token]].
- **Consumed by:** [[Parser Expression]].

## Algorithm

Dispatch on the leading keyword, read the head through the capability the form needs — a scrutinee
for `if`, `while`, `match`, and `for`, nothing for `loop` — then a block. Labels are read before the
keyword and passed down to whichever loop follows.

## Negative Logic (Prohibited Paths)

- No importing [[Parser Expression]]. That is the cycle this module exists on the other side of.
- No typing rules. Whether a `break` may carry a value, whether branches unify, and whether a label
  names an enclosing loop are all semantic questions owned elsewhere.
- No unbounded arm or branch iteration.

## Grill Log

- **Q:** Why a record of three functions rather than passing them separately? **A:** Because they
  travel together through every form here. _Rationale:_ threading three arguments through eleven
  functions makes each signature about plumbing rather than about the form it parses. _Rejected:_
  separate parameters; a type class, which would need an instance for a thing that is not a type.
- **Q:** Why does `loop` take the record and not use it? **A:** So every loop form has one shape.
  _Rationale:_ `while` and `for` read a head and `loop` does not, and giving them different
  signatures would put that difference in the caller as well as here. _Rejected:_ a narrower
  signature for the one form that needs less.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Expression]] · [[grammar/pudu]]
