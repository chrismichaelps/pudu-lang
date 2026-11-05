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

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Signature]] · [[Core IR]] · [[Type Substitution]]

## Referenced by

[[Compiler Lower Body]] · [[Compiler Lower Method]] · [[Native Generics]]

## Mutable loans (#790)

matchType looks through a reference of either kind on either side: a value
lent to `self: &mut Self` holds its target, so a generic implementation is
instantiated at the receiver's own type.

## Derived bindings and `matchType` (#824)

`specialize` takes the instance's derived trait arguments, substitutes the
copy's own bindings into each and forms them in the caller's facts. A copy
binds every rigid name its body names, the trait's included. `matchType` is
exported so method tables can recover trait arguments the same way a call
recovers its instantiation.

Resolved Grill Log (#824): derived bindings are formed against the settled
implementation bindings, then overlay them for the body's scope. Fixed bindings
contain `Self` only for inherited defaults. The body and implementation may
reuse a parameter spelling without sharing its meaning. Keeping a fixed trait
parameter before matching would erase a same-named implementation parameter.

Resolved Grill Log: a registered copy stores its scheme type substituted with
the settled implementation bindings before installing the body overlay.
Signature admission reads that concrete scheme, while body facts read their
own namespace. Otherwise `Box[T]` in an implementation signature could become
`Box[Str]` merely because the trait body binds its own `T` to `Str`.

Resolved Grill Log: reifying settled native collection arguments preserves
the canonical Array/Map/Set/Range constructors and their arguments. Display
strings such as `Array[Int]` are not nominal identities and cannot be used
when a derived body argument is passed to another generic member.

Resolved Grill Log: freeze a copy's scheme by substituting matched checker
`Type`s, preserving callable required counts and capabilities. Reconstructing
a semantic function type from the native carrier loses that metadata and
regresses passing function values through ordinary generic functions. Native
function carriers reify structurally for matching nested calls, never as
display-text nominal identities.
