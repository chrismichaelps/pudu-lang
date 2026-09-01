---
type: module
path: "@root/lib/Std/Test.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.7
tags: [module, stdlib, medium]
aliases: [Std Test]
---

# Std Test

## Purpose

Checks and suites as values, and a report that says what failed, where, and what it expected.

## Interface

37 exports: the `Outcome`, `Check`, `Suite` and `Report` types; check constructors (`that`, `not`,
`equals`, `differs`, `present`, `absent`, `succeeded`, `errored`, `contains`, `all`, `sameElements`,
`closeTo`, `todo`); suite building (`suite`, `group`, `withCheck`, `withGroup`); inspection (`held`,
`pending`, `names`); running (`run`); and reading a report (`passedOf`, `failedOf`, `pendingOf`,
`failuresOf`, `total`, `passed`, `status`, `summary`, `lines`, `rendered`, `combine`, `combineAll`).

### Governance

- **A check is a value and running a suite is a pure function.** Nothing throws, nothing is
  discovered by reflection, and nothing is written. That is what lets a suite be built
  programmatically, inspected before it runs, run twice with the same answer, and — the test of the
  design — checked by comparing reports.
- **Every failure is collected.** A framework whose assertion aborts tells a reader about one
  failure per run. Here a failing check is a value beside its siblings, so one run reports all of
  them.
- A failure says **what it expected and what it found**. A suite answering "thirty-nine of forty"
  has told the reader the least useful true thing about their program.
- A failure is named by the **path** that reaches it, so it says where to look.
- A **pending** check is neither a pass nor a failure and is counted apart. Counting it as a pass
  would let a suite quietly shrink by deleting what has not been done.
- `total` counts what ran, so a pending check does not make a suite look larger for work not done.
- An **empty suite passes**, because it asserted nothing and nothing it asserted was wrong. The
  count is what tells a reader nothing ran, which is why the count is reported beside the verdict.
- `status` is zero only when every check held. A runner that always leaves zero is one nothing can
  be built on.

### Linkage

- **Requires:** [[Std Decimal]], [[Std Fmt]], [[Std List]], [[Std Order]], [[Std Text]].
- **Consumed by:** programs. [[Std Test Property]] extends it with generated values.

## Algorithm

One walk over the suite tree accumulating three counts and the failure lines, with the path carried
down. Rendering is separate and reads only the report.

## Negative Logic (Prohibited Paths)

- No panic on a failing check; a failure is a value, not an exit.
- No reflection or automatic discovery; a suite is built by the program.
- No writing: running answers a report and [[Std Out]] writes it.
- No pending check counted among the passes.
- No clock, no ambient state, and nothing that makes two runs of the same suite differ.

## Edge Cases

- An empty suite passes and reports that no checks ran.
- A group with no checks contributes nothing but its name to the paths beneath it.
- `all` names the first value that failed, not the number that did.
- `sameElements` compares sorted copies, so a repeated value must be repeated on both sides.
- `closeTo` takes `Decimal`, since a tolerance is usually wanted for a figure a float already got
  wrong.

## Depth

DEPTH 0.45 (MEDIUM). One tree walk, three counts, and a vocabulary of checks over them.

## Grill Log

- **Q:** Why is a check a value rather than something that throws? **A:** Because throwing reports
  one failure per run and loses the rest. _Rationale:_ a value sits beside its siblings, so a single
  run says everything that is wrong; it also makes a suite inspectable before it runs and makes this
  module testable by comparing reports rather than by reading output. _Rejected:_ an aborting
  assertion, which is what most frameworks do and what forces the run-fix-rerun loop.
- **Q:** Why does an empty suite pass? **A:** Because it asserted nothing, and nothing it asserted
  was wrong. _Rationale:_ the alternative is a verdict that depends on a count, which hides the count
  behind a boolean; reporting both leaves the reader with the fact rather than an interpretation.
  _Rejected:_ failing an empty suite, which makes building one up incrementally report failures that
  are not about the program.
- **Q:** Why count pending separately rather than as a failure? **A:** Because it is not one — it is
  work not yet done, and a suite full of failures for unwritten tests trains a reader to ignore
  failures. _Rationale:_ counting it as a *pass* is the worse error, and was a real defect here
  caught by this module's own fixture. _Rejected:_ both, in favour of a third count.
- **Q:** Why is property testing a separate module? **A:** Because generation and shrinking are a
  different subject from stating an expectation, and together they pass the size the delivery rules
  set. _Rationale:_ the split follows the same seam [[Std Text Parse]] uses — a submodule extending a
  parent that exists — and a reader wanting only assertions imports only those.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Std Test Property]]
