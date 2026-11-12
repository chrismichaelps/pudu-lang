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
