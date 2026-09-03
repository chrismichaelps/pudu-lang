---
type: module
path: "@root/lib/Std/App/Cache.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, caching]
aliases: [Std App Cache]
---
# Std App Cache
## Purpose
Keep an answer for a while, and say plainly when the one being handed back is old.
## Interface
A cache: bounded, with a lifetime for what it holds and a shorter one for what it remembers was
absent. Looking something up, which answers fresh, stale, or nothing at all. Keeping an answer, and
keeping the fact that there was none. Forgetting one, and forgetting everything past its lifetime.
How much it holds, and how often it has been able to answer.
## Governance and algorithm
**A lookup answers one of three things, not two.** Fresh, stale, or missing. The ordinary interface
answers a value or nothing, which forces a caller to treat an expired entry as an absent one — and
that is what causes the failure this module is most for. When a much-read key expires, every request
that wanted it finds nothing and every one of them goes to recompute it, all at once, against
whatever was being protected. Told the entry is stale, a caller can hand back the old answer and
refresh once. The three-state answer is the whole design; everything else here is bookkeeping.

**What was absent is remembered too, and for less time.** A key that is not there, looked up
repeatedly, is a hot path to whatever would have answered — and the answer is always the same. It is
kept for a shorter time than a real answer, because being wrong about an absence costs less than
being wrong about a value, and because the thing most likely to change is a key that does not exist
yet.

**The clock is given rather than read**, as everywhere else here, so what a cache does at a moment is
a comparison of values and an entry with an hour's lifetime is checked in a millisecond.

**Bounded, and the bound is on entries rather than on bytes.** A cache without a bound is a leak
whose speed depends on how many distinct keys arrive, which is a property of the traffic rather than
of the program. Entries rather than bytes because the size of a value here is not something this
module can know, and a bound it cannot enforce would be a claim rather than a bound.
## Grill Log
- **Q:** Answer a value or nothing, as a cache usually does? **A:** No — fresh, stale, or nothing.
  _Rationale:_ two answers force a caller to treat an expired entry as absent, and that is exactly
  what makes every request for a hot key recompute it at the same moment. The third answer is what
  lets one refresh happen while the rest are served. _Rejected:_ an optional value; an expiry the
  caller has to check separately, which is the same mistake with more steps.
- **Q:** Refresh a stale entry here? **A:** No; say it is stale and let the caller decide.
  _Rationale:_ refreshing means calling something, and a cache that calls things has to know about
  failure, timeouts, and what may be called from where. It answers what it holds; the program
  decides what that is worth. _Rejected:_ a loading cache.
- **Q:** Remember that something was absent? **A:** Yes, for less time. _Rationale:_ a key that does
  not exist, looked up repeatedly, is a hot path to whatever would have answered, and the answer
  never changes. Less time because a key that does not exist yet is the thing most likely to start
  existing. _Rejected:_ not caching absence; caching it for as long as a value.
- **Q:** Bound by bytes? **A:** No, by entries. _Rationale:_ the size of a value is not something
  this can know, and a bound it cannot enforce is a claim. _Rejected:_ a byte bound.
## Referenced by
[[src/Std/_MOC]] · [[Std LruCache]] · [[Std App]] · [[architecture/WEB]]
