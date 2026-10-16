---
type: handoff
status: VALIDATED-LOCALLY
issue: 488
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
