---
type: module
path: "@root/test/Pudu/Backend/ShapePrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Shape Programs]
---
# Backend Shape Programs

Exports shapeSuccessPrograms and shapeModulePrograms.

Resolved Grill Log: a record of aliases holding a function, called through its
field; a trait method of a field's name winning over the field, with and
without parentheses, arguments printing before the call; mutually recursive
records in one module and across two; a record whose fields are another
module's aliases; and assignments as match-arm, `if let` and binding values.

## Referenced by

[[Backend Module Programs]] · [[Backend Text Leak Tests]]

Resolved Grill Log (#828): Pin method precedence and capture a function-valued field before an argument rebinds its record.

Resolved Grill Log (#872): shorthand fields naming a top-level function, a
generic function at its instantiation and a local, through construction,
record update and a named payload, compile natively from the checker's
published facts.

## Dynamic members at aggregate joins (#956)

Resolved Grill Log: compare both branches of an if that produces a tuple
and both match arms that construct an Option. Their members remain concrete
until projected into the expected dynamic carrier. The consumer dispatches
on each held implementation.

## Dynamic nominal patterns (#956)

Resolved Grill Log: two modules export the same record and sum names.
Exercise record and positional and named sum narrowing with guards, a
nested dynamic field, if let and let else. Results expose both payload
bindings and fallback behavior.

## Dynamic method provider identity (#956)

Resolved Grill Log: one concrete record implements two traits of the
same display name, each with its own body for the same member. Both dynamic
views of the same value reach their selected body.

## Generic dynamic payloads (#956)

Resolved Grill Log: instantiate a generic implementation at two concrete
payload types through checked widenings. Pass both variants through an
array of the trait type and call the implementation on each.

Resolved Grill Log: a second fixture widens a construction inside a
specialized function. Its payload type is rigid during checking and
becomes concrete only in the reachable copy.

Resolved Grill Log: a dynamic record pattern reads a common field from
all three concrete variants of the same owner.

## Comparing different dynamic payload layouts (#956)

Resolved Grill Log: compare erased generic owners with different concrete
types, including empty and populated nested payloads, mixed-width integer
ordering, and membership in an ordered collection of dynamic keys.

## Runtime layouts in tuples and records (#956)

Resolved Grill Log: retain selected callable layouts through construction, field reads, record updates, branches and destructuring. Check the original value after updating a shared record.

## Runtime layouts in sum payloads (#956)

Resolved Grill Log: exercise positional and named constructors, tag tests, payload binding and early propagation with selected callable values.

## Task results with selected native layouts (#956)

Resolved Grill Log: cover named and stored async bodies with selected
inputs, delayed execution, explicit awaits, and a joined child failing
with an alternative carrier.

## Native mutable loan layouts (#956)

Resolved Grill Log: hold a field and indexed place once through direct and indirect calls, preserve their callable carriers and verify the returned value and writeback.

## Later mutable writes (#956)

Resolved Grill Log: start with the checked carrier and introduce alternatives after initialization. Exercise branches, repeated writes, indexed setters and aliases retained before the update.

## Stored loan writeback layouts (#956)

Resolved Grill Log: a stored lambda and a retained bound method write selected callable values through places that started with the checked layout.
