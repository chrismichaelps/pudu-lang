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
data Blame = AtKey | AtRoot
data Place
data Lent = Lent { lentSelf :: Maybe Place, lentArguments :: [Maybe Place] }
noneLent :: Lent
placeOf :: (Located Expression -> Evaluator Value) -> Located Expression -> Evaluator (Maybe Place)
plainPlace :: Located Expression -> Maybe Place
readPlace :: Blame -> Place -> Evaluator Value
storePlace :: Place -> Value -> Evaluator ()
storeName :: Span -> Text -> Value -> Evaluator ()
withFrameKeeping :: [(Text, Value)] -> [Text] -> Evaluator a -> Evaluator (a, [Value])
exclusiveParameters :: Function -> [Int]
```

## Behaviour

- A place is its root binding and its steps: a field by name, or an element by the value its index
  evaluated to. `placeOf` evaluates each index once; `plainPlace` answers only when finding the place
  evaluates nothing.
- An element step is `ElementStep !Span !Value`: the span of its key, then the value the key evaluated to.
- `readPlace` follows the steps with the same member and index reads an expression uses. `Blame`
  chooses where a failing element reports: `AtKey` reports at the key's span, for an element and a range alike; `AtRoot` reports at the place's span, the root name.
  `storePlace` rebuilds the root's value with the one field or element replaced and assigns the root
  where it was declared; an index outside an array is `E7004`.
- `withFrameKeeping` is `withFrame` that also reads the named parameters out of the frame when the
  body finishes. Because [[Eval Call]] catches `return` and `?` inside the frame, every way a body
  finishes answers them.

Resolved Grill Log: a place is re-read from its root at store time rather than held as a pointer into
a value, because values are immutable and the root is the only thing that changes.

## Grill Log

- **Q:** Construct a Place for every assignment to one bare name? **A:** No.
  _Rationale:_ no index or field needs evaluation there. `storeName` owns the
  existing one-pass binding update and exact missing/nonassignable diagnostics;
  both the general Place path and the tree's bare-name assignment use it.
  Nested places keep their original index-before-right-hand-side ordering.

- **Q:** Look a name up before a plain assignment to it? **A:** No. _Rationale:_ with no field or
  index step the old value is never used, so the search was wasted on every `x = value` (#423).
  The lookup happens only to name the failure when the update finds no binding.

- **Q:** Read a lent parameter's final value from a map? **A:** From a snapshot of the frame.
  _Rationale:_ a compiled body may have turned the parameter frame into a slot frame, whose values
  are read through its layout.

- **Q:** Why does a loan blame the root while a receiver blames the key? **A:** A loan names a place
  to write back into, and every write to a place reports at its root; a receiver only reads the
  element, so it reports where an element read does.

- **Q:** Does a range receiver blame the value it slices? **A:** A range chooses the stretch as a key chooses an element; both report where they were written.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Env]]

## Named sum value foundation (#761)

Rebuild named sum fields during a place write while preserving canonical owner, variant label, every other field and storage order. Static lending/mutability rules stay with the checker.

Resolved Grill Log: represent named sums independently of ordinary records and positional sums. Preserve existing field order and public labels. Source publication follows in its own tested partition. See [[Named Sum Value Delivery]].

## Element read spans (#958)

`readPlace` fails an element step at that step's key span, so an element read through a method receiver (`items[0..9].length()`, `items[9].toText()`) reports where the same element read as a value does, and where native code reports it. Writes through a place keep the root span, the failure location assignment shares with native code (#649).

Resolved Grill Log: a place recorded one span for its whole path, which blamed the root name for a bad key; each element step now keeps the span of the key it was read with.
