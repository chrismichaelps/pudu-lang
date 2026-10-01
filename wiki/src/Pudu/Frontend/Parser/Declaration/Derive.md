---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Derive.md"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, medium]
aliases: [Parser Derive Declaration]
---

# Parser Derive Declaration

## Purpose

Parse attribute lists, trailing `derives` clauses, `derive` definitions, and
standalone `derive impl` requests. `derive` and `derives` stay contextual
identifiers: each is special only where the grammar puts it.

## Interface

### Signatures

```haskell
parseAttributes :: Parser [Located Attribute]
parseDeriveDeclaration :: Visibility -> Parser (Located Declaration)
parseDerivesClause :: Parser (Maybe (Span, [Located TypeSyntax]))
peekDerivesClause :: Parser Bool
matchDeriveWord :: Text -> Parser Bool
```

### Governance

- Attributes are `@name` or `@name(literal, ...)` with inert literals only:
  integers, decimals, strings, chars, `true`, `false`, and `null`. Anything
  else is `E1067`, because only a literal stays data without evaluation.
- A `derives` entry is a trait path starting uppercase. A missing entry is
  `E1065`; naming a trait twice is `E1066`. Both entries are kept, so the
  tree says what was written and the diagnostic names the repetition.
- `peekDerivesClause` requires a trait-shaped follower: `| derives` at the
  end of a sum is a lowercase variant, and the variant parser reports it.
- `derive Trait for Param: Shape { ... }` takes `Record` or `Sum`; anything
  else is `E1068` and the token is consumed so the body still parses once.
- `derive impl Trait for Target` reuses the `impl` and `for` keywords, which
  are only special here because `derive` opened the declaration.
- The declaration span covers the `derives` clause, so later phases point at
  the whole opt-in rather than at the type alone.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Type]],
  [[Parser Trait]] (member grammar), [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Parser Declaration]], [[Parser Type Declaration]].

## Algorithm

Attributes loop on `@`; arguments loop on literals with comma handling and a
single `E1067` per offending token. The derives clause matches its word, then
loops trait paths with duplicate detection and progress guards. A derive
definition reads trait, `for`, parameter, shape, and member functions;
a request reads `impl`, trait, `for`, and target. Every loop visits each token
once with required progress and stops on budget exhaustion, so hostile input
costs linear time and reports one `E1099` rather than a diagnostic per token.

## Negative Logic (Prohibited Paths)

- No keyword reservation for `derive`/`derives`; no visibility, resolution,
  or coherence semantics; no member checking (derive checking owns it).

## Edge Cases

- `derives` with no entries reports `E1065` without consuming, so the
  surrounding recovery owns the position that follows.
- A trailing comma ends the entry list silently; the closer belongs to the
  enclosing construct.
- An empty derive body parses with no members rather than a diagnostic.

## Grill Log

- **Q:** Reserve `derive`/`derives` as keywords? **A:** No; contextual words.
  _Rationale:_ both already name values in programs, and each is only special
  where the grammar puts it — a declaration start and a definition end — so
  reserving them renames working code for no diagnostic gain. _Rejected:_
  new keywords; overloading the words in expression position.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser Declaration]] · [[Parser Type Declaration]] · [[Derive Design]]
