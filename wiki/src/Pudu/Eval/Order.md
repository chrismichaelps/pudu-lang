---
type: module
path: "@root/src/Pudu/Eval/Order.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 1.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Eval Order]
---

# Eval Order

## Purpose

Say which values may be keys. The order those keys are held in lives with [[Eval Value]], and is
re-exported here so a caller asking about keys has one place to ask.

## Interface

### Signatures

```haskell
comparableValue :: Value -> Bool
-- re-exported from [[Eval Value]], which declares them:
newtype OrdValue = OrdValue {unOrdValue :: Value}
compareValues :: Value -> Value -> Ordering
```

### Governance

- The runtime's `Value` deliberately has no `Ord` instance. A function is a value, and no order on
  functions is meaningful; deriving one would let a map silently accept a key it cannot compare.
  Wrapping the values that can be ordered keeps the distinction visible at every use.
- `OrdValue` and the order itself are **declared in [[Eval Value]]**, because `MapValue` and
  `SetValue` are keyed by that order and the type cannot be declared without it. Placing the
  instance here instead would make it an orphan, which [[grammar/haskell]] prohibits. This module
  keeps the separate question the evaluator actually asks before an insertion: not how two keys
  compare, but whether this value may be asked at all.
- Values of **different shapes** are ordered by shape, so one map may hold keys of more than one type
  without the comparison becoming partial.
- Two values that cannot be ordered compare equal. That is not a claim that they are: it keeps the
  order total so a malformed key cannot make the structure inconsistent. The caller is refused the
  insertion with `E7008` before it ever reaches here.
- Records compare field by field in **declaration order**, which is the order the reader wrote and
  therefore the one they can predict.

### Linkage

- **Requires:** [[Eval Value]].
- **Consumed by:** [[Eval Keyed]], [[Evaluator]].

## Algorithm

Structural recursion over the shapes a key may take. The comparison it defers to, and the shape rank
that comparison falls back on, are [[Eval Value]]'s.

## Negative Logic (Prohibited Paths)

- No derived `Ord` on `Value`, which would make an unorderable key a silent success.
- No ordering of functions, tasks, or partially applied methods by any proxy — not by name, not by
  identity, not by rendering.

## Edge Cases

- An integer and a float compare numerically rather than by shape, because a program that mixes them
  in one collection means the numbers.

## Depth

DEPTH 0.50 (MEDIUM). One total order and one honest refusal.

## Grill Log

- **Q:** Should `compareValues` fail on an unorderable pair instead of answering `EQ`? **A:** No.
  _Rationale:_ the comparison is called from inside a data structure's invariant, where a failure has
  nowhere to go; refusing at the boundary is where a caller can act on it. _Rejected:_ a partial
  comparison returning `Maybe Ordering`, which would push the same decision into every call site.
- **Q:** Why did the order move to [[Eval Value]] in #157? **A:** Because the keyed collections
  became balanced trees keyed by `OrdValue`, so the value type now names the order in its own
  declaration and cannot be compiled before it. _Rejected:_ keeping the instance here as an orphan,
  and a `.hs-boot` cycle between the two — the first is prohibited outright, and the second buys a
  file boundary at the price of a build-order subtlety every later reader would have to learn.
- **Q:** Should this module have been folded into [[Eval Value]] entirely? **A:** No. _Rationale:_
  which values may be keys is a rule enforced at a boundary, and it answers with a refusal the user
  sees as `E7008`; how two keys compare is a property of the value model. They change for different
  reasons. _Deferred:_ revisit if this module stays a single predicate and stops growing.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Keyed]]
