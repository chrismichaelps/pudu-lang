---
type: module
path: "@root/src/Pudu/Foreign/Crossing.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.6
tags: [module, medium, foreign, ffi]
aliases: [Foreign Crossing]
---

# Foreign Crossing

## Purpose

What may pass between this language and another, stated once so both the checker and the runtime
read the same list.

## Interface

```haskell
data Crossing = SignedCrossing !Int | UnsignedCrossing !Int | FloatingCrossing !Int
              | BooleanCrossing | TextCrossing | HandleCrossing !Text
              | RecordCrossing !Text ![(Text, Crossing)] | NothingCrossing

crossingFor    :: Set Text -> RecordLayouts -> Located TypeSyntax -> Maybe Crossing
crossingName   :: Crossing -> Text
crossingType   :: Crossing -> Type
fitsCrossing   :: Crossing -> Integer -> Bool
crossableNames :: Text
type RecordLayouts = Map Text [(Text, Located TypeSyntax)]
recordLayouts  :: [Located Declaration] -> RecordLayouts
foreignArgumentLimit    :: Int
foreignRecordFieldLimit :: Int
```

### Governance

- **The set is stated rather than inferred.** A general marshaller for arbitrary types is how an
  interface stops being able to say what it does, and every value it fails on fails when it is
  called rather than where it is written. Anything absent is refused at the declaration.
- **A crossing's type on this side is the type the declaration wrote.** `Int32` is already one of
  this language's own types, so a foreign signature is an ordinary signature — checked by the
  ordinary checker, shown by the ordinary hover. A binding language that invents a parallel set of
  width names spreads them through everything that calls the binding.
- **A width that does not fit is a question, not a wraparound.** `fitsCrossing` is what the runtime
  asks before a value leaves. Silent wraparound at this boundary is how a program calling a library
  keeps running with a value it never computed.
- **The names are in one place** so a diagnostic can offer the whole list rather than a guess about
  which one was meant.
- **Handle names are unqualified and come from the enclosing block.** A qualified `Other.Box` is
  never reduced to `Box`; scalar names may be unqualified only as well. A misspelled or qualified
  handle is refused rather than laundered into the block's own nominal type.

- **A record crosses by value and is an ordinary record.** What a library passes about is its
  colours, points, and rectangles, so a boundary admitting only scalars admits almost nothing real.
  The declaration names a record this program already has; it crosses when every field crosses, one
  level deep, and the fields travel in the order the declaration wrote them. `()` and opaque handles
  are not stored fields: unit has no value, while a nested handle would evade the top-level ownership
  lease and release contract. `Str` is a pointer field whose UTF-8 bytes are borrowed for the call or
  copied on return exactly as direct text is.
- **The layout is the platform's answer.** Only names and widths are carried across; where each
  field sits inside the record is asked for on the other side. A calculation here would be right on
  the machine it was written for and silently wrong on the next.
- **The bridge limits are declaration limits.** A call has at most 32 arguments and a flat record at
  most 32 fields. A larger shape is refused where it is declared rather than accepted by the checker
  and rejected only when execution reaches the native bridge.

### Linkage

- **Requires:** [[Pudu Type]], [[Pudu Syntax Tree]].
- **Used by:** [[Type Check Foreign]], [[Eval Foreign]], [[Foreign Call]], [[Eval Install]].

## Grill Log

- **Q:** Give the boundary its own type names — `I32`, `CText` — as most binding
  layers do? **A:** No. _Rationale:_ this language already has `Int32` and `Str`;
  a second spelling for the same thing means a caller converts at every call and
  the foreign names leak into code that has nothing to do with the boundary.
  _Rejected:_ a parallel width vocabulary.
- **Q:** Represent a handle as an integer? **A:** No. _Rationale:_ its address-shaped storage is not
  permission to calculate with it, and its declared name prevents one resource from being passed as
  another. _Rejected:_ exposing addresses as `Int64`; one universal pointer type.
- **Q:** Compare only the final segment of a foreign type path? **A:** No. _Rationale:_ `Other.Box`
  and this block's `Box` are different nominal types even when their basenames match. _Rejected:_
  qualifier erasure at the ABI boundary.
- **Q:** Treat `()` like any other field or parameter because it has a kind code? **A:** No.
  _Rationale:_ void describes the absence of a result; neither C nor libffi has a value of type void
  to place in an argument register or record field. _Rejected:_ deferring the bridge refusal until
  the call.
- **Q:** Put an opaque handle inside a by-value record? **A:** No. _Rationale:_ handle ownership is
  attached to a top-level foreign result and its declared release; nesting one would hide it from
  liveness leasing on arguments and ownership registration on results. _Rejected:_ recursively
  leasing or claiming fields without a field-level lifetime and release declaration.

## Referenced by

[[src/Pudu/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[grammar/pudu]]
