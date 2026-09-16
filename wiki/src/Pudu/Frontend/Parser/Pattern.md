---
type: module
path: "@root/src/Pudu/Frontend/Parser/Pattern.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.71
depth_status: MEDIUM
coupling: 4.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Pattern]
---

# Parser Pattern

## Purpose

Parse the closed pattern vocabulary — wildcard, binding, literal, range, tuple, constructor, record, and alternation — for `match` arms, `for` binders, and `if let` conditions.

## Interface

### Signatures

```haskell
parsePattern :: Parser (Located Pattern)
```

### Governance

- The pattern start is decided by the token itself: `_` never binds, a lowercase identifier always binds, an uppercase path is a constructor even with no payload, and a literal is a literal.
- A constructor path reuses [[Parser Name]]'s segmented path with `E1011` casing, so `Core.Result.Err(e)` and `Err(e)` share one rule.
- A numeric pattern literal admits a leading `-`, preserved inside the literal's own text rather than as a unary expression node, so `-5..=5` is one range pattern.
- `..` and `..=` join two literal endpoints; a missing endpoint reports `E1050` and keeps the lower literal.
- A record pattern may end with `..`, recorded as an explicit rest flag; a field without `:` binds the field to its own name.
- Alternation with `|` is flat: one alternative is returned unwrapped, and two or more become a single `AlternativePattern`. That alternatives must bind identical names is a semantic rule, not a parsing one.
- Every recursive descent is charged to [[Parser State]]'s shared budget, and a latched budget suppresses closing-delimiter expectations so hostile nesting reports one `E1099` with no unwinding cascade.
- An unrecognized pattern start reports `E1050` once and consumes one token unless it sits on a recovery boundary (`,` `)` `]` `}` `=>` `|` `=`), which the enclosing construct owns. `=` belongs to `if let`; preserving it lets one missing pattern remain one diagnostic.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Token]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Parser Expression]] for `match` arms, `for` binders, and `if let` conditions.

## Algorithm

Parse one alternative, then fold `|`-separated alternatives; each alternative dispatches on the leading token to the wildcard, binding, literal/range, tuple, constructor, or record form, with comma-separated sub-patterns admitting one trailing comma.

## Negative Logic (Prohibited Paths)

- No exhaustiveness or reachability analysis, name resolution, type checking, binding-consistency checking across alternatives, or desugaring.

## Edge Cases

- `(only)` groups a single pattern instead of forming a one-member tuple, matching the type grammar's `(T)` rule; `(a, b,)` keeps two members.
- A constructor with no payload is distinguishable from a binding purely by case, so `None` never becomes a variable.
- Unclosed tuple, constructor, and record patterns report one `E1001` and keep what was recovered.

## Depth

DEPTH 0.71 (MEDIUM). It resolves case-driven classification, range and alternation folding, and delimiter recovery behind one total entry point.

## Grill Log

- **Q:** How is a binding distinguished from a nullary constructor? **A:** By identifier case, using the same rule [[grammar/pudu]] applies to every other name position. _Rationale:_ resolution-free classification keeps parsing independent of scope. _Rejected:_ resolving names during parsing; requiring parentheses on nullary constructors.
- **Q:** Should `-1` be a unary expression inside a pattern? **A:** No; the sign belongs to the literal's text. _Rationale:_ patterns are not expressions, and a range endpoint must stay a literal. _Rejected:_ reusing expression parsing for pattern literals.
- **Q:** How does an alternation of one alternative appear? **A:** As the alternative itself, not a one-member alternation. _Rationale:_ later phases should not special-case a wrapper that carries no information. _Rejected:_ always wrapping.

## Variants

- Slice patterns, binding `@` sub-patterns, and nested rest patterns extend this module once their semantics are resolved.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser State]] · [[Parser Name]] · [[Parser Expression]] · [[Syntax Tree]] · [[Frontend]]
