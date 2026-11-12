---
type: module
path: "@root/test/Pudu/Backend/ForeignPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Foreign Programs]
---
# Backend Foreign Programs

Export foreignSuccessPrograms and foreignRefusalPrograms (#850). The success
program reaches the C library through `c` with Int32, Int64 and Float64
crossings and a renamed symbol; the refusals stop with E7015 for a library that
does not open (every candidate named, in order) and a symbol the library does
not export. The native harness compares each with the interpreter's bridge.

Resolved Grill Log: the corpus calls only the C library and names that cannot
exist, so it runs on any machine without building a library; every crossing
width, both float widths, Bool and a unit result were checked against a built
library by hand ([[Native Foreign Call Sites]]).

Text and lent bytes cross to the C library (`strlen`, `strchr`, `strnlen`, `memcmp`, `strerror`), and text holding a nought (E7017) and a missing text result (E7024) stop as the bridge does (#851).

## Referenced by

[[Backend Native Tests]] · [[Native Foreign Call Sites]]
