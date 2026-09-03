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
## What this composes, and what it deliberately does not

An application carries the protective steps, can be told which origins may read
its answers, mounts a health report and its own measurements where the program
says, and starts and stops its stages in order. Those are wired here because
they are framework concerns: a service that lacks them lacks them by accident.

What is deliberately left as a leaf, and why — because an unused module is
either a gap or a decision, and these are decisions:

- [[Std App Access]] builds a router; a program hands the result here. The
  framework does not choose a program's authorisation model, and wiring one in
  would mean choosing.
- [[Std App Password]] and [[Std App Session]] are what a program's own sign-in
  handler uses. Forcing either would settle how a service authenticates, which
  is the program's decision and not this one's.
- [[Std Db Migrate]] and [[Std Db]] are reached from a stage the program writes,
  which is five lines. The alternative is for every program that never touches
  a database to carry one.
- [[Std Http Client]] is what a handler calls out with; nothing here needs it.

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
- **Q:** Leave the protective steps to each program? **A:** No; they are part of
  the application. _Rationale:_ [[ADR-0017 What the Web Layer Refuses]] says the
  protections are on and turned off deliberately, and for a while that was only
  true of the steps themselves — a service built the ordinary way here got none
  of them, because nothing wired them. A default that has to be remembered is
  not a default. _Rejected:_ documenting the step and leaving it out.
- **Q:** Mount the health and metrics routes automatically? **A:** No; the
  program writes the path. _Rationale:_ an endpoint that appears without being
  written is one nobody decided to expose, and the mechanism that publishes a
  health report publishes an environment dump beside it. _Rejected:_ fixed paths.
- **Q:** Stop at the first failure when stopping? **A:** No. _Rationale:_ one resource failing to
  close is not a reason to leak the next. _Rejected:_ short-circuiting stop.
## Referenced by
[[src/Std/_MOC]] · [[ADR-0016 An Application Is a Value]] · [[Std App Config]] · [[Std App Health]] · [[Std Http Server]]
