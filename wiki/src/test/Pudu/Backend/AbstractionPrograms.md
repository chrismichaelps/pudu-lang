---
type: module
path: "@root/test/Pudu/Backend/AbstractionPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Abstraction Programs]
---
# Backend Abstraction Programs

Export abstractionSuccessPrograms and abstractionRefusalPrograms. Success
programs cover static members through a type parameter with written and
inferred arguments and generic implementations, sequence patterns in `let`
at every depth, dynamic values (widening at each expectation site, dispatch
with defaults and arguments, nesting, rendering and equality) and
constructor parameters of one and two arguments, plain and through a trait.
Refusal programs pin E7013 for a sequence of another length, top-level and
nested in a record.

## Resolved Grill Log

Every expectation is what the interpreter prints for the same program. All
success programs also run under the counted-allocation harness.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Type Abstractions]]

## Dynamic operator cases (#956)

Exercise negation and complement on held integers, equality with a concrete
implementation, and runtime refusals on held text or sum variants. Cover
text addition, mixed-width checked, wrapping and saturating integer
operations, mixed-width equality, signed shifts and division by zero. An
overflow must retain its original operation, kind and span. Text and
characters retain their separate display and show results through the dynamic cell.

### Resolved Grill Log

A dynamic result must still dispatch against the updated value in a later
method call.

## Dynamic aggregate order (#956)

Compare dynamic integers of different widths inside tuples and exercise
ordering and duplicate elimination for an ordered collection of those keys.

### Resolved Grill Log

Use held numbers whose order disagrees with the order of their type names.


## Dynamic shape order (#956)

Cover nonnumeric payloads whose type names sort differently from their shapes.
Exercise both alternatives of a sum with positional and named variants, as
concrete tuple members and as dynamic keys.

### Resolved Grill Log

Check both ordering directions and the ordered set's rendered output.

## Dynamic replacements and collection methods (#956)

Resolved Grill Log: the differential program widens record updates, nested
place assignments, array arguments, set literals and keyed arguments.
A second program supplies an implementing value beside a mutable loan
through direct and stored calls and observes both the result and writeback.

## Dynamic results across loop exits (#956)

Resolved Grill Log: a loop joins an already-widened value with a concrete
implementation at another break. One concrete operand runs its effect
before breaking, and a labelled break nested inside another break operand
reaches the outer carrier without producing an inner result.
