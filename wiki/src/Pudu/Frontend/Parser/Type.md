---
type: module
path: "@root/src/Pudu/Frontend/Parser/Type.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.68
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Type]
---

# Parser Type

- **`unsafe(raw) fn(Int) -> Int` is a type.** Without it a program could hold a function that
  requires something but never name the shape of one, so no parameter could accept it and
  higher-order code over a binding would be unwritable. Closing a hole by making the feature useless
  is not closing it.

## Purpose

Parse reference, tuple/unit, named path, and square-bracket generic type syntax without type resolution.

## Interface

### Signatures

```haskell
parseTypeSyntax :: Parser (Located TypeSyntax)
parseTypeList :: Text -> Parser [Located TypeSyntax]
```

### Governance

- `async? fn(A, B) -> T` parses as a first-class function type; the async marker and declared result are preserved so capability and recoverable failure survive into later phases.

- `&mut` is reference syntax; `mut` elsewhere is not consumed.
- `()` is unit; `(T)` groups; `(T,)`/`(T,U)` are tuples.
- Type arguments allow a trailing comma and require closing `]`.
- Empty generic arguments and invalid/missing atoms produce `InvalidType` at the recovery span with `E1020`; missing delimiters use the state-owned `E1001` expectation.
- Every recursive type/list descent consumes input and runs under the parser recursion budget.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Syntax Tree]], [[Pudu Type]].
- **Consumed by:** current [[Parser Binding]] and future declaration partitions.

## Algorithm

Parse a budgeted reference prefix, then parentheses or a named path; parse generic arguments with closed-symbol predicates and progress checks; compose location across delimiters.

## Negative Logic (Prohibited Paths)

- No generic constraints, type alias expansion, arity checking, or `&mut` ownership validation.

## Edge Cases

- Empty `[]` diagnoses exactly once; nested generics close without C++-style token ambiguity because `]` is distinct.

## Depth

DEPTH 0.68 (MEDIUM). Hides recursive type grammar and delimiter recovery behind one operation.

## Grill Log

- **Q:** Parse function types now? **A:** Not until a syntax constructor and semantic slice are complete. _Rationale:_ no parser-only surface. _Rejected:_ placeholder function-type text.
- **Q:** How is hostile nesting bounded? **A:** Charge every reference, parenthesized, and generic-list descent to `Parser State`'s shared budget. _Rationale:_ syntax depth cannot exhaust the host stack. _Rejected:_ unbounded mutual recursion.
- **Q:** Can raw text construct punctuation kinds? **A:** No; use the state-owned closed symbol predicate. _Rationale:_ punctuation remains exhaustively defined by `Token`. _Rejected:_ `Symbol Text` construction.

## Variants

- Function/array types extend this module via their vertical semantic slices.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Parser State]] · [[Parser Name]] · [[Parser Binding]] · [[Frontend]]
