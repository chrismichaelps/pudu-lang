---
type: handoff
status: ACTIVE
issue: 499
aliases: [Native C11 Backend Delivery]
tags: [handoff, backend, native, c11]
---
# Native C11 Backend Delivery

## Current continuation — 2026-10-18

[[Native Frame Pressure Repair]] now has a validated local revision-5 exact
integer/frame integration: all 19 clean gates, 669 groups, production native
AddressSanitizer/UBSan checks against the tree evaluator, controlled allocation
cleanup and real CLI host-memory checks pass. README coverage is 4/14 areas,
28%. Independent reviews, PR partitioning, platform evidence and full emission
coverage remain pending. No subagents execute. Exact next action: resolve #497
canonical fixed signed-width admission against the new carrier before source
changes, then continue the full coverage ledger rather than treating this
scalar/function repair as completion.

Issue #486 delivered milestone 1 (PR #487, stacked on #485 until it merges).
Issue #488 continues the same backend with milestone 2: user-defined
functions, calls, recursion, and the evaluator's call-depth refusal. The user
authorizes production-level emission, not a minimal sketch: deterministic C11,
checked arithmetic with interpreter-parity diagnostics, a bounded toolchain
seam, and differential conformance tests.

Transitions: Delivery Owner → Language Architect (semantic surfaces: required
annotations, call-depth parity) → Backend Engineer (lowering, emission, runtime and process fixes) → Independent Reviewer → Forensic Guardian (wiki parity). Delivery
Owner owns [[Compiler Lower]], [[Compiler Lower Body]], [[Backend Emit]],
[[Backend Runtime]], [[Pudu Core]], [[Diagnostic Evaluation]], and the two
backend test specs. Runtime author owns nothing beyond the call-depth part;
[[Eval Env]] changes are one text-source refactor, not a behavior change.
Agents are not alone; preserve other work.

Resolved Grill Log: the interpreter is the semantic oracle — native output
must equal it byte for byte (stdout, stderr text, exit status), enforced by
differential tests, not by convention. Milestone 2 rules: only functions
reachable from the entry are validated and carried; non-entry functions need
declared `Int`/`Bool` parameter types and `Int`/`Bool`/`()` return types and block bodies; calls
lower left to right and reach the evaluator's depth check through per-callee
wrappers; the entry keeps milestone 1's body-derived `Int`/`()` rule and is
called directly at depth 1; the depth bound is written from
[[Compile Time Limits]] and the `E7002` text from [[Diagnostic Evaluation]], so
neither can drift. Everything outside the subset still refuses with `E6001`,
never silently.

Measured record: milestone 1 — `pudu build Smoke.pudu --native` produces an
executable whose stdout, stderr, and exit status are byte-identical to the
interpreter; Abort1/Abort2 render byte-identical refusals; the 16 new backend
checks pass; the full 628-check suite is green; native Loop
(`bench/eval/Loop.pudu`, 3,000,000 iterations) runs 9.1–12.9 ms (median
~11 ms) with stdout `26999982` and exit 0, a 34,032-byte executable. Milestone
2 — implemented, independently reviewed, and validated locally: 635 optimized property groups pass through both direct execution and Cabal.

Exact next action: run the GHC 9.14.1 CI matrix when the release toolchain is available before production promotion. PR #487
stays open against `feature/483-backend-performance` until #485 merges, then
retargets to `dev`; Language Architect and Forensic Guardian reviews are
pending on it.

---

## Production hardening

Backend Engineer owns emission assembly and integration; bounded implementation assignments own lowering and its mirrors, backend test specs/corpus and mirrors, and the toolchain/process tests and mirrors. Independent Reviewer owns no implementation files. All assignments preserve concurrent edits.

Resolved findings: source-ordered eager evaluation and mutable reads, guarded short circuit, complete reachable wrappers, collision-free Unicode names, explicit entry return types, print Result escape refusals, nested comparison grouping, strict-C11 terminal detection, C11 trigraph-safe literals, and bounded subprocess cleanup.

Local validation is complete. Local compiler is GHC 9.10.3; the grammar's GHC 9.14.1 lock is not installed, so local evidence does not claim that matrix.

## Independent review record

Independent implementation review found and then verified fixes for eager evaluation order, short-circuit argument setup, lost wrapper reachability, Unicode symbol collisions, nested comparison grouping, explicit entry return types, and unbounded toolchain cleanup. Final review reports no remaining P0/P1 findings in lowering, emission, runtime, or toolchain.

Language Architect assessment approves the supported Core ABI and call-depth contract, subject to final validation: no surface syntax or checker policy changes; explicit Int/Bool parameters and Int/Bool/unit results are carried, all unsupported signatures refuse with E6001, and entry depth plus the shared E7002 vocabulary match the interpreter. Unit-valued parameters remain outside this native subset and refuse explicitly.

Forensic Guardian review confirms source/mirror ownership, resolved Grill Logs, module registration, navigation, and changelog parity. Every new implementation module existed in the vault before its source was created.

## Validation evidence

- Clean optimized `-Werror` build passed under the installed GHC 9.10.3.
- Direct execution of the rebuilt optimized test binary passed all 635 property groups with zero failures. Native function, recursion-depth, output, arithmetic diagnostic, and process-lifetime groups passed.
- Real CLI smoke: recursive factorial through `pudu build --native -o <temporary executable>` printed `120`, stderr was empty, exit was 0, and interpreter execution was identical.
- `test/gates.sh` passed dependency-layer checks, formatting, diagnostic-code consistency, atomic permissions, release planning, API coverage, package registry/install, generated projects, CLI lint, LSP session/robustness, watch, documentation, and derive API gates. Its first full-suite and residency invocations failed with their output suppressed by the wrapper; no failure detail is claimed or discarded.
- Captured direct full-suite rerun passed all 635 groups; separate residency rerun passed with streaming peaks approximately 88–91 MiB for 2/20 MiB input and buffered control growing from 92 to 148 MiB. No tests or thresholds were weakened. Final captured `cabal test all --enable-optimization=2 --ghc-options=-Werror --test-show-details=direct` confirmation also passed all 635 groups with exit 0.
- Independent implementation, Language Architect, and Forensic Guardian reviews report no outstanding P0/P1 findings. `git diff --check` passes; new modules have complete mirrors and resolved Grill Logs; private local inputs remain ignored and untracked.
- GHC 9.14.1 release/CI validation was not run: the compiler is not installed and local free disk was below 300 MiB during validation, insufficient to install another GHC runtime. Do not interpret local evidence as a claim about that CI matrix.

Delivery Owner → Commit Owner: commit the validated source, tests, and matching vault pages together on `feature/488-native-functions`, preserving the independent review record above. No push, merge, or release is part of this delivery.

## Commit validation

The pre-commit native-property refresh passed, including function ordering, recursion, diagnostic parity, hostile compiler deadlines, inherited pipes, and live cancellation. Staged whitespace checks pass, including newly tracked modules. The validated implementation and matching vault are committed together; release promotion remains gated on GHC 9.14.1 CI. The unrelated profiling build directory is excluded.

## Continuation toward complete emission

Delivery Owner → Language Architect: expand through independently validated native surfaces in [[Native Emission Coverage]]. The next slice is scalar loop control, including labels, break values and Never branch joins. Continue in this worktree, stacked on the committed #488 implementation. Architect resolved the Core contract before implementation; bounded ownership assignments will cover lowering, emission and tests with independent review.

Issue #489 is ready and owns loop control on `feature/489-native-control-flow`, stacked on #488 because its Core/function machinery is required. Delivery Owner owns Core, manifests and shared vault navigation; Lowering Engineer owns Lower.hs/Lower/* and mirrors; Emission Engineer owns Emit.hs/Emit/* and mirrors; Test Engineer owns backend test specs/corpora and mirrors. Independent Reviewer owns no implementation file. Preserve each other's work; no concurrent shared-file ownership. Exact next action: implement the resolved Core loop contract and run differential control-flow conformance.

## Full-emission goal re-anchor — 2026-10-17

The active user goal is complete C11 emission with non-native behavioral parity, including all implemented language and runtime surfaces. #489 is progress only. The goal remains active until every coverage-ledger obligation is implemented and validated. Code comments stay concise and describe invariants without tutorial narration.

Issue #490 records the verified checker/evaluator disagreement for if-without-else results; #489 keeps an explicit incomplete boundary instead of silently changing behavior. Next architectural seam: feed existing solved CompileResult type/scheme facts into lowering, then publish canonical local declaration and callable-specialization identities for aggregate/generic expansion.

## #489 validation complete

The optimized warnings-as-errors build passes on GHC 9.10.3. Fresh scalar loop-control differential validation passes 40 success programs; two discarded-break arithmetic refusal programs and divergent-entry lower-only checks are included in the suite. The actual-unit noelse cases and mutable unit-local effects were corrected and independently checked against the interpreter; a prior test incorrectly equated checked Unit with runtime Unit and was corrected rather than weakening the refusal boundary. The clean `test/gates.sh` completed with exit 0: all 19 build, suite, dependency, formatting, diagnostic, permissions, release, coverage, residency, package, generated-project, lint, LSP, watch, documentation and derive gates passed on the current sources. Evidence: `/tmp/pudu-489-gates.log` (local validation log).

A GHC 9.14.1 installation was attempted after free space became available, but unpacking and staging exhausted the volume before installation completed. The installer was stopped; only its own named temporary download/unpack/staging directories were removed, restoring space. The installed compiler selection was not changed. Locked-toolchain evidence remains outstanding.

## #490 regression preparation

Language Architect approves correcting no-else if to yield unit on normal completion, consistent with its checked type and existing if-let behavior. Transfers and errors remain unchanged; with-else values remain unchanged. Runtime ownership will cover Eval.hs, Eval/Compile.hs and Eval/Loop/Kernel.hs; derive ownership will cover Derive/Record.hs; backend ownership removes the temporary value admission refusal only after oracle agreement. Before those changes, Test Engineer may create only test/Pudu/Eval/IfUnitSpec.hs and its complete mirror as an unregistered regression family. Existing #489 source stays frozen during its clean validation run.

Delivery Owner → Independent Reviewer → Forensic Guardian: refresh the scoped #489 approval after the clean gates, then commit loop control and its matching vault. The unregistered #490 test family and unrelated profiling directory remain excluded. Full native completion and GHC 9.14.1 validation remain outstanding.

Final #489 review: independent implementation and Language Architect approval report no outstanding P0/P1 findings after the clean gates. Forensic Guardian verified mirrors, registrations, navigation, private-file exclusions and evidence; its requested completed-validation update is recorded above. Exact next action: establish the #490 unit-result contract and repair all evaluator/derive paths before broadening native admission.


## #490 architecture handoff — 2026-10-17

Delivery Owner → Language Architect → Runtime/Semantic/Derive/Backend Engineers.
#489 is committed as f8de1bbc; #490 uses feature/490-if-unit-results stacked on it.
[[ADR-0025-if-without-else-unit-results]] is accepted before implementation and
clarifies normal unit production across every projection. Semantic version
1.0.1-draft records a conformance correction rather than preserving accidental
runtime payload leakage. With-else values and all effects, transfers, diagnostics
and existing cleanup retain their meaning.

Bounded ownership: runtime owns Eval.hs, Eval/Compile.hs, Eval/Loop/Kernel.hs and
mirrors; semantic owns Type/Check/Statement.hs and mirror; derive owns
Derive/Record.hs and mirror; backend owns Lower/Body.hs and mirror; test owns
IfUnitSpec and affected existing backend/derive test modules and mirrors. Delivery
Owner sequences shared manifests/navigation. Architecture owns grammar, semantics,
ADR, coverage ledger and this handoff. Agents are not alone; preserve concurrent
work and resolve every module's Grill Log before editing its implementation.

Resolved Grill Log: discard only a normal then-block result when else is absent;
false yields unit; ordinary sequencing must preserve every unwind and diagnostic.
Literal-true derive folding must preserve unit, and dynamic expected checking
must check resulting unit rather than the discarded branch. Actual boxed-kernel
execution needs a separate admitted-path test. Constant folds use the repaired
oracle. Native value admission broadens only after tree/compiled/kernel agreement.

Exact next action: owners update their complete module mirrors with the resolved
#490 contract, then implement the four execution/transformation repairs and dynamic
context correction with independent regression expectations. No #490 validation is
claimed yet. Full native completion and the GHC 9.14.1 matrix remain outstanding.


## #490 direct continuation

The user requires direct execution without activating subagents. Delivery Owner
continues runtime, derive, checker, backend and test ownership in sequence;
existing edits are preserved. No new agent review is claimed. The architecture
contract was independently resolved before this restriction; final implementation
review remains required before PR promotion.

The focused unit-result run passes explicit tree/compiled results, mutations,
transfers, failures, direct boxed-kernel execution, folded constants, contextual
dynamic rejection and actual generated derive methods. Native admission now uses
the resultless CoreIf boundary for supported branch values. Exact next action:
finish native differential validation, then run the clean complete gates.


Focused #490 evidence: native success/status/refusal/process groups pass, and the
pure no-else admission group passes. Dynamic expectations nested in arrays and
record fields reject the unit result with E3001. A real CLI smoke passes:
`pudu run` and `pudu build --native` both print `taken` once, skip the false
branch, retain mutable unit values, write no stderr and exit 0. The fresh full
optimized warnings-as-errors build passes. The clean gate run passed 18 of 19
gates; the full-suite gate failed with output suppressed by its wrapper. A
captured direct full-suite rerun identified a stale derive expansion snapshot:
the repaired residualizer retains a literal-true no-else conditional around a
labelled break. The inspected diff changes only that wrapper; the refreshed
snapshot passes its 200-run property check. No passing full-suite result is
claimed for #490 until the complete rerun finishes.

The background GHC installer was stopped when the user took over installation.
The user installed and selected GHC 9.14.1 successfully; direct local verification
confirms the version. The optimized warnings-as-errors suite is now building its
first GHC 9.14.1 dependency set with captured output. Locked-toolchain validation
remains unclaimed until that build and its checks finish.
Issue #491 records the next solved-type-input expansion; its design draft is
local preparation only and no #491 source has changed.


Exact next action: diagnose the captured full-suite failure and finish the GHC
9.14.1 optimized warnings-as-errors build and suite before committing #490.
Independent implementation review remains pending before PR promotion; the user
requires continuation without activating subagents.


## #490 locked-toolchain validation complete

Delivery Owner → Validation Owner → Commit Owner. GHC 9.14.1 is installed and
selected, verified directly. A fresh optimized library, test executable and CLI
build passes with warnings treated as errors. The captured complete suite
passes all 648 property groups, including the corrected expansion snapshot,
tree/compiled/boxed unit results, constants, dynamic expectations, generated
derive methods and native control/function/process parity. Evidence:
`/tmp/pudu-490-ghc914.log` and `/tmp/pudu-490-ghc914-build.log`.

Both dependency-layer gates and all 15 remaining post-build integration gates
pass with the GHC 9.14.1 CLI. These are the existing test/gates.sh checks, run
without repeating its build-product deletion after the fresh compiler build.
Evidence: `/tmp/pudu-490-ghc914-layers.log` and
`/tmp/pudu-490-ghc914-integration.log`. A real CLI smoke compares interpreter
and native execution: mutable unit bindings, taken print and skipped print
produce exactly `taken` followed by newline, empty stderr and status 0.

The earlier GHC 9.10.3 captured suite had 647 passing groups and one stale
derive snapshot failure. Its only textual delta was inspected and corrected;
the complete GHC 9.14.1 run above validates the final snapshot and sources.
No check or threshold was weakened. This is local macOS evidence, not a claim
that remote Linux CI or the complete native coverage matrix has passed.

Commit the #490 source, tests and matching vault together. Independent final
implementation review remains pending before PR promotion under the user's
no-subagent restriction. Full native emission remains incomplete.
Exact next action: resolve the #491 solved-checker-type contract in the vault
and its affected module mirrors before implementing scalar signature expansion.

## #491 direct implementation handoff

Delivery Owner → Language Architect → Backend Engineer. #490 is committed as 15409bf4. Work continues stacked on it on feature/491-native-solved-types. The #491 solved-fact contract is resolved in Native Emission Coverage and all affected module mirrors before source edits. Direct owner covers Lower/Types, Lower/State, Lower/Signature, Lower/Body, Lower driver, CLI, Cabal registration and the existing backend tests in sequence. Preserve unrelated profiling outputs. No subagents are activated; independent final implementation review remains pending before promotion.

Exact next action: implement the settled fact input and scalar signature admission, then run focused and complete GHC 9.14.1 validation.

## #491 validation and commit handoff

Delivery Owner → Validation Owner → Commit Owner. Clean GHC 9.14.1 optimized
`-Werror` build and full suite pass. All 19 test/gates.sh gates pass with exit 0
(`/tmp/pudu-491-gates.log`). The expanded native function differential group
passes, including inferred Int/Bool/unit helpers, inferred recursive result,
aliases and annotated mutable locals. Canonical identities, exact source and
generated spans, missing analysis/schemes/expression facts, existing unsupported
surfaces and unresolved inferred result refusals pass their focused checks.

The real CLI native build of inferred/aliased calls and annotated locals matches
`pudu run`: stdout `13` followed by newline, empty stderr and exit 13. Existing
print-carrier and unsupported formed type/default refusals remain. The checker
currently leaves unannotated bare-return helper results unresolved; #491 refuses
those facts explicitly rather than guessing unit. No checker semantics changed.

The direct self-audit is not independent review. Independent implementation,
architecture and wiki review remain pending before promotion under the user's
no-subagent restriction. No remote/platform-wide CI claim is made.
Exact next action: commit #491 and implement the resolved unit-literal/parameter
slice in issue #492, starting with complete affected module mirrors.

## #492 implementation handoff

Delivery Owner → Language Architect → Backend Engineer. #491 is committed as 6a3f296b; feature/492-native-unit-values is stacked on it. The direct owner covers Lower/Body, Lower/Signature, Backend/Emit and their mirrors, the existing EmitSpec/FunctionPrograms and matching mirrors, plus coverage/changelog/handoff. Contracts and resolved Grill Logs above precede implementation. Preserve unrelated profiling output. No subagents are activated; independent review remains pending before promotion.

Exact next action: implement unit literal/parameter admission and effect-first unit call temporaries, then validate success, failure, ordering and the full GHC 9.14.1 gates.

## #492 validation in progress

The GHC 9.14.1 clean optimized warnings-as-errors build passes. Pure unit
signature admission, function success/order/recursion, unit-argument arithmetic
failure and existing refusal groups pass. A real CLI smoke prints 1, 2, 3 in
order with empty stderr and exit 2 through interpreted and native execution.

The clean gate run passes 18 of 19 checks; its full-suite invocation fails with
output discarded by the wrapper. The captured direct diagnostic rerun passes
all 652 property groups with zero failures and exit 0. The same full Cabal test
command is now running with its complete output preserved, before committing
this slice. No first-run failure cause is claimed without evidence and no
threshold or test has been weakened. Exact next action: finish the captured
Cabal confirmation and resolve any reported failure before #492 commit.

## #492 validation complete

Delivery Owner → Validation Owner → Commit Owner. The captured Cabal confirmation
passes all 652 groups and exits 0 (`/tmp/pudu-492-cabal-confirm.log`), matching
the direct captured full-suite pass. The initial gate failure did not reproduce;
its cause remains unknown because the wrapper discarded its output. The clean
optimized GHC 9.14.1 warnings-as-errors build and all other 18 gates passed.
No test or threshold changed between these runs. Focused native successes,
unit argument failure ordering, refusal spans and real CLI parity passed as
recorded above. No remote Linux/platform-wide evidence or independent review
is claimed. Full native coverage remains incomplete.

Exact next action: commit #492 and publish the #493 unit display/equality
contract in all affected mirrors before implementing it. Independent reviews
remain pending before promotion; do not activate subagents.

## #493 direct implementation handoff

Delivery Owner → Language Architect → Backend Engineer. #492 is committed as f0192cfd; feature/493-native-unit-operations is stacked on it. Direct owner covers Lower/Body, Backend/Emit, Backend/Emit/Support, EmitSpec and FunctionPrograms plus their mirrors and shared coverage/changelog/handoff. Complete contracts and resolved Grill Logs precede source edits. No subagents are activated; independent reviews remain pending before promotion.

Exact next action: implement shared unit operand freezing, inline unit display and equality, then run focused and full GHC 9.14.1 validation.

#493 self-audit found that admitting Core unit display/equality also admitted the effect-only print Result carrier. The clean validation run was stopped before any commit; explicit recursive carrier guards and checked-source refusal regressions were added. This is a resolved self-audit finding, not an independent review approval. Exact next action: rebuild and run the new refusal and native groups before restarting clean validation.

#493 current validation: the final source tree passes the fresh optimized
GHC 9.14.1 warnings-as-errors build (clean products were removed before the
interrupted attempt, then compilation resumed after the carrier correction).
Final focused carrier refusals, unit signature/display/equality success, native
effect/transfer ordering and failure groups pass. The full Cabal suite is
running with output captured. The two dependency gates and all 15 post-build
integration gates pass through the original commands with output retained.
Evidence: `/tmp/pudu-493-build.log`, `/tmp/pudu-493-suite.log`,
`/tmp/pudu-493-integration.log`. The temporary wrapper changes output retention
only and does not delete fresh products a second time or weaken any check.
A real CLI unit-operation comparison matches stdout, stderr and status; the
print Result refusal preserves an existing output file.

Issue #494 records the next explicit Core runtime-refusal slice for
checker-accepted invalid scalar operators. Its design must be resolved in
complete mirrors before source edits. The #491 commit spans 613 changed lines;
partition its review before opening a PR under the delivery size gate, preserving
source/wiki parity. No PR, remote CI or independent approval is claimed.

## #493 final validation and commit handoff

Delivery Owner → Validation Owner → Commit Owner. The final full Cabal suite
passes all 652 property groups with zero failures and exit 0. Fresh optimized
GHC 9.14.1 `-Werror` compilation and all 17 remaining dependency/integration
checks pass, accounting for every standard gate without recompiling already
fresh products again. Captured evidence is listed above. The earlier #493
validation attempt was intentionally stopped to fix the self-audited print
Result carrier gap; final regressions prove direct/nested Result display and
equality refuse E6001 while genuine no-else unit display remains accepted.

Unit display/equality native success, effect order, mutation, transfers and
arithmetic failure diagnostics match the interpreter. CLI output/status parity
and preservation of an existing output on Result refusal pass. No snapshots,
checks or thresholds were weakened. All touched implementation/test files are
below 500 lines. Independent implementation, architecture and wiki reviews
remain pending before promotion; no subagents, PR, push or remote CI is claimed.

Full C11 coverage remains incomplete. Exact next action: resolve issue #494's
Core runtime-trap representation and scalar-lowering extraction in complete
vault mirrors, using the actual interpreter E7001 text/evaluation order, then
implement checked invalid-scalar runtime refusals with differential tests.

## #494 resolved implementation handoff

Delivery Owner → Language Architect → Backend Engineer. Parent #493 is committed as 53738e66; feature/494-native-operator-failures is stacked on it. Direct owner covers Core, Diagnostic/Evaluation, Eval/Operator, Lower/Scalar and Lower/Body, emitter/state/support, manifest and existing backend corpus/spec, each with complete mirrors and resolved Grill Logs before source edits. Shared diagnostics preserve interpreter wording. Bool ordering is valid; Unit failures and Bool invalid-operator wording differ. Never sequencing and print Result guards are explicit. No subagents or independent approval are claimed. Exact next action: implement this resolved Core/scalar contract and differential evidence, then run GHC 9.14.1 validation.

## #494 validation and continuation

Fresh optimized GHC 9.14.1 compilation with -Werror and all 19 repository gates
pass, including all 654 property groups. The captured copy of test/gates.sh
preserves commands and clean-build behavior while retaining per-gate output;
aggregate /tmp/pudu-494-gates.log. Focused operator facts, refusal, native success
and failure groups pass. Real CLI tree/compiled/native runs agree on E7001,
status and combined stdout/stderr effect order. Independent implementation,
Language Architect and Forensic Guardian reviews remain pending before promotion.
No subagents activated. Local macOS evidence does not claim hosted/Linux checks.
Next native issue #495 covers remaining platform Int operators; exact next action
is resolve its Core/runtime/diagnostic module mirrors before implementation.

## README progress publishing #496

User steering adds an auditable progress bar and dev-merge refresh. Delivery Owner
→ Documentation Architect → Tooling Engineer owns README.md,
scripts/native-progress.mjs, test/native-progress.test.mjs and
.github/workflows/native-progress.yml plus their mirrors/navigation. Resolved
Grill Logs exist before implementation. Branch feature/496-native-progress is stacked on committed #494; preserve
its implementation and the unrelated dist-ticky directory.
No agents activated. Independent review remains pending before promotion.
The metric is complete ledger areas, currently 4/14 (28% floored); partial rows
count zero. Publishing may only commit the generated README block to current dev;
branch protection is currently absent. Hosted execution requires integration.

### #496 validation and next action

All five Node test groups pass, including CLI stale-output failure, write/check,
malformed-input preservation, cwd independence and idempotence. YAML parses.
The actual publishing shell passed against a temporary local bare dev remote:
README-only commit, untouched surrounding/unrelated content, second-run no-op,
and a concurrent dev integration causing non-fast-forward rejection followed by
recomputation on the newer merge (5/14 = 35% in the fixture). No force push.
The real ledger remains 4/14 = 28%. Hosted Actions credentials/permissions remain
unverified until integration; this branch has not been pushed or merged.
Native #494 is committed as 7d95fd54 with all 19 clean gates and 654 property
groups passing. Independent review remains pending; no agents activated.
Exact next action: resolve issue #495's Core/runtime/diagnostic mirrors before
implementing the remaining platform Int operators.

## #495 resolved operator implementation handoff

Delivery Owner → Language Architect → Backend Engineer owns Core, Lower/Scalar,
Backend Runtime/Integer, Runtime catalogue, Emit/State/Support, Diagnostic
Arithmetic, the behavior-preserving Eval/Operator diagnostic refactor, manifests
and integer differential corpus/tests. Branch feature/495-native-int-operators
is stacked on 6bb9ecbf (#496) and 7d95fd54 (#494). Preserve dist-ticky.
All affected mirrors and the new integer-runtime contract have resolved Grill
Logs before source changes. The conversion and sign/overflow algorithms are
specified in Backend Runtime Integer. No subagents activated; independent
implementation/architecture/wiki review remains pending before promotion.
Exact next action: implement the resolved platform Int Core/runtime contract
and interpreter differential boundary/diagnostic evidence.

### #495 focused evidence

Optimized GHC 9.14.1 -Werror build passes after removing the obsolete evaluator
kind-name import. All 24 integer success programs pass independent mathematical
stdout expectations plus interpreter/native parity and warning-free C checks.
All 13 refusal programs pass, including count extrema, ordered effects, an
operand failure before the shift, macro provenance, Unicode/tabs and nonliteral
minimum negation. Focused logs: /tmp/pudu-495-integer.log (success matrix) and
/tmp/pudu-495-shifts.log (final refusal run). The earlier refusal run correctly
exposed minimum-literal narrowing; immediate checked literal negation is fixed.
A temporary direct runtime harness passed 67,342 independent Python mathematical
results under strict C11 -Wall -Wextra -Werror -pedantic and UBSan, seed 495;
/tmp/pudu-495-runtime-check.py retains the reproducible local probe.

An initial unannotated minimum local followed by negation is rejected by the
existing checker with E3018. The final runtime-overflow regression uses a solved
Int parameter so it exercises accepted source; no checker behavior was changed.
Clean complete repository gates are running with captured outputs under the
path in /tmp/pudu-495-gate-log-root and aggregate /tmp/pudu-495-gates.log.
Next issue #497 records canonical fixed signed-width admission and declared
bounds. Exact next action remains finish #495 validation before that source work.

### Additional parity audit #498

Real CLI probes accepted `return -{ 9223372036854775808 }` and an inferred
positive-magnitude local later negated. Tree evaluation returns Int minimum;
native currently narrows the intermediate and emits E7005. This is distinct
from #495's repaired immediate literal spelling. Issue #498 preserves the
full successful-native acceptance requirement, with a no-loss E6001 guard as
an intermediate hardening partition only. Exact next action after #495 gates
and commit: resolve/implement that guard, keeping #498 open until exact native
representation matches accepted intermediate behavior. Then resume #497's
signed-width family admission. No full Int/numeric/native completion is claimed.

### #495 final validation and delivery

All 19 clean repository gates pass, including fresh optimized GHC 9.14.1
-Werror compilation and all 656 property groups. Aggregate:
/tmp/pudu-495-gates.log; individual outputs are under the directory recorded
in /tmp/pudu-495-gate-log-root. The original clean-build commands/checks were
preserved in a temporary captured copy; no check or threshold was weakened.
Real CLI tree/compiled/native boundary values and shift failure agree on status
and combined stdout/stderr byte order. Current production/test sources stay
below 500 lines. The issue diff needs runtime/diagnostic versus admission/test
PR partitions before promotion if it exceeds the 600-line review boundary.
Independent implementation, architecture and wiki reviews remain pending;
no remote/Linux validation, PR, push, merge or subagent work is claimed.
Full emission is incomplete. Exact next action: resolve and implement #498's
no-loss literal admission guard, keeping its successful representation work open.

## #498 hardening partition handoff

Delivery Owner → Language Architect → Backend Engineer owns Lower.Body and
Backend Emit Tests plus their mirrors, the native coverage ledger, generated
README progress and changelog. Parent #495 is committed as 52477f88 with all
19 clean gates and 656 groups passing. Branch feature/498-native-literal-range
is stacked on it. Resolved module Grill Logs precede source edits. The guard
prevents silent narrowing; issue #498 must remain open for successful exact
intermediate representation. No subagents or independent approval claimed.
Exact next action: add carrier admission and located refusals, then verify real
CLI output preservation and immediate-minimum success.

### Exact-carrier evidence and next implementation

A reusable signed-magnitude C prototype passed 19,980 independent mathematical
boundary/full-width cases under strict C11/UBSan, including positive 2^63.
[[Exact Native Integer Carriers]] resolves the local production design and
ABI/selection/Never/diagnostic obligations. No production exact carrier is
implemented yet, and no independent review is claimed. After the guard partition
passes validation and is committed, exact next action: publish complete mirrored
contracts for Runtime.Integer value/arithmetic/bits modules and affected emitter
ABI consumers, then implement revision 4 according to that architecture page.

### #498 validation attempts and retained contract

The first guard refusal property exposed duplicate follow-on errors. Failed
block propagation was repaired without weakening the exact-one assertions.
The initial full run was stopped after that known failure; its captured output
is /tmp/pudu-498-suite-initial-aborted.log. A subsequent run found the existing
function-value fixture expected two dependent refusals; the new first-failure
policy intentionally reports only the refused initializer. The semantic delta
was inspected and documented before updating its exact code/span expectation;
that old-contract run is /tmp/pudu-498-suite-before-diagnostic-contract.log.
The final build and focused guard/recovery properties pass. Real CLI checks
prove both guarded source forms pass tree/compiled evaluation unchanged, native
build gives one E6001 at the literal, and an existing output stays byte-identical.
The immediate minimum literal still builds and prints exactly. Final full suite
ran as session 34087 and completed successfully: all 656 property groups pass,
zero failed markers, process exit 0. Capture: /tmp/pudu-498-suite.log.

The #495 integer corpus executes 24 success and 13 refusal source programs.
QuickCheck's fixed-property repetition is not 200 independent native executions.
The standalone carrier prototype is an independent mathematical experiment,
not a production backend result or completed #498 acceptance.

### #498 hardening partition final validation

Optimized GHC 9.14.1 -Werror build and all 656 property groups pass after the
recovery fix and inspected diagnostic-contract update. Focused refusal and
function recovery properties, real CLI preservation/minimum-success checks,
diagnostic-code registry, all five progress generator tests and generated
README check pass. The parent #495 has all 19 clean repository gates green;
#498's final full-suite run reused those clean products and rebuilt its changed
modules with -Werror. Do not describe that as a second clean 19-gate run.
Sources stay below 500 lines (Body 389, EmitSpec 492); scope is below the PR
review-size threshold. Independent implementation/architecture/wiki review and
hosted platform validation remain pending before promotion; no agents activated.
The scalar area is correctly Partial and the generated bar is 3/14 = 21%.
Exact next action: publish the complete Runtime.Integer.Value/Arithmetic/Bits
and affected ABI consumer mirror contracts, then implement the revision-4 exact
carrier in [[Exact Native Integer Carriers]]. Keep issue #498 and the full
100% C11-emission goal open until accepted intermediate programs execute with
complete observable parity.

## #498 exact-carrier implementation ownership

Delivery Owner → Language Architect → Backend Engineer owns Runtime and its
Integer catalogue/value/arithmetic/bits modules, Emit/Support, Lower.Body,
manifest registration and the integer/deferred corpora plus EmitSpec. Branch
feature/498-exact-int-carrier is stacked on 83f6c6cb. Complete mirrored contracts
and resolved Grill Logs precede source changes. Prototype evidence supports
unsigned sign/magnitude arithmetic; production conformance still must pass.
Preserve unrelated dist-ticky and every earlier feature. No agents activated;
independent architecture/implementation/wiki review remains pending before
promotion. Exact next action: implement revision 4 and deferred native cases.

### #498 measured layout correction

The first production magnitude/sign implementation passed focused ordinary and
extended integer cases. A runtime-kernel benchmark against 83f6c6cb measured
wrapping LCG at 5.6x the old runtime cost, so validation session 72309 was
explicitly stopped (owned process tree, terminal 143) before changing layout.
Its log is /tmp/pudu-498-exact-gates-before-layout-correction.log. This was a
measured correction, not a failed/expired observation or a claimed passing gate.
A bits/actual-sign prototype plus guarded canonical 64-bit addition passed the
same 37,980 independent mathematical/failure cases under C11/UBSan. Wrapping
LCG median ratio was 1.005; checked alternating sum ratio 1.237 on this machine.
The cost and guard are resolved in [[Exact Native Integer Carriers]]. Exact
semantics remain the hard requirement; benchmark samples are not whole-program
or cross-platform guarantees. Next validation must use the corrected layout.

## #499 promotion block and exact next action

The revision-4 integer integration remains uncommitted in
feature/499-native-frame-pressure. Its final corrected bits/sign layout passed
all 19 clean gates and 656 groups before adding the missing frame-pressure case;
logs /tmp/pudu-498-final-gates.log and the directory in
/tmp/pudu-498-final-gate-log-root. Eight final CLI source forms agree in tree,
compiled and native execution, including positive-boundary exit status 255.
The production helper probe passes 37,980 independent C11/UBSan results and
failure kinds. Measured runtime-kernel ratios: wrapping 1.008 and checked sum
1.240 versus 83f6c6cb on this host; no general performance guarantee is claimed.

The pressure audit then found native SIGSEGV before E7002 with 96 live integer
parameters. Both tree/compiled paths give E7002. The permanent test-only failing
regression is committed as 32b231cc; the focused current integration test exits 1
in /tmp/pudu-499-regression.log. Do not claim the current suite is green or
commit/promote the ABI integration until #499 is repaired. Prior gate success
did not cover this failure. No subagents were executed.

[[Native Frame Pressure Repair]] is the focused active handoff.
[[Native Execution Frames]] resolves pure control/continuation requirements;
allocation failure policy still needs explicit resolution. Exact next action:
publish complete Core frame-IR and structured-Core-to-continuation mirrors with
resolved Grill Logs, then implement that pure transformation and its tests.
Resolve runtime allocation/cleanup vocabulary before implementing frame storage.
The full 100% goal remains active; signed-width issue #497 follows this repair.
