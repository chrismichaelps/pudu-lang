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

Records come back by value from the C library (`div`, `ldiv`) (#852); record parameters, nested records, text fields and a missing text field were checked against a built library by hand.

## Handles (#853)

The success corpus uses a temporary C stream to exercise an owned handle in a
live call and release it through a status-returning function. A borrowed error
string is used as an opaque handle. Refusal programs cover null results
(E7020), use after release, double release, and release of a borrowed handle
(E7022). A missing release symbol (E7015) must take precedence over the null
result the producer would return. Two declarations of one C symbol exercise
distinct borrowed and owned wrappers. The differential harness compares output,
rendered diagnostics with their source spans, and exit status.

Resolved Grill Log: use libc so the corpus has no external library or display
dependency. An empty path makes `fopen` fail without touching any file. Use a
read-only status function for the borrowed-release refusal so an erroneous
dispatch is observable without freeing libc-owned storage.

## Referenced by

[[Backend Native Tests]] · [[Native Foreign Call Sites]]
