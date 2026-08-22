---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Generic.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.52
depth_status: MEDIUM
coupling: 3.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Generic]
---

# Parser Generic

## Purpose

Parse the generic syntax shared by functions, type declarations, traits, and implementations: bracketed type parameters with bounds, and `where` constraint clauses.

## Interface

### Signatures

```haskell
parseTypeParams :: Parser [Located TypeParam]
parseWhereClause :: Parser [Located Constraint]
```

### Governance

- Both forms are optional everywhere they appear, so an absent `[` or `where` is never a diagnostic.
- Parameter and constraint subjects are uppercase names through [[Parser Name]]'s `E1011` rule; bounds are ordinary type references joined by `+`.
- Bound satisfaction, coherence, and the prohibition on higher-kinded or defaulted parameters are semantic rules; this module preserves spelling only.
- A `where` clause ends at the first token that cannot continue a constraint list, which is the owning construct's body, so no construct needs to pre-scan for its own `{`.
- Iteration requires token progress and stops on a latched budget, so a malformed list cannot loop or cascade.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Type]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Parser Function]], [[Parser Type Declaration]], [[Parser Trait]].

## Algorithm

For parameters, consume `[`, then parse comma-separated `Name (: Bound (+ Bound)*)?` entries with one optional trailing comma, and require `]`. For constraints, consume `where`, then parse comma-separated `Name: Bound (+ Bound)*` entries.

## Negative Logic (Prohibited Paths)

- No bound checking, variance inference, defaulted parameters, higher-kinded parameters, or duplicate-name rejection.

## Edge Cases

- `[T]` with no bounds and `where T: A + B` with several bounds are both ordinary; an empty `[]` yields no parameters and one `E1011` from the missing name.

## Depth

DEPTH 0.52 (MEDIUM). One small module keeps four declaration parsers from repeating bracket, bound, and constraint mechanics.

## Grill Log

- **Q:** Should each declaration parse its own generics? **A:** No; share one module. _Rationale:_ four copies of bound parsing would drift, and generic syntax is identical in every position. _Rejected:_ duplicating the logic per declaration module.
- **Q:** How does a `where` clause know where it ends? **A:** It stops when a constraint cannot continue. _Rationale:_ the body delimiter differs per construct (`{` for traits and impls, `{` or `=` for functions), so the clause must not hard-code it. _Rejected:_ scanning ahead for the owning construct's body token.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser Function]] · [[Parser Type Declaration]] · [[Parser Trait]] · [[Parser Type]] · [[Syntax Tree]]
