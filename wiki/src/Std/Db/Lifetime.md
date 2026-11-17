---
type: module
path: "@root/lib/Std/Db/Lifetime.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, database, pool, lifetime]
aliases: [Std Db Lifetime]
---
# Std Db Lifetime
## Purpose
Decide, for each pooled connection about to be lent, whether to keep it, check it with a trivial
question first, or replace it.
## Interface
`Policy` holds three limits in milliseconds: `maxLifetimeMillis`, `maxIdleMillis`, and
`probeAfterMillis`. A zero limit turns that limit off. `Verdict` is `Keep`, `Probe`, or `Replace`.
`DEFAULT_POLICY` allows thirty minutes of life, ten minutes idle, and a probe after thirty seconds
idle. `never()` returns a policy with every limit off. `verdict(policy, stream, now)` gives the
verdict for a connection at the time `now`.
## Governance and algorithm
The verdict is computed from two stamps on the connection: `opened` and `returned`, both taken from
the elapsed-time clock. Age is `now - opened`, and idle time is `now - returned`.

The checks run in a fixed order. Lifetime is checked first, then idle time for replacement, then the
probe threshold. The first check that applies decides the verdict. A connection past its lifetime or
its idle limit is replaced. A connection that has been idle long enough to doubt is probed. Anything
else is kept.

A probe exists because a connection can die without telling the pool. The server may restart, or a
network device between the two may drop the mapping and say nothing. Such a connection still looks
open until the next write fails, and the caller who receives it is the one who pays for the failure.
A probe after a period of idleness finds the dead connection while the pool still has the choice of
replacing it, before any caller has been handed it. A probe that fails replaces the connection, so
a failed probe is never lent.

[[Std Db]] applies the verdict inside `withConnectionWithin`, before the connection is lent.
## Grill Log
- **Q:** Probe a connection on every lend? **A:** No. _Rationale:_ a round trip on every borrow adds
  latency to the common case where the connection is fine. A probe is needed only after a connection
  has sat idle long enough that it may have died. _Rejected:_ probing on every lend; probing only
  after a failed request, which has already cost the caller.
- **Q:** Check idle time before lifetime? **A:** No. Lifetime is checked first because it is the
  stronger reason. A connection that is both old and idle must be replaced, and checking idle first
  could return a probe for a connection that is about to be replaced anyway, wasting a round trip.
  _Rejected:_ idle first, which orders the checks by the cheaper signal rather than the stronger one.
- **Q:** Use zero to disable a limit? **A:** Yes. _Rationale:_ a literal zero age would replace every
  connection at once, so zero cannot mean a real bound. Treating zero as off gives `never()` a
  representation with no separate type or flag. _Rejected:_ separate boolean switches per limit, which
  doubles the fields a caller must set consistently.
- **Q:** Probe only at the probe threshold and never replace on idle time? **A:** No. A connection idle
  for a long time has a higher chance of having died, and the idle limit bounds how long a stale
  connection can wait in the pool before it is discarded. _Rejected:_ a single probe threshold with no
  idle replacement.
## Referenced by
[[src/Std/_MOC]] · [[Std Db]] · [[Std Db Session]]
