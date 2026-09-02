---
type: module
path: "@root/lib/Std/App.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, lifecycle]
aliases: [Std App]
---
# Std App
## Purpose
The program itself as a value: what it is made of, what starts it, and what stops it.
## Interface
`serve` — a name and a router, and a service is running: configuration found, health answered,
stopping graceful. That is the whole of the interface a first program needs.

Beneath it, for a program that outgrew one call: `web` builds the same application without running
it, `with` adds a stage, `start`, `stop`, and `run` drive one, and `stagesOf`, `configOf`, and
`routerOf` read one back. A `Stage` names what to start and how to stop it. A `Report` names the
stage that failed rather than only saying that one did.
## Governance and algorithm
**One call, then a way down.** `serve` is not a wrapper written for demonstrations; it is the
default path, and it is composed of exactly the pieces below it, so a program that starts there and
later needs a migration stage adds one without rewriting what it had. Nothing is hidden that has to
be un-hidden: `serve` is a short function whose body is the same `web`, `with`, and `run` a program
would have written. What makes it short is that the defaults are real defaults rather than absences
— a port, a health route, and a stop that waits are what a service wants, so they are what it gets
without asking.


Start runs the stages in the order they were added; stop runs them in reverse, so a pool opened
after the migration that used a connection closes before that connection. Nothing infers an order
from what a stage needs, because a written order can be read without running the program and an
inferred one cannot. A stage that fails to start stops every stage already started, in reverse, so a
program that cannot come up does not leave half of itself running — the failure is reported after
that unwinding rather than before it, since a caller told a start failed will not then be told to
clean up. Stop attempts every stage even after one fails, because a second failure is not a reason
to leak the third resource; every failure is collected and reported together.

An application does not read a clock, a file, or an environment when it is built. It is a value, so
a test builds one, reads its stages and its routes, and never binds a port; the same value started
in a test and in production differs only in the configuration it was handed.
## Grill Log
- **Q:** Make the explicit form the only form, since it is the honest one? **A:** No. _Rationale:_ a
  framework whose smallest program is twenty lines of wiring loses to one whose smallest program is
  one line, and it loses for a good reason — most of that wiring is the same every time. The answer
  is not to hide the wiring but to ship the common arrangement of it as a value. _Rejected:_
  requiring every program to assemble its own stages.
- **Q:** Give `serve` options for everything it defaults? **A:** No. _Rationale:_ that grows one call
  into the whole interface and reintroduces the ceremony it exists to remove. A program needing
  something `serve` does not offer drops to `web` and `with`, which is one step rather than a
  cliff. _Rejected:_ an options record on `serve`.
- **Q:** Infer stage order from what each stage needs? **A:** No. _Rationale:_ that is the container
  model's inferred order, and it needs a directive to correct it in exactly the cases that matter.
  A list is legible without running anything. _Rejected:_ a dependency-ordered start.
- **Q:** Keep a registry of components keyed by type? **A:** No. _Rationale:_ a dependency is a
  parameter, and a missing parameter is a type error at the place it is missing; a registry moves
  that failure to where the registry is built and stops it being a type error. See
  [[ADR-0016 An Application Is a Value]]. _Rejected:_ a typed component registry.
- **Q:** Stop at the first failure when stopping? **A:** No. _Rationale:_ one resource failing to
  close is not a reason to leak the next. _Rejected:_ short-circuiting stop.
## Referenced by
[[src/Std/_MOC]] · [[ADR-0016 An Application Is a Value]] · [[Std App Config]] · [[Std App Health]] · [[Std Http Server]]
