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
Run subprocesses and expose exit status, standard output, and standard error as data; hold running
programs whose streams are read, written, waited for, and stopped; and start programs with a stated
environment and working directory whose lifetime is bounded by the code that started them.
## Interface
Exports `Finished`, `run`, `withInput`, output/line/status conveniences, availability and success
predicates, and rendering helpers. `Started`, `start`, `read`, `readErrors`, `write`, `writeText`,
`closeInput`, `wait`, `waitWithin`, `stop`, `drain`, `within`, and `pipe` hold running programs.
`Launch`, `launch`, and the `Launching` methods `withVariable`, `isolated`, and `inDirectory` describe a
start; `begin` starts one, `runLaunch` runs one to completion, and `withStarted` gives an action a
program that is stopped when the action returns.
## Governance and algorithm
Execution is the prelude process effect; wrappers propagate host failure with `?` and never reinterpret a
nonzero child status as failure to launch.

**A launch states what the program sees.** Variables given with `withVariable` override inherited ones of
the same name. `isolated` gives the program only the variables stated, so a child run in a controlled
environment cannot read a secret the parent holds. `inDirectory` sets the working directory; a missing
directory fails the start. A variable name that is empty or contains `=` is refused before anything
starts, because an operating system would split or drop it without saying so.

**A scoped program cannot outlive its scope.** `withStarted` stops and reaps the program after the action
returns, whether the action succeeded, failed, or the program had already finished, and returns the
action's own answer. This moves the stop from something each caller must remember to something the shape
of the call guarantees.

**Both streams are read at once.** `runLaunch` reads errors on a worker while output is read, so a
program filling one pipe while the caller reads the other cannot stall.
## Grill Log
- **Q:** Why is child status inside `Finished`? **A:** A process that ran and exited nonzero is an
  observed result, distinct from failing to start it. _Rejected:_ collapsing both into one string error.
- **Q:** Pass environment and directory as positional arguments? **A:** No. _Rationale:_ five positional
  values read as a call rather than as what changed. _Rejected:_ a wide `start`; a `Launch` changed by
  methods.
- **Q:** Inherit the parent environment when variables are given? **A:** Yes, unless `isolated`.
  _Rationale:_ most children need `PATH` and locale; isolation is the explicit choice for untrusted
  environments. _Rejected:_ implicit isolation that breaks ordinary tools.
- **Q:** Leave stopping to the caller of `begin`? **A:** For `begin`, yes; `withStarted` exists so it need
  not be. _Rejected:_ relying on evaluator teardown to stop children a scope abandoned.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[First Release Readiness]]
