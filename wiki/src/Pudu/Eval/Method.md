---
type: module
path: "@root/src/Pudu/Eval/Method.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.85
tags: [module, shallow, runtime]
aliases: [Eval Method]
---

# Eval Method

## Purpose

The closed vocabulary of built-in methods on the language's own values, and the name each answers to.

## Interface

```haskell
data ArrayMethod   = ArrayLength | ArrayIsEmpty | ArrayGet | …
data StringMethod  = StringLength | StringIsEmpty | StringCharAt | …
data MapMethod     = MapSize | MapIsEmpty | MapGet | …
data SetMethod     = …
data BytesMethod   = …
data BucketsMethod = …
data CharMethod    = CharCode | CharToText

arrayMethodName   :: ArrayMethod -> Text
stringMethodName  :: StringMethod -> Text
mapMethodName     :: MapMethod -> Text
setMethodName     :: SetMethod -> Text
bytesMethodName   :: BytesMethod -> Text
bucketsMethodName :: BucketsMethod -> Text
charMethodName    :: CharMethod -> Text
```

### Governance

- **Each set is closed.** A method the compiler knows the semantics of can be typed exactly, and an
  unknown one is reported rather than dispatched into whatever happens to be there.
- **The name table is the single spelling.** The checker matches it, the diagnostic prints it, and
  the evaluator dispatches on it, so a rename cannot leave two of them disagreeing.
- **Definitions only.** Nothing here depends on a runtime value, an environment, or an evaluator,
  which is why it can sit beneath [[Eval Value]] rather than inside it — and why [[Eval Value]] can
  re-export the whole vocabulary without any caller learning that it moved.
- **A collection answers with a new collection.** Every method here is a question rather than a
  change to the receiver, which is what makes a value a value.

### Linkage

- **Requires:** nothing but `Data.Text`.
- **Used by:** [[Eval Value]] (which re-exports it), [[Eval Dispatch]], [[Type Check Rule]].

## Grill Log

- **Q:** Why extract this rather than leave it in [[Eval Value]]? **A:** Because that file had passed
  500 lines again and a reviewable file is the point of the limit. _Rationale:_ this is the same
  seam [[Eval Builtin Definition]] used — a closed tag set and its name table, with no dependency on
  the runtime value it describes — so the split follows the code rather than the line count.
  _Rejected:_ splitting `Value` by alphabetical halves; restating the size as acceptable.
- **Q:** Should callers import this module directly? **A:** They may, but they need not.
  _Rationale:_ [[Eval Value]] re-exports it, so the extraction changed no call site and no import
  list — which is what makes it safe to do for a size reason. _Rejected:_ forcing every user to
  learn a second import.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Value]]
