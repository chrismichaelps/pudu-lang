---
type: module
path: "@root/src/Pudu/Frontend/Parser/Expression/Aggregate.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, parser]
aliases: [Parser Expression Aggregate]
---

# Parser Expression Aggregate

## Purpose

Parse the forms that name or build a value: references, record constructions, macro calls, literals,
parenthesised groups, tuples, and arrays.

## Interface

```haskell
literal           :: Token -> Literal -> Parser (Located Expression)
blockExpression   :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseNameOrRecord :: ExpressionParsers -> BlockParser -> Token -> Text -> Parser (Located Expression)
parseGrouped      :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
parseArrayLiteral :: ExpressionParsers -> BlockParser -> Parser (Located Expression)
```

### Governance

- **An uppercase name followed by `{` is a record**, and only where records are admitted. `if READY
  { ... }` is the case that makes the admission a state rather than a rule: the condition withholds
  records so the brace reads as the block it is, and any bracketed context inside reinstates them.
- Deciding a record construction needs lookahead past the brace, not just at it. `recordFollows`
  walks to the matching close so a `{` that opens a block is never mistaken for one that opens a
  field list.
- A parenthesised expression groups; adding a comma makes it a tuple, and `(e,)` is the one-member
  tuple. This mirrors the type grammar exactly, where `(T)` groups and `(T,)` is a tuple, so a reader
  never has to hold two rules for one shape.
- Element and field iteration is bounded by required token progress and stops on an exhausted
  budget, so a hostile literal neither loops nor cascades.
- A trailing comma closes a list rather than admitting an empty element.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Expression Control]] for the capability
  record, [[Parser Expression Recovery]], [[Syntax Tree]], [[Token]].
- **Consumed by:** [[Parser Expression]].

## Algorithm

Dispatch on the leading token. A name checks for a following `{` or `!` before committing to a plain
reference; a `(` reads a group and promotes it to a tuple on the first top-level comma; a `[` reads
elements until the closing bracket. Every list is read through the capability record's expression
parser.

## Negative Logic (Prohibited Paths)

- No typing, and no deciding whether a named record exists — an unknown type is a semantic error
  reported with the fields the reader wrote, not a parse failure that discards them.
- No importing [[Parser Expression]]; the capability record is the path back.
- No unbounded element iteration.

## Grill Log

- **Q:** Why does record admission travel in parser state rather than as an argument? **A:** Because
  it is a property of the position, not of the call. _Rationale:_ every bracketed context inside a
  withheld region reinstates it, and threading that through each nested parse would put the rule in
  a dozen signatures instead of one. _Rejected:_ an argument; a distinct scrutinee grammar.
- **Q:** Why look past the brace to decide a record? **A:** Because `{` alone does not distinguish
  them. _Rationale:_ `Name { x: 1 }` and `Name { statement }` differ only in what follows, and
  guessing from the brace alone would misparse one of the two. _Rejected:_ requiring a sigil on
  record construction.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Expression]] · [[grammar/pudu]]
