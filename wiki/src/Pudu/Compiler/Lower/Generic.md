---
type: module
path: "@root/src/Pudu/Compiler/Lower/Generic.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Generic]
---
# Compiler Lower Generic

## Purpose and interface

Copies of generic bodies under [[Native Generics]].

- `admitCallee` admits a call's callee and returns the key the call names: the
  function itself when it is monomorphic, otherwise the copy for the types
  checking instantiated it at the callee's span. The signature is admitted in
  the callee's module under the callee's bindings, and the caller's come back.
- `specialize` binds a scheme's rigid parameters against an instantiation,
  forms each in the caller's facts and registers the copy under
  `key[<types>]`. Already known bindings (`Self` of an inherited default) are
  passed in and kept.

## Matching

Matching walks the scheme and the instantiation together: rigid parameters
bind (and must agree when seen twice), nominal types, tuples and function
types match member by member, and a shared reference on one side only is
looked through, since a receiver is passed by value where the member wrote
`self: &Self`. An unconstrained variable matches anything. A parameter left
open stands for unit, the same rule [[Compiler Lower Types]] uses for an
unconstrained sum argument: no value holds it.

Inside a copy, facts still name the copy's own rigid parameters. Before
matching, they are replaced by what they stand for there, written back as the
checker spells types (`unformed`), so calls made from a copy specialize too.

## Resolved Grill Log

- **Q:** Why read the callee's span? **A:** That is where checking recorded
  the instantiated function type, with every type argument settled. Rejected:
  inferring type arguments from the argument expressions, which would be a
  second checker.
- **Q:** What if a type argument has no native form? **A:** The call refuses
  with E6001 at the callee. It must never return no result without a refusal;
  [[Compiler Lower Body]] now refuses any construct that does.
- **Q:** One copy per call or per type list? **A:** Per type list; the key
  carries the formed types, so `identity[Int]` is lowered once however many
  calls reach it.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Signature]] · [[Core IR]]

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Method]] · [[Native Generics]]
