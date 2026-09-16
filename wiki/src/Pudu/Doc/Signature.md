---
type: module
path: "@root/src/Pudu/Doc/Signature.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Doc Signature]
---

# Doc Signature

## Purpose

Give an inferred type a form that can be compared, ranked, and printed.

## Interface

### Signatures

```haskell
data SigType = SigCon !Text ![SigType] | SigVar !Text | SigRef !Bool !SigType
             | SigTuple ![SigType] | SigFun ![SigType] !SigType | SigUnit | SigNever | SigUnknown
data Signature = Signature { signatureConstraints :: ![(Text, [Text])]
                           , signatureArguments :: ![SigType], signatureResult :: !SigType }
schemeSignature :: Scheme -> Signature
alphaNormalise :: Signature -> Signature
renderSignature :: Signature -> Text
```

### Governance

- `SigType` mirrors the checker's `Type`, not the written syntax. It is a separate type for one
  reason: search needs `Ord` and a normal form, and neither belongs on the checker's own
  representation.
- `alphaNormalise` is for **comparison only**. Two signatures differing only in variable names are
  the same question to a search, but a reader must see the names the author chose, so the index
  stores the original and search normalises on the way in.
- Unresolved inference variables are rendered as `a`, `b`, `c`… in order of appearance. `_47` names
  an internal counter and tells a reader nothing. The renaming is display-only, so two signatures
  cannot become equal by being printed alike.
- A non-callable declaration has no arguments and its type as the result, so a constant and a
  nullary function are searched by one shape rather than two.
- Bounds are rendered in a trailing `where` clause. Pudu writes them inside the type-parameter
  list, but a result line has no parameter list to write them in, and a reader scanning results
  wants the arrow shape first.

### Linkage

- **Requires:** [[Type Value]].
- **Consumed by:** [[Doc Index]], [[Doc Query]], [[Doc Search]], [[Doc Json]].

## Algorithm

A structural map from `Type` to `SigType`, plus two renamings: one to canonical `%n` names for
comparison, one to letters for display.

## Negative Logic (Prohibited Paths)

- No unification, no substitution, and no instantiation: this module compares shapes, it does not
  solve them.
- No wildcard for an unresolved variable — it stays a variable, because that is what it means.
- No display-time renaming that reaches the values search compares.

## Edge Cases

- `ErrorType` becomes `SigUnknown`, which matches anything, so one bad declaration does not remove
  a whole module from search results.
- A reference to a function type is re-parenthesised when printed, since `&fn(A) -> B` would
  otherwise read as a function returning `B`.

## Depth

DEPTH 0.50 (MEDIUM). Two normal forms and one projection, each with a stated purpose.

## Grill Log

- **Q:** Should search reuse the checker's `Type` directly? **A:** No. _Rationale:_ it would need
  an `Ord` instance and a normal form that only search wants, and putting them on the checker's
  type would invite code that unifies against a search shape. _Rejected:_ deriving `Ord` for
  `Type`; comparing rendered strings, which makes the renderer part of the semantics.

## Referenced by

[[src/Pudu/Doc/_MOC]] · [[Doc Index]] · [[Doc Search]]
