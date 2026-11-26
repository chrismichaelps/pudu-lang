---
type: module
path: "@root/test/Pudu/Backend/KernelCountedPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Kernel Counted Programs]
---
# Backend Kernel Counted Programs

Export `flatTableProgram`, `codecProgram` and `kernelCountedLibraryPrograms`.
`flatTableProgram` and `codecProgram` each take extra trailing lines that run
before the program returns. `kernelCountedLibraryPrograms` lists the flat-table
and JSON/XML/CSV codec programs run to completion.

[[Backend Kernel Programs]] builds its flat-table and codec refusal cases by
appending the refusing lines to these bodies. [[Backend Text Leak Tests]]
runs the completing bodies under the counted-allocation harness.

## Grill Log

- **Q:** Why share bodies instead of copying them? **A:** The refusal case and the counted case must exercise the same kernels; one body keeps them from drifting. Rejected: a second copy of each program.

## Dependencies and consumers

Consumed by [[Backend Kernel Programs]] (refusal cases) and [[Backend Text Leak Tests]] (counted run). Library imports resolve through the library mode described on the leak page.

## Referenced by

[[Backend Kernel Programs]] · [[Backend Text Leak Tests]] · [[Backend Module Map]]
