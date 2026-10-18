---
type: handoff
status: ACTIVE
issue: 499
aliases: [Native Frame Pressure Repair]
tags: [handoff, native, backend, recursion]
---
# Native Frame Pressure Repair

## Current state and ownership

Delivery Owner → Language Architect → Test Engineer. Direct owner covers the
frame-pressure case in [[Backend Function Programs]] and its matching mirror;
no subagents execute. Preserve all other work, including the uncommitted #498
exact-carrier integration and unrelated dist-ticky. This test-only partition
must not be presented as completed emission or production-ready integration.

The current worktree is feature/499-native-frame-pressure, stacked on 83f6c6cb.
It was branched from the uncommitted #498 integration without discarding files.
The exact integer runtime/caller changes are uncommitted. Their ordinary and
deferred tests, eight CLI tree/compiled/native probes and 37,980 independent
C11/UBSan runtime checks pass. All 19 existing clean gates and 656 groups passed
before adding this missing pressure case. Those gates did not prove recursion
frame safety.

## Authoritative failure

A program with 96 integer parameters live across recursion, n=4200, and no
unsupported syntax exits natively with SIGSEGV (-11) and empty stderr on the
local 8 MiB stack. Tree and compiled evaluation both exit 1 with E7002 at the
recursive call. The stack limit was not changed. Child core dumps alone were
disabled in the local probe.

Local reproducer: /tmp/pudu-498-recursion-pressure-probe.py. Generated source
and executable root: /tmp/pudu-498-stack-root. Captured results:
/tmp/pudu-498-recursion-pressure.json. The permanent regression now runs through
the normal native function-failure corpus and fails in the current ABI integration until frame storage
is repaired. Its exact-one test expectation is the interpreter output/status;
no check or threshold is weakened.

## Resolved test Grill Log

- **Q:** Is this source supported by the checker? **A:** Both evaluators execute it to the normal E7002 depth refusal.
- **Q:** Is the probe using an artificially small C stack? **A:** No; it uses the host's unchanged 8 MiB default.
- **Q:** May a smaller language bound or a skipped pressure case close the issue? **A:** No; preserve depth timing, argument effects, diagnostics and status.

## Next implementation action

Resolve explicit native frame/continuation storage, with dispatcher-based calls
whose generated C call depth is independent of Pudu recursion. Read the actual
allocation/failure and cleanup vocabulary before deciding that runtime boundary;
do not invent a mismatched error or silently fall back to interpretation.
Publish complete new/affected Core, lowering, runtime and emitter mirrors with
resolved Grill Logs before implementation. Keep #498 ABI integration unpromoted
until #499 passes this regression, existing suites, platform checks and independent
architecture/implementation/wiki review. The full 100% goal remains active.

## Referenced by

[[handoffs/_MOC]] · [[Native C11 Backend Delivery]] · [[Native Emission Coverage]]

## Regression checkpoint evidence

Optimized GHC 9.14.1 -Werror compilation succeeds. The focused native function
failure property exits 1 and reproduces the interpreter-E7002/native-empty-stderr
mismatch at the named wide-frame case. Capture: /tmp/pudu-499-regression.log;
build: /tmp/pudu-499-regression-build.log. The test-only commit intentionally
captures this failing integration regression; it does not stage the uncommitted
runtime/ABI implementation. Do not claim that the prior 656-group green run
includes this newly added failure.

An allocation-vocabulary audit found withRuntimeEnv uses bracketed resource
lifetimes but no dedicated shared HeapOverflow/allocation-refusal mapping in
Diagnostic.Evaluation. Resolve that boundary explicitly before runtime frame
allocation; the pure control-flow/continuation contracts can be specified
independently. Source call argument snapshots and exact E7002 pre-increment
timing remain non-negotiable. No lowered bound, larger host-stack workaround,
permanent E6001 restriction or interpreter fallback closes #499.
