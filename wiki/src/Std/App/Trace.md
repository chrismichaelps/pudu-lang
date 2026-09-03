---
type: module
path: "@root/lib/Std/App/Trace.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, tracing, observability]
aliases: [Std App Trace]
---
# Std App Trace
## Purpose
Follow one piece of work across every service that touched it.
## Interface
A trace: what the whole piece of work is called, what this step in it is called, and whether it is
being recorded. Continuing one from what a request carried, and starting one when a request carried
nothing. A step within a trace, for the work this service hands on. The header a trace travels in,
read and written. A span: a named stretch of work, when it began and ended, and what was noted
about it. The step that puts a trace on every request.
## Governance and algorithm
**A trace that cannot be read starts a new one; it never refuses the request.** This is the decision
that separates this module from the ones beside it. Everywhere else here, something that cannot be
read is refused — a malformed body, a header carrying a line break, a name that is a path. Tracing
is the opposite: it exists to explain what happened, and a service that returns an error because it
could not parse a diagnostic header has made the diagnosis into the outage. A header that is
nonsense, truncated, or from a version this does not know is treated as no header at all.

**The recording decision travels and is not retaken.** Whether a piece of work is being recorded is
decided once, where it entered, and every service after that obeys it. A service that decided again
would record the first half of a piece of work and not the second, which is worse than recording
neither — a trace missing its middle looks like a service that stopped answering.

**Identifiers come from the machine's entropy and are never all zeros.** The all-zero identifier is
what the format uses to mean "absent", so generating one would produce a trace nothing can follow.
Failing to reach entropy yields a trace that is not recorded rather than a failure, for the same
reason as above: tracing must not be able to stop the work.

**What is noted about a span is text, and nothing is noted automatically.** A span carries what a
program put on it. Nothing here reads a request and decides what is worth recording, because what is
worth recording is what the program knows and this module does not — and a field added automatically
is a field nobody chose, which is how a trace comes to carry a password.

**The clock is given rather than read**, as everywhere else here, so a span's duration is a
comparison of values and a trace can be built in a test without time passing.
## Grill Log
- **Q:** Refuse a request whose trace header cannot be read? **A:** No — and this is the one place
  here where malformed input is not refused. _Rationale:_ the header is a diagnostic, and a service
  that fails a request because a diagnostic was malformed has turned the diagnosis into the outage.
  _Rejected:_ refusing; reporting a diagnostic to the caller.
- **Q:** Let each service decide whether to record? **A:** No; the decision travels. _Rationale:_ a
  trace recorded in one service and not the next is missing its middle, which reads as a service
  that stopped answering rather than as a sampling choice. _Rejected:_ per-service sampling.
- **Q:** Note the request's path and headers on the span automatically? **A:** No. _Rationale:_ a
  field added automatically is a field nobody chose, and that is how an authorization header ends up
  in a trace that is shipped somewhere else. _Rejected:_ automatic attributes.
- **Q:** Generate an identifier without entropy when none is available? **A:** No; the trace is
  simply not recorded. _Rationale:_ a predictable identifier collides, and two pieces of work under
  one identifier is a trace that describes neither. _Rejected:_ a clock-derived identifier.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Http Server Guard]] · [[Std Log]] · [[Std Random]]
