---
type: module
path: "@root/test/Pudu/Backend/TextPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text Programs]
---
# Backend Text Programs

## Purpose and interface

Export textSuccessPrograms :: [(String, Text, Text)] (label, source, expected
stdout) and textRefusalPrograms :: [(String, Text)]. [[Backend Native Tests]]
runs them against the interpreter and the expected answers;
[[Backend Text Leak Tests]] reruns the success programs with counted heap
blocks.

## Coverage

Literals: empty text, escapes, multi-byte scalars up to four bytes, NUL.
Concatenation: self-doubling reassignment, a loop accumulator built from
`display`, nested grouping. Comparisons: prefixes, empty text, a two-byte
scalar against ASCII, NUL ordering. Rendering: display and show of narrow and
wide integers at their extremes, both float widths, Bool, unit and Str,
including show's escapes and an unescaped carriage return. Interpolation of
every kind plus a computed hole. Transport: parameters, results, recursion,
an argument snapshot taken before a later argument reassigns it, if values,
loop break values, a discarded text call, and owned text returned up 4000
frames. A module `fn display` returning Str. Str entry results, quoted and
empty.

Refusals: subtraction, multiplication, remainder, bit and, wrapping add,
negation, complement and shift on text, plus a trap whose operands print
and mutate before it fires.

## Grill Log

- **Q:** Why 4000 frames and not more? **A:** The call-depth limit is 4096;
  past it both sides stop with E7002, which the function corpus already covers.
- **Q:** Why no methods here? **A:** Str methods are the next slice; their
  results need Char, Option and Array.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Text Runtime]] · [[src/_MOC]]
