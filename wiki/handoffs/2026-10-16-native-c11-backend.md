---
type: handoff
status: ACTIVE
issue: 494
aliases: [Native C11 Backend Delivery]
tags: [handoff, backend, native, c11]
---
# Native C11 Backend Delivery

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
