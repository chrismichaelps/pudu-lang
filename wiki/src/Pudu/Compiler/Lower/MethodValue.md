---
type: module
path: "@root/src/Pudu/Compiler/Lower/MethodValue.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Method Value]
---
# Compiler Lower Method Value

Export lowerMethodValue. For a member expression on a text, array, map, set,
range, char or bytes receiver whose fact is a function type, lower the
receiver once and answer a closure over it. The lifted body, keyed by method,
receiver type and signature, declares `$receiver` from capture 0 and lowers
`$receiver.member($1, ...)` through the ordinary call dispatch. The call span
is re-faced to the method's result and each argument gets a span past the
end of the source with its parameter's fact; the overlay is dropped after.

## Resolved Grill Log

No method is implemented twice. Refusals raised inside the body point at
made-up spans, so they are replaced by one refusal at the member expression.
Closure info records the receiver type, which drives rendering, equality and
the caller-blaming frame flag. See [[Native Method Values]].

## Text methods (#846)

`toText` taken as a value from a receiver whose type declares no `toText` (an
Int, Float, Bool, Decimal, tuple, or a record or sum without one) is a bound
value whose body is the written `$receiver.toText()`. Its key starts with
`textMethodPrefix` from [[Core Closure Identities]], so emission renders it as
the interpreter does.

Resolved Grill Log: decide by the same owner lookup [[Compiler Lower Method]]
makes for a written `toText()` call. _Rejected:_ admitting every scalar member
(only `toText` exists on them).

## Referenced by

[[Compiler Lower Body]] · [[src/Pudu/Compiler/_MOC]]

## Trait methods (#646)

Declared receivers qualify when the member is not a field; an unbound
`Owner.member` qualifies when the value's first parameter is a declared type
owned by that name. Resolved Grill Log: the unbound wrapper has no
environment and records the first parameter as its receiver type with no
capture, so equality compares sites only.

## Mutable loans (#794)

A lifted method value whose function type has `&mut` inputs lends them on
to the written call by name and closes its body over their finals, so
`b.steal` and `Bag.grow` used as values write back where they are called.

## Selected providers (#798)

A method value keeps the selected member in the call it lifts, so the call
resolves the same provider, and names itself by the plain member.

## Indexed stores (#840)

A store's methods are values bound to their receiver, rendered `<store method name>`. Resolved Grill Log: the lifted body is the written call, so narrowing and Option construction are shared.

## Text methods on dynamic values (#956)

Resolved Grill Log: a dynamic member read selects the callable from the
held value when the read executes. The callable therefore retains the
held receiver and keeps its ordinary display and identity. Calls on the
universal member reuse the same payload selection. Returning arms keep
their actual layouts through the join.

Direct calls retain a mutable receiver's place and rewrap the resulting
payload before writing it back. A member read captures the held value.
Character and byte members read as values keep their builtin selection.

## Consumers of dynamic text-call results (#956)

Resolved Grill Log: a uniform result keeps its native carrier, and
heterogeneous arms produce a runtime alternative. Effects and receiver
writeback happen before the consumer sees the value.

## Stored text callables with different results (#956)

Resolved Grill Log: resolve each held member's own callable shape, then
join selected values in a runtime alternative when their shapes differ.
Keep callable identity, receiver and return carrier inside the selected
variant. No caller reads a callee result through another type's ABI.

## Marking a uniform nonmatching runtime value (#956)

Resolved Grill Log: a known native value whose carrier differs from the
checked member type retains that runtime fact in its layout, even if
selection has only one returning alternative.

## Bound array runtime carriers (#956)

Resolved Grill Log: a bound array method captures the lowered array with
its actual element layout. Its lifted body declares the native result
carrier when it differs from the checked result, and the closure uses
that signature. The checked method parameters still set the input ABI.

## Runtime layouts in stored methods and builtins (#956)

Resolved Grill Log: Rebuild a method on its checked receiver and parameter facts, using the native layouts supplied by the call. Settle the resulting frame signature before emitting the closure.

## Runtime keyed layouts (#956)

Resolved Grill Log: A bound keyed method captures the exact collection layout. Its body reads and returns values using those slots.

## Loaned stored method layouts (#956)

Resolved Grill Log: a stored method settles its ordinary result
separately from the finals of its lent parameters. A copied wrapper
uses the exact layout for each final.

## Stored mutable parameter layouts (#956)

Resolved Grill Log: Register the wrapper’s parameter sites before lowering the synthetic call. Replay the wrapper when the implementation demands a broader place carrier.

Resolved Grill Log: a stored mutable receiver retains its original
capture layout. A widened receiver local is projected from that
capture for each invocation and uses a separate layout demand.

## Selected receiver layouts (#956)

Resolved Grill Log: Reading a bound member selects the receiver carrier before building its closure. Missing members report at the member access.

## Exact dynamic Int payloads

Resolved Grill Log: A stored dynamic trait method retains its receiver once and invokes the same dispatch as a direct call.
