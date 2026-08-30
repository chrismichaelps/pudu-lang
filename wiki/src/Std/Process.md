---
type: module
path: "@root/lib/Std/Process.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, process]
aliases: [Std Process]
---
# Std Process
## Purpose
Run subprocesses and expose exit status, standard output, and standard error as data.
## Interface
Exports `Finished`, `run`, `withInput`, output/line/status conveniences, availability and success predicates, and rendering helpers.
## Governance and algorithm
Execution is the prelude process effect; wrappers propagate host failure with `?` and never reinterpret a nonzero child status as failure to launch.
## Grill Log
- **Q:** Why is child status inside `Finished`? **A:** A process that ran and exited nonzero is an observed result, distinct from failing to start it. _Rejected:_ collapsing both into one string error.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
