---
type: module
path: "packages/pudu/v0.1/src/Pudu/Type/Check/Receiver.hs"
fidelity: Active
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
tags: [module, types, methods]
aliases: [Type Check Receiver]
---

# Type Check Receiver

## Purpose and interface

`bindReceiver :: Span -> Type -> Type -> Checker Type` specializes an instantiated
method's full signature to the receiver before exposing its remaining parameters.
Both immediate calls and captured method values use this operation.

## Algorithm

Follow the receiver's references, follow the self parameter's references (automatic
method borrowing), and unify those referents. Return error poison on mismatch.
Otherwise remove exactly the first parameter, preserve asyncness, capability
wrappers and the remaining required argument count, and zonk the resulting type.
Instantiating each method use separately keeps distinct receivers independent.
The existing constructor-wide implementation form (`impl Counting for Array`)
gives Self a bare constructor. When that exact canonical owner receives an applied
value, saturate the bare Self occurrences with that receiver's arguments before
binding it. Applied heads always match their arguments; a different owner never
matches. Preserve this behavior for both calls and captured values.

## Negative logic

Never infer implementation type arguments from later arguments while ignoring self.
Do not re-check the receiver expression, invent a conversion at ordinary function
calls, or dispatch an evaluator here. Writable-receiver checks remain in [[Check Place]].

## Grill Log

- **Q:** Drop self without unifying it? **A:** No. That permitted Field[T, F].get
  to choose a different T or F from its arguments/result and affected every generic
  nominal method. _Rejected:_ accessor-specific workarounds.
- **Q:** Preserve the required count? **A:** Subtract one for the bound receiver.
  A method value retains defaults just as an ordinary stored function does.
- **Q:** Reject constructor-wide implementations? **A:** No. Their bare Self is
  applied at receiver binding; arbitrary applied heads retain exact unification.
  _Rejected:_ ignoring every receiver, or treating a concrete applied head as a
  wildcard over other arguments.

## Linkage and references

Requires [[Type Env]], [[Type Unify]], [[Type Value]]. Consumed by [[Type Check Call]]
and [[Type Check Rule]]. Referenced by [[src/Pudu/Type/_MOC]].
