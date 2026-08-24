---
type: module
path: "@root/src/Pudu/Type/Unify.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Unify]
---

# Type Unify

## Purpose

Own making two types equal or explaining why not for [[Type Check]].

## Interface

The exported signatures are the module header's export list.

### Governance

- Nominal types are equal by declaration identity and equal arguments; tuples, functions, and references are structural, matching [[architecture/SEMANTICS]].
- `Never` unifies with every type, which is the rule it is given for unreachable control-flow joins, and the error type absorbs so one mistake never cascades.
- An absent annotation becomes a fresh inference variable rather than a default, because defaulting would decide something the reader did not write.
- A type alias expands transparently; a declared generic parameter stays rigid inside the declaration that introduced it.
- Diagnostics use the `E3xxx` family and name the expected type first, because that is the one the reader declared.
- When two unequal nominal identities render with the same short name, the mismatch qualifies both with their declaring modules so the diagnostic never says only `expected Hidden, found Hidden`.

### Linkage

- **Requires:** [[Type Value]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]].

## Algorithm

Direct structural recursion over the type or syntax shape, with the checker's substitution consulted whenever a variable is reached.

## Negative Logic (Prohibited Paths)

- No subtyping beyond `Never`, no implicit numeric conversion, no trait resolution, no defaulting of unsolved variables, and no evaluation.

## Edge Cases

- An occurs-check failure reports `E3002` rather than building a type that contains itself.
- Same-basename private types from different modules report their canonical qualified keys in `E3001` while ordinary diagnostics retain concise type spelling.

## Depth

DEPTH 0.6 (MEDIUM). It keeps one concern out of [[Type Check]], which the delivery rules cap at 500 lines.

## Grill Log

- **Q:** Why a separate module? **A:** Because the checking walk is already deep, and formation, unification, and state are independently testable concerns. _Rationale:_ the split follows a real seam rather than a line count alone. _Rejected:_ one large checker file.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
