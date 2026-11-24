---
type: module
path: "@root/src/Pudu/Compiler/Lower/Generic.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Generic]
---
# Compiler Lower Generic

## Concrete held call arguments

Resolved Grill Log. Specialize the body whenever a represented
argument differs from its admitted slot. A single concrete held
layout can be the source of that difference. Keep omitted parameters
and the hidden supplied count in their declared positions.

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

## Callable entry copy

entryCopy registers the entry declaration under its internal instance key so the worklist can lower it against the original checked scheme. Recursive calls reuse that key.

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

## Indexed stores (#840)

unformed spells CoreStoreType back as `Buckets[...]`. Resolved Grill Log: generic copies over stores match by the checker's own spelling.

## Open applications and constructor parameters (#846)

`admitCalleeGiven` receives the arguments' own types. When checking left the
callee's fact as an application it never settled, the operands fill the
scheme's inputs and the result stays open; a constructor parameter applied to
arguments matches against the actual type's constructor and the arguments the
application does not supply. Written type arguments fill the scheme's
parameters in declared order.

`throughBounds` settles parameters named only by a bound: the implementation
head providing that bound supplies the bound's arguments, and those matches may
settle further parameters, with fuel against cycles. `instantiationOf` does the
same for a call checking recorded no fact for, as a `for` asking a sequence for
`begin` does. `writtenCoreType` forms a call's written types when no fact
exists. Resolved Grill Log: only checking's recorded instantiation and the
operands' solved facts select a copy; nothing is inferred from spelling alone.

Written type arguments are admitted through `writtenTypeArguments`, moved here
from [[Compiler Lower Body]]: it reads checking's recorded tuple at
`typeArgumentsKey` first, then forms what the call wrote. Resolved Grill Log:
the application's written arguments belong with the specialization they feed,
and keeping them here leaves the body module below the size target.

## Widening proofs in specialized bodies (#956)

Resolved Grill Log: reuse the specialization substitution for checked
dynamic payloads. Descend into restricted function types so their enclosed
types settle with the copy's other bindings.

## Runtime call copies (#956)

Resolved Grill Log: a direct call and a method callback can request the
same exact native input signature. The instance keeps checking's
substitution and uses the result settled for that copy. Async and loaned
parameters retain their established signatures.

Resolved Grill Log: a copy's key uses its source specialization and
complete parameter layout. Retargeting a retained copy can reuse an
existing body with that layout.

## Native task result layouts (#956)

Resolved Grill Log: Internal async functions use exact input copies. Calling the copy creates a deferred task.

## Native mutable loan layouts (#956)

Resolved Grill Log: Specialized loaned parameters use the held place layout. Ordinary arguments can widen independently.

Resolved Grill Log: apply demands to the mutable parameters of a
native signature copy after its key has been chosen.

## Stored mutable parameter layouts (#956)

Resolved Grill Log: Keep native copy keys independent of layout demands discovered inside the body.
