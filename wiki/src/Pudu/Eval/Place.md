---
type: module
path: "@root/src/Pudu/Eval/Place.hs"
fidelity: Active
domain: "[[Pudu Eval]]"
subsystem: "[[Evaluator]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium, evaluator, ownership]
aliases: [Eval Place]
---

# Eval Place

## Purpose

Store into places, and hand a `&mut` parameter's final value back to the place it was lent from, as
[[ADR-0022-lending-a-place]] decides.

## Interface

```haskell
data Place
data Lent = Lent { lentSelf :: Maybe Place, lentArguments :: [Maybe Place] }
noneLent :: Lent
placeOf :: (Located Expression -> Evaluator Value) -> Located Expression -> Evaluator (Maybe Place)
plainPlace :: Located Expression -> Maybe Place
readPlace :: Place -> Evaluator Value
storePlace :: Place -> Value -> Evaluator ()
withFrameKeeping :: [(Text, Value)] -> [Text] -> Evaluator a -> Evaluator (a, [Value])
exclusiveParameters :: Function -> [Int]
```

## Behaviour

- A place is its root binding and its steps: a field by name, or an element by the value its index
  evaluated to. `placeOf` evaluates each index once; `plainPlace` answers only when finding the place
  evaluates nothing.
- `readPlace` follows the steps with the same member and index reads an expression uses.
  `storePlace` rebuilds the root's value with the one field or element replaced and assigns the root
  where it was declared; an index outside an array is `E7004`.
- `withFrameKeeping` is `withFrame` that also reads the named parameters out of the frame when the
  body finishes. Because [[Eval Call]] catches `return` and `?` inside the frame, every way a body
  finishes answers them.

Resolved Grill Log: a place is re-read from its root at store time rather than held as a pointer into
a value, because values are immutable and the root is the only thing that changes.
