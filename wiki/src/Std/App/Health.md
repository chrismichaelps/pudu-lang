---
type: module
path: "@root/lib/Std/App/Health.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, health, probes]
aliases: [Std App Health]
---
# Std App Health
## Purpose
The two different questions something outside the process asks, kept different.
## Interface
A verdict, and what it was about. A liveness check: a name and a judgement over a reading the
program supplies. A readiness check: a name and a judgement that may consult whatever it needs. The
aggregate of each, and the verdict the aggregate reaches. Rendering a report. The status code each
verdict answers with.
## Governance and algorithm
**They are two questions and they have two types.** *Should this process be restarted?* must not
consult anything outside the process: a database being unreachable is not a reason to kill a healthy
program, and a check that consults one turns a dependency's outage into a restart storm across every
instance at once. *Should this process receive traffic?* may consult whatever it needs, because
removing an instance from rotation is cheap and reversible.

Established practice states that rule in documentation and relies on the programmer to follow it.
Here the two are separate types with separate constructors, and a liveness judgement is given a
reading rather than a connection — it has nothing to reach with. A program that additionally
declares its judgement `comptime` gets the language's own refusal: reaching a clock, a socket, or a
file from it is a compile error rather than a note in review. That is the strongest form available
and the one to write; the type alone does not carry it once the function is stored, so what the
signature guarantees is that nothing was handed over, and what `comptime` guarantees is that nothing
was reached.

**The reading's accessors are themselves compile-time.** A `comptime` body may call only other
compile-time functions, which is what makes the guarantee transitive rather than a promise each
function makes about itself — so a judgement that reads a count or a flag needs those two to carry
the same restriction. They ask the reading's own map directly rather than going through another
module, which keeps the compile-time claim inside the module that makes it.

**The worst verdict wins.** An aggregate is as healthy as its unhealthiest part, which is the only
aggregation rule that does not eventually report a working service while one of its parts is down.
There is no ordering to configure and no per-check weighting, because both are ways of arranging for
a failure not to count.

**What is reachable from outside is what was routed.** There is no setting listing which endpoints
are published — such a setting accepts a wildcard, and a wildcard is how a program ends up serving
its own environment and memory to the network. A report is a value; a program that wants it served
writes a route for it.
## Grill Log
- **Q:** One kind of check, with a flag saying whether it is used for restarts? **A:** No.
  _Rationale:_ a flag is set at the point the check is registered rather than where it is written,
  so the person who wrote a check that dials a database is not the person who decides it can restart
  the process. Two types put the decision where the code is. _Rejected:_ a single check with a role.
- **Q:** Let a check say how much it counts toward the whole? **A:** No. _Rationale:_ every weighting
  scheme is a way of arranging for a failure not to count, and the failure still happened.
  _Rejected:_ weighted aggregation; a quorum.
- **Q:** Publish the report at a fixed path automatically? **A:** No. _Rationale:_ an endpoint that
  appears without being written is one nobody decided to expose, and the same mechanism is what
  publishes an environment dump next to it. _Rejected:_ automatic mounting.
- **Q:** Cache a readiness result? **A:** Not here. _Rationale:_ how stale an answer may be is a
  property of the deployment, and a cache inside this module would be one every program shared.
  _Rejected:_ a fixed interval.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[ADR-0016 An Application Is a Value]] · [[architecture/WEB]]
