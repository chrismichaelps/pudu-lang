---
type: module
path: "@root/src/Pudu/Type/Value.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Value]
---

# Type Value

## Purpose

Own formed types, schemes with trait bounds, and rendering for [[Type Check]].

## Interface

### Signatures

```haskell
data Type = ... | NominalType !Text ![Type] | VariableType !TypeVar | RigidType !Text | ErrorType
data Scheme = Scheme { schemeParams :: ![Text], schemeBounds :: ![(Text, [Text])], schemeType :: !Type }
monotype :: Type -> Scheme
polytype :: [Text] -> [(Text, [Text])] -> Type -> Scheme
```

### Governance

- Nominal types are equal by declaration identity and equal arguments; tuples, functions, and references are structural, matching [[architecture/SEMANTICS]].
- `Never` unifies with every type, which is the rule it is given for unreachable control-flow joins, and the error type absorbs so one mistake never cascades.
- An absent annotation becomes a fresh inference variable rather than a default, because defaulting would decide something the reader did not write.
- A type alias expands transparently; a declared generic parameter stays rigid inside the declaration that introduced it.
- A scheme carries the trait bounds each parameter must satisfy alongside the parameter list itself, so instantiation can register obligations a call must prove. `monotype` is a scheme with no parameters and nothing to prove; `polytype` pairs parameters with their bounds.
- Diagnostics use the `E3xxx` family and name the expected type first, because that is the one the reader declared.

### Linkage

- **Requires:** [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]], [[Type Env]], [[Type Check Rule]], [[Type Check Method]], [[Type Formation]].

## Algorithm

Direct structural recursion over the type or syntax shape, with the checker's substitution consulted whenever a variable is reached.

## Negative Logic (Prohibited Paths)

- No subtyping beyond `Never`, no implicit numeric conversion, no defaulting of unsolved variables, and no evaluation.

## Edge Cases

- An occurs-check failure reports `E3002` rather than building a type that contains itself.

## Depth

DEPTH 0.4 (MEDIUM). It keeps one concern out of [[Type Check]], which the delivery rules cap at 500 lines.

## Grill Log

- **Q:** Why a separate module? **A:** Because the checking walk is already deep, and formation, unification, and state are independently testable concerns. _Rationale:_ the split follows a real seam rather than a line count alone. _Rejected:_ one large checker file.
- **Q:** Should `Scheme` carry bounds? **A:** Yes, alongside its parameters. _Rationale:_ bounds are part of what a declaration promises, and instantiation must register them as obligations; storing them on the scheme is where the checker reads them. _Rejected:_ a separate bounds table keyed by name, which would drift from the scheme it describes.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]
