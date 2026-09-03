---
type: module
path: "@root/lib/Std/App/Work.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, scheduling, background]
aliases: [Std App Work]
---
# Std App Work
## Purpose
The work a service does when nobody asked: what runs, how often, and what happens when one fails.
## Interface
A job: what it is called, what it does, and when it is due. When that is: after a delay, at an
interval measured from the end of the last run, or at an interval measured from its start. A
schedule, which is jobs. Which jobs are due at a moment, and the schedule that follows running them.
What a schedule has recorded — how many times each job ran, how many times it failed, how long the
last run took, and what it last said when it failed. Running a schedule once, and the stage that
runs it until the program stops.
## Governance and algorithm
**Which jobs are due is a pure function of the schedule and the moment.** Nothing here reads a clock;
the moment is given. So a schedule is checked by asking what is due at a time and comparing values,
rather than by waiting — and a job that should run hourly can be tested in a millisecond.

**A job still running when its next turn arrives does not start a second.** Two runs of a job that
writes something is a race nobody designed, and it is the failure that shows up as duplicated
records rather than as an error. The turn is skipped, and skipping is counted so a job that never
finishes in time is visible rather than merely slow.

**Where the interval is measured from is stated per job, because the two are different.** Measured
from the end of the last run, a job that takes longer than its interval simply runs less often.
Measured from the start, it keeps its cadence and the skips above are what absorb the overrun. A
scheduler offering only one of these is wrong for half the jobs it is given.

**A job that fails is recorded and runs again.** One failure is not a reason to stop scheduling
something forever — a nightly job that failed once because a database was restarting must not be
silently dead until somebody notices the reports stopped. The failure count and the last thing it
said are kept, so a job that always fails is visible without being fatal.

**Nothing is retried faster than its interval.** A job that fails is not immediately re-run: that
turns one failing dependency into a tight loop against it, which is how a struggling service is
finished off by its own clients.
## Grill Log
- **Q:** Stop scheduling a job after it fails? **A:** No; record and continue. _Rationale:_ a job
  that stops after one bad night is dead until somebody notices the absence of its output, and
  absence is the hardest thing to notice. _Rejected:_ stopping on failure; a failure threshold,
  which is the same thing with a delay.
- **Q:** Retry a failed job immediately? **A:** No. _Rationale:_ that turns one failing dependency
  into a tight loop against it. The next turn comes when it comes. _Rejected:_ immediate retry;
  backoff, which is a policy a program can write over a job that needs it.
- **Q:** Let a job start while the previous run is going? **A:** No. _Rationale:_ two runs of a job
  that writes is a race nobody designed, and it appears as duplicated work rather than as an error.
  _Rejected:_ overlapping runs; a per-job concurrency limit, which is the same question with more
  ways to get it wrong.
- **Q:** Offer one kind of interval? **A:** No; both, stated per job. _Rationale:_ measured from the
  end and measured from the start answer different needs, and a scheduler with one is wrong for
  half its jobs. _Rejected:_ choosing one.
- **Q:** Read the clock here? **A:** No. _Rationale:_ then a schedule can only be tested by waiting,
  and an hourly job cannot be tested at all. _Rejected:_ an internal clock.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Concurrent]] · [[Std App Metrics]]
