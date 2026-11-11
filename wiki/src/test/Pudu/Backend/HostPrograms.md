---
type: module
path: "@root/test/Pudu/Backend/HostPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Host Programs]
---
# Backend Host Programs

Export hostSuccessPrograms, hostCountedPrograms and hostRefusalPrograms: the
float and lane kernels, clocks and surroundings, files and handles, cells,
locks, channels and threads, tasks and scopes, and tables of functions.
Counted programs also run under the counted-allocation harness; refusal
programs pin failures inside tasks, scopes and kernels with their spans.

## Resolved Grill Log

Every expectation is what the interpreter prints for the same program.
Programs that read the clock or the machine assert relations, never values.

## Referenced by

[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Native Host Services]]
