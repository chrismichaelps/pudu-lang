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
              | BooleanCrossing | TextCrossing | NothingCrossing

crossingFor    :: Located TypeSyntax -> Maybe Crossing
crossingName   :: Crossing -> Text
crossingType   :: Crossing -> Type
fitsCrossing   :: Crossing -> Integer -> Bool
crossableNames :: Text
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

### Linkage

- **Requires:** [[Pudu Type]], [[Pudu Syntax Tree]].
- **Used by:** [[Type Check Foreign]], [[Eval Foreign]], [[Foreign Call]], [[Eval Install]].

## Grill Log

- **Q:** Give the boundary its own type names — `I32`, `CText` — as most binding
  layers do? **A:** No. _Rationale:_ this language already has `Int32` and `Str`;
  a second spelling for the same thing means a caller converts at every call and
  the foreign names leak into code that has nothing to do with the boundary.
  _Rejected:_ a parallel width vocabulary.
- **Q:** Admit a pointer now, since [[ADR-0018 Calling a Library Written Elsewhere]]
  describes one? **A:** Not in this slice. _Rationale:_ a pointer needs a runtime
  representation and an ownership rule of its own, and `owned … by …` already
  exists in the declaration form, so the next slice adds a type rather than a
  syntax. _Rejected:_ an opaque integer standing in for an address.

## Referenced by

[[src/Pudu/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[grammar/pudu]]
