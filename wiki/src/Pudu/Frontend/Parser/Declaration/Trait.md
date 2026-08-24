---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Trait.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 5.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Trait]
---

# Parser Trait

## Purpose

Parse `trait` contracts and `impl` blocks, both of which contain only function members.

## Interface

### Signatures

```haskell
parseTrait :: Visibility -> Parser (Located Declaration)
parseImpl :: Parser (Located Declaration)
```

### Governance

- A trait member is a function whose body is optional: a bodiless member declares required behavior, and a member with a body supplies a default implementation. An `impl` function always requires a body.
- Both forms share [[Parser Function]]'s single signature parser, so parameters, defaults, return types, and generics cannot drift between a declaration and its implementation.
- Traits declare behavior without stored state, so a non-function member reports `E1052` once and recovery skips to the next `fn` or the closing brace rather than diagnosing every token it contains.
- `impl` has no visibility of its own: an implementation is as public as the trait and type it connects, which is a semantic rule rather than a syntactic marker.
- Coherence is deliberately not parser work: [[Type Check Coherence]] enforces module ownership and exact duplicate heads, while general unification overlap remains a later resolved-type rule.
- Generic parameters and `where` clauses come from [[Parser Generic]] in both forms.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Type]], [[Parser Generic]], [[Parser Function]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Parser Declaration]].

## Algorithm

For a trait, consume `trait`, the uppercase name, optional generics and `where`, then members until `}`. For an implementation, consume `impl`, optional generics, the trait reference, `for`, the target reference, optional `where`, then functions until `}`.

## Negative Logic (Prohibited Paths)

- No coherence checking in the parser; the typing phase owns orphan and duplicate-head diagnostics. No default-method resolution, associated types or constants, dynamic-dispatch forms, or stored state in traits.

## Edge Cases

- An empty trait or implementation body is syntactically valid and yields no members.
- A member list that ends without `}` reports one `E1001` and keeps the members already recovered.

## Depth

DEPTH 0.60 (MEDIUM). Two related declaration forms share one member loop, one recovery rule, and one function-signature parser.

## Grill Log

- **Q:** Should trait members use a separate signature parser? **A:** No; reuse [[Parser Function]] with an optional body. _Rationale:_ a trait signature and its implementation must accept exactly the same syntax or the two would drift. _Rejected:_ a dedicated signature grammar.
- **Q:** Does `impl` carry `export`? **A:** No. _Rationale:_ visibility follows the trait and the implementing type; a separate marker would let syntax claim reach that resolution does not grant. _Rejected:_ an exported-impl form.
- **Q:** How does a non-function member recover? **A:** One `E1052`, then skip to the next `fn` or `}`. _Rationale:_ a `let` inside a trait would otherwise emit a diagnostic per token. _Rejected:_ per-token recovery; skipping the whole trait body.

## Variants

- Associated types, associated constants, and trait-object forms extend both entry points once [[architecture/SEMANTICS]] admits them.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser Declaration]] · [[Parser Function]] · [[Parser Generic]] · [[Syntax Tree]]
