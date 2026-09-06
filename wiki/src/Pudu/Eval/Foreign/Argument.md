---
type: module
path: "@root/src/Pudu/Eval/Foreign/Argument.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium, runtime, foreign, ffi]
aliases: [Eval Foreign Argument]
---

# Eval Foreign Argument

## Purpose

Enforce and prepare foreign function arguments across the native boundary according to their declared crossing specifications.

## Interface

```haskell
crossArguments :: Span -> ForeignBinding -> [Value] -> Evaluator [(Crossing, Bool, CrossedValue)]
crossOne :: Span -> ForeignBinding -> Crossing -> Value -> Evaluator (Crossing, CrossedValue)
crossField :: Span -> ForeignBinding -> Text -> [(Text, Value)] -> (Text, Crossing) -> Evaluator (Text, CrossedValue)
isIntegral :: Crossing -> Bool
slotsOf :: ForeignBinding -> [Maybe ForeignSlot]
count :: Int -> Text
```

## Governance

- **Every check that can happen before the call happens before the call.**
- **Arity checking is exact:** If argument count does not match the non-slot positions declared in the foreign binding, raises `E7016`.
- **Text carrying a nought is refused (`E7017`):** Null bytes in strings are forbidden to prevent truncated C-string reads.
- **Integer overflow/underflow is refused (`E7018`):** An integer that does not fit its declared bitwidth and signedness is rejected rather than silently wrapped or truncated.
- **Type crossing validation (`E7019`):** Floats, booleans, bytes, handles, and records must strictly match the declared crossing type.
- **Record validation (`E7023`):** Records crossing foreign boundaries must provide all declared fields by name.
- **Slot handling:** Slots receive no caller value on input; they are threaded with placeholder values and marked for post-call output extraction.

## Linkage

- **Requires:** `Pudu.Diagnostic`, `Pudu.Eval.Env`, `Pudu.Eval.Value`, `Pudu.Foreign.Call`, `Pudu.Foreign.Crossing`, `Pudu.Source`.
- **Consumed by:** `Pudu.Eval.Foreign`.

## Negative Logic (Prohibited Paths)

- No silent integer truncation or modular wrapping.
- No native memory allocation or execution; pure boundary validation and marshaling only.

## Grill Log

- **Q:** Why isolate argument crossing into `Eval.Foreign.Argument`? **A:** Validating and converting caller values to native `CrossedValue` representations constitutes a distinct, cohesive phase (~130 lines) separate from symbol resolution, ownership leasing, execution, and result settlement.
