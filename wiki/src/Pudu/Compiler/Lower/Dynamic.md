---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Dynamic.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Dynamic]
---
# Compiler Lower Dynamic

Export dynamicSums, isDynamic, widen, widenBlock, widenTo, writtenType and
pathText. `dynamicSums` gives every trait a sum over its implementing types:
one variant per concrete payload, holding that value. The sum is filed under the trait's own
identity inside a `dynamic` module no program can declare, which is what
[[Compiler Lower Types]] forms a `dynamic Trait` to.

`widen` answers a value as an expected type holds it: itself when the types
agree, its variant when the expected type is dynamic and the value's type is
one of the implementing types. A literal whose members are expected dynamic
(an array, tuple, record, variant, block, `if` or `match`) is built again
with each member widened, to any depth. `widenBlock` widens a block's
result and `widenTo` answers the widened value beside its type.

`writtenType` forms a written type with the given names rigid; resolution
has already made every path canonical. [[Compiler Lower Method]] reads
implementation heads through it.

## Resolved Grill Log

A closed sum is the whole dispatch table: lowering sees every implementation
of the program, so a method call is a match over the held type and needs no
table of function addresses. Widening happens only where a dynamic type is
expected, the one direction checking allows. A generic implementation
contributes the concrete payloads established by proven widenings.
A value that is not a literal and holds an implementing type inside another
type is not converted.

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Compiler Lower Method]] · [[Compiler Lower Generic]] · [[Compiler Lower Array]] · [[Compiler Lower Record]] · [[Compiler Lower Sum]] · [[Compiler Lower Match]] · [[Compiler Lower Call]] · [[Native Type Abstractions]]

## Nominal aggregate widening (#956)

Resolved Grill Log: rebuilding a record literal or constructor for wider
members requires the same canonical owner. Layout coincidence cannot
justify replacing nominal identity at a branch join.

## Payload selection (#956)

Resolved Grill Log: widening finds the variant by the exact concrete
payload type and constructs it using the selected tag. Canonical method
lookup and nominal pattern selection read the payload's owner separately.

## Concrete applications from widening proofs (#956)

Resolved Grill Log: form variants for the concrete nominal applications
that checking proved against a trait. Distinguish parameter lists in
the tags and deduplicate matching applications across sites. Keep
declaration-only monomorphic alternatives. Facts still containing rigid
parameters remain available for specialization of their owning bodies.

## Joining runtime alternatives (#956)

Resolved Grill Log: a runtime selection whose returning arms disagree
keeps each known layout in a tagged box. Uniform results keep their
existing carrier. Consumers select a tag, then use the complete held type.
The same projection traces closures and returned values.

## Runtime carrier admission at a boundary (#956)

Resolved Grill Log: union the leaf carriers of a runtime selection and
rebox through a typed match when an already boxed value crosses into a
larger layout. Mark a result that differs from its checked carrier even
when its actual shape is uniform.

## Uniform marked compound carriers (#956)

Resolved Grill Log: a uniform carrier with an embedded runtime
alternative already describes its difference from the checked carrier.
Keep the compound layout directly. Reserve an outer tag for carriers
that need it to record a runtime alternative.

## Runtime layouts in products (#956)

Resolved Grill Log: Project compatible tuples and same-owner records by retaining the source once and projecting each field. Native product joins give every branch one stable carrier.

## Runtime layouts in sum payloads (#956)

Resolved Grill Log: Join same-owner sum carriers by variant and payload position. Project a retained sum by matching its tag and rebuilding the selected payload.

## Mutable slot layout discovery (#956)

Resolved Grill Log: Copy arrays or keyed values into a wider element layout through a typed traversal. Keep the logical order, value ownership and original aliases.

## Selected receiver layouts (#956)

Resolved Grill Log: Report the held value kind at a failed member read or index. Preserve the evaluator’s distinct names for nominal members and index failures.
