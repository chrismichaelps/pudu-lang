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

Provide the total order that keyed collections need, and say which values do not have one.

## Interface

### Signatures

```haskell
newtype OrdValue = OrdValue {unOrdValue :: Value}
comparableValue :: Value -> Bool
compareValues :: Value -> Value -> Ordering
```

### Governance

- The runtime's `Value` deliberately has no `Ord` instance. A function is a value, and no order on
  functions is meaningful; deriving one would let a map silently accept a key it cannot compare.
  Wrapping the values that can be ordered keeps the distinction visible at every use.
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

Structural recursion with a shape rank as the fallback comparison.

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

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Keyed]]
