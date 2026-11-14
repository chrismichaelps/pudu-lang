---
type: handoff
status: ACTIVE
issue: 499
aliases: [Native Frame Pressure Repair]
tags: [handoff, native, backend, recursion]
---
# Native Frame Pressure Repair

## Validated local integration — 2026-10-18

All 19 clean repository gates pass with GHC 9.14.1 -Werror, including all 669
test groups and the formerly failing pressure case. A separate production
native run using AddressSanitizer/UBSan and PUDU_EVAL=tree passes all 20 matching
groups. The ordinary full suite uses the compiled evaluator. Actual CLI builds
under sanitizers match both engines on exact deferred values and argument
snapshots. Real -M32m CLI heap exhaustion in both modes yields only the shared
host line and status 1. The five README progress tests and freshness check pass;
coverage is now 4/14 completed areas (28%). No fixed-property repeat count is
presented as independent generated programs.

Durable local evidence: ~/.codex/tmp/pudu-499-20261018-validation/gates.log,
4.log, native-sanitized-tree.log, native-sanitized-summary.json,
real-heap-failure.json and cli-parity.json. The actual process handles were
observed to exit 0. Scoped wiki-link/private-ignore/whitespace checks pass.
No subagents execute, no push/PR/merge is performed, and no independent review
or other-platform execution is claimed.

The exact carrier and frame calling convention are one coherent local
integration: committing only the former would retain the known pressure crash.
PR review partitioning remains required before promotion; the local checkpoint
does not waive the repository's review-size or independent-review gates.
Exact next action: resolve #497 fixed signed-width admission in the vault using
the revision-5 exact carrier, then start its bounded implementation. Preserve
every remaining numeric, aggregate, module, resource and concurrency obligation
of the full 100% objective.

## Current integration checkpoint — 2026-10-18

The production CLI now lowers Core through lowerFrames and emits constant-arity
step bodies plus the checked heap-frame dispatcher. Runtime revision is 5.
Source panics and memory failures run a scalar-frame cleanup hook. Native
calloc failure/size overflow and catchable CLI HeapOverflow share the literal
host message and status 1; no Pudu error code or source span is invented.
StackOverflow, ThreadKilled and UserInterrupt retain their existing behavior.

Before the host restart, focused production native function failures (including
the permanent wide-pressure regression), allocation/cleanup injection tests,
host-exception tests and a real CLI -M32m heap-exhaustion probe passed. Their
temporary /tmp captures no longer exist; do not treat those paths as durable
current-state evidence. No validation process survived the restart, as verified
from the process inventory. Source edits and mirrors remain in the worktree.

A fresh clean 19-gate run is active, captured under
~/.codex/tmp/pudu-499-20261018-validation/ with the repository's commands and
cleanup unchanged. No subagents execute. Exact next action: finish that run,
resolve any semantic failure, then run the native corpus through the production
allocator with AddressSanitizer/UBSan and the tree evaluator as oracle. Do not
promote or claim 100% from these scalar/function gates.

## Allocator integration ownership

Backend Engineer → Language Architect → Runtime Engineer → Tooling Engineer.
Direct owner covers Diagnostic.Host, Cli.Memory, Backend.Runtime.Frame,
Backend.Emit.Frame, runtime cleanup hooks, CLI entry wiring, manifests and
focused host/frame tests. No subagents execute. The shared executable memory
failure contract is a host-level stderr line/status 1, with no new Pudu error.
Catch only catchable HeapOverflow in the CLI; preserve cancellation. Scalar
frame cleanup precedes controlled native exits. Independent review remains
pending before promotion; the complete emission goal remains unchanged.

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

[[Native Execution Frames]] now specifies the local control-flow design. Publish its Core frame-IR and continuation-lowering mirrors before source implementation; the runtime allocation boundary remains explicit.

## Pure frame lowering ownership

Test Engineer → Language Architect → Compiler Engineer. Direct owner covers
Core.Frame, Compiler.Frame, Compiler.Frame.State and Compiler.Frame.Body plus
manifest registration and focused compiler-frame tests. Complete mirrors and
resolved local Grill Logs precede implementation. The control partition has no
allocator and makes no claim that the failing native pressure case is repaired.
Preserve all existing #498 work. No agents execute.

## Pure lowering checkpoint

Compiler Engineer → Backend Engineer. Direct ownership additionally covers
Backend.Emit.Frame.Value/Body and their mirrors/registration. Generate and test
constant-arity step bodies without an allocator; runtime integration and host
allocation failure remain explicit obligations. No subagents execute.

Core.Frame and Compiler.Frame/State/Body are implemented and registered.
Every local read snapshots its slot. Calls retain ordered argument slots,
typed result destinations and distinct resume blocks. Short circuit uses
branches. Returns and resolved loop transfers stop subsequent lowering,
including transfers in while conditions and break operands. The driver checks
that all referenced block destinations are closed before returning a product.

Seven focused FrameSpec groups pass under optimized GHC 9.14.1 -Werror,
including the checked function/integer/control corpora. The test runner repeats
fixed properties; this is not a claim of 1,400 independent generated programs.
Evidence: /tmp/pudu-499-frame-tests.log. All newly added source files remain
below 500 lines. The C emitter has not been switched to FrameModule, so the
permanent native-pressure regression remains unresolved. No full-suite green
claim, integration commit, independent review or promotion follows this pass.

Exact next action: resolve the shared host allocation-failure boundary in
Native Execution Frames, then specify the dispatcher/runtime and frame-emitter
mirrors before replacing recursive generated C calls. Preserve source call
spans, argument-before-depth order and the evaluator's pre-increment depth check.

## Generated step-body checkpoint

Backend.Emit.Frame.Value/Body and FrameEmitSpec are implemented and registered.
Generated bodies take only a frame pointer, return call/return steps and keep
all source-dependent slots and argument scratch outside C automatic storage.
Integer policies and sites reuse existing runtime helpers. Nested-call tests
pin suspension/destination counts and reject direct C body calls. Unsupported
payload slots/descriptors return located FrameFault values.

Ten focused frame groups pass; strict C11 compilation covers 194 checked corpus
translations, once each, with -pedantic -Wall -Wextra -Werror. Log:
/tmp/pudu-499-frame-all-tests.log. An initial type-only harness left call-depth
pudu_fail unreferenced; its dispatch wrapper now performs the real post-step
depth check, with no warning suppression or weakened compiler flags.

The actual generated pressure bodies run with a test-only static arena under
AddressSanitizer/UBSan and match both evaluators byte for byte at E7002 on the
unchanged 8 MiB stack. Probe source: /tmp/pudu-499-frame-dispatch-probe.hs;
generated C: /tmp/pudu-499-frame-pressure.c; report:
/tmp/pudu-499-frame-pressure-proof.json. This fixture does not implement or
validate the production allocator, normal heap reclamation or panic cleanup.
No CLI switch, full-suite green claim, integration commit or independent review.

Exact next action: specify the allocation-failure contract for dispatcher frames
in Native Execution Frames using the audited evaluator/CLI host-error boundary.
Then publish the runtime/allocator mirrors before implementing allocation and
cleanup and switching the existing emitter. Keep the permanent #499 regression
and the full 100% completion objective unchanged. No subagents execute.
