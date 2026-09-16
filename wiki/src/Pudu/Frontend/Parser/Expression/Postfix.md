---
type: module
path: "@root/src/Pudu/Frontend/Parser/Expression/Postfix.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, parser]
aliases: [Parser Expression Postfix]
---

# Parser Expression Postfix

## Purpose

Parse what may follow an operand: calls, indexing, member access, `?`, `.await`, and explicit type
arguments.

## Interface

```haskell
parsePostfix      :: ExpressionParsers -> BlockParser -> Located Expression -> Parser (Located Expression)
isPostfixStart    :: TokenKind -> Bool
callRecoverySpan  :: Located Expression -> [Located Expression] -> Span
```

### Governance

- Postfix is the tightest band in [[grammar/pudu]], so it loops on one operand until nothing more
  follows. Each step must consume a token, so an unrecognised postfix can never spin.
- **A line-initial `(` or `[` is a new statement, never a call or an index.** A newline delimits a
  statement here, so continuing across one would silently turn two statements into one call. Only
  `.`, `?`, and `.await` continue a line, which is the rule the grammar already states for
  continuations.
- **A `[` opens type arguments only when its closing bracket is followed by `(`**, and its first
  token could begin a type. That two-part test is what keeps `values[index]` from being read as a
  type application: an index is far commoner than an explicit instantiation, so the ambiguity is
  resolved toward the reading a reader almost always meant.
- `.await` is a member access on a reserved name rather than an operator, which is why it parses
  here rather than in the operator table.
- Argument iteration is bounded by required progress and by the shared nesting budget.
- `callRecoverySpan` covers the callee and every argument, so a diagnostic about a failed call
  underlines the whole call rather than the token where parsing stopped.

### Linkage

- **Requires:** [[Parser State]], [[Parser Type]], [[Parser Expression Control]] for the capability
  record, [[Parser Expression Recovery]], [[Syntax Tree]], [[Token]].
- **Consumed by:** [[Parser Expression]].

## Algorithm

Peek; if the token starts a postfix and does not begin a line, take one step and loop. A `[` first
runs the two-part type-argument test and otherwise reads an index. Calls read arguments through the
capability record's expression parser, with records reinstated inside the parentheses.

## Negative Logic (Prohibited Paths)

- No precedence decisions. Postfix binds tighter than everything, so there is nothing to compare
  against.
- No importing [[Parser Expression]].
- No continuing across a line break except for `.`, `?`, and `.await`.

## Grill Log

- **Q:** Why must a type argument's bracket be followed by `(`? **A:** Because indexing is the
  commoner reading. _Rationale:_ `values[index]` and `name[Type](x)` open identically, and without
  the second half of the test every index on a generic-looking name would be a parse error.
  _Rejected:_ a turbofish sigil; deciding by the case of the first token alone.
- **Q:** Why is a line-initial `(` not a call? **A:** Because a newline ends a statement.
  _Rationale:_ admitting it would let a statement beginning with a parenthesis silently become an
  argument list for the line above. _Rejected:_ requiring a terminator; whitespace-sensitive call
  syntax.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser Expression]] · [[grammar/pudu]]
