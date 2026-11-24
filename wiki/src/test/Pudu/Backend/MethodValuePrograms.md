---
type: module
path: "@root/test/Pudu/Backend/MethodValuePrograms.hs"
fidelity: Active
aliases: [Backend Method Value Programs]
---
# Backend Method Value Programs

Export methodValueSuccessPrograms and methodValueRefusalPrograms. Successes
cover text, array, map, set, range, char and bytes methods as values; a
receiver reassigned after the value was made; values in records and generic
callers; rendering, equality on equal and different receivers; Option, array
and slice answers; and 200 owned receivers in a loop. Refusals cover an index
failure and an E7008 key refusal, both reported at the call through the value.

## Resolved Grill Log

Expectations come from the tree interpreter and are rechecked against the
compiled evaluator on every run; the healthy programs also run under counted
allocation.

## Dependencies and consumers

[[Backend Output Callable Programs]] · [[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Pudu Test Cabal Manifest]]

`toText` taken as a value from Int, Float, Bool, Decimal, UInt8, tuples, records and sums renders `<method toText>`, calls render the receiver and equality compares receivers (#846).

## Referenced by

[[Native Method Values]] · [[src/Pudu/Backend/_MOC]]

## Trait methods (#646)

Records and sums as receivers, `Bot.label` through its type, arrays and
record fields of method values, receiver equality, a receiver with output,
and a division by zero inside the implementation at the body's own span.

## Dynamic text member selection (#956)

Resolved Grill Log: exercise the checked trait member, a held override,
universal rendering, a character method, and a callable field. A stored
method captures the held receiver before the dynamic binding changes.
A direct mutable override writes back through an indexed receiver, and
a stored override keeps its receiver independent of that place.

## Direct dynamic text result consumers (#956)

Resolved Grill Log: text and byte implementations share one view. The
same direct-call source uses display, show and standard output on each
actual result, including valid and invalid byte sequences.

Resolved Grill Log: a dynamic receiver with a numeric text field runs
its receiver effects before the ordinary call failure.

## Stored dynamic text result alternatives (#956)

Resolved Grill Log: retain a Str or byte decoder selected from one
dynamic member expression. Rebind the original receiver, then invoke
and display the captured callable and its actual result.

## Runtime alternatives across direct calls (#956)

Resolved Grill Log: return a text method from an ordinary function,
accept it through a declared callable parameter, and pass its answer
through a function with a declared Str parameter. Cover an explicit
early return and an ordinary matching-carrier call beside the native copy.

## Array runtime element carriers (#956)

Resolved Grill Log: store checked callable values with different native
return shapes. Cover indexing, retrieval, functional updates, retained
aliases, concatenation, range slices, and iteration.

Resolved Grill Log: bind `get` before rebinding or updating the array.
Invoking the bound method reads the retained array and returns the
selected callable with its original result layout.

Resolved Grill Log: retrieve and iterate a mixed-carrier array returned
from an internal function declared with the checked array type.

## Array callbacks with runtime element carriers (#956)

Resolved Grill Log: call named and inline callbacks with callable array
elements. Preserve selected results in map output and exercise filter,
reduction and ordering over the same retained elements.

Resolved Grill Log: repeat a reduction after its accumulator changes
carrier and verify an empty reduction keeps the seed. Exercise the same
callback boundary over a range.

Resolved Grill Log: join mapped values when every held result is text,
and check that a selected decoder result fails after separator effects.

## Stored callback calls with runtime element carriers (#956)

Resolved Grill Log: pass a retained closure through an internal function, then call it directly and from an array operation. Rebinding the local used to make it leaves the captured value intact.

## Stored method input layouts (#956)

Resolved Grill Log: bind a user method and an array update before calling them with a selected text method. Check the retained receiver and the returned callable.
