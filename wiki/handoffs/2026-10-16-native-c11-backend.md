---
type: handoff
status: ACTIVE
issue: 486
aliases: [Native C11 Backend Delivery]
tags: [handoff, backend, native, c11]
---
# Native C11 Backend Delivery

Issue #486 delivers the first production slice of the native C11 backend
promised by [[ADR-0002-compiler-pipeline]], stacked on PR #485
(`feature/483-backend-performance`) until it merges. The user authorizes
production-level emission, not a minimal sketch: deterministic C11, checked
arithmetic with interpreter-parity diagnostics, a bounded toolchain seam, and
differential conformance tests.

Transitions: Delivery Owner → Language Architect (CLI surface: `pudu build
--native`) → Performance Engineer (Loop measurement) → Forensic Guardian
(wiki parity). Delivery Owner owns [[Compiler Lower]], [[Backend Emit]],
[[Backend Runtime]], [[Backend Toolchain]], [[Diagnostic Arithmetic]],
[[Diagnostic Native]], [[Pudu Core]], the [[Pudu CLI]] build path, and the two
new test specs. Runtime author owns nothing until the interpreter's checked
text moves into [[Diagnostic Arithmetic]]. Benchmark owner reuses the #483
harness unchanged. Agents are not alone; preserve other work.

Resolved Grill Log: the interpreter is the semantic oracle — native output
must equal it byte for byte (stdout, stderr text, exit status), enforced by
differential tests, not by convention. C emission is a pure function of
[[Core IR]] plus sources; the toolchain is the only process seam; the runtime
is embedded so packaged compilers stay self-contained. M1 refuses everything
outside the frozen scalar subset with `E6001`; no fallback, no approximation.
The `E7004`/`E7005` texts move to one module so the C runtime cannot drift.

Measured record: the CLI surface is verified end to end — `pudu build
Smoke.pudu --native` produces an executable whose stdout, stderr, and exit
status are byte-identical to the interpreter, Abort1/Abort2 render
byte-identical refusals, `E6001`/`E6003` refusals render through the CLI, the
15 new backend checks pass, and the full 628-check suite is green. Native Loop
(`bench/eval/Loop.pudu`, 3,000,000 iterations): 9.1–12.9 ms across five runs
(median ~11 ms) with stdout `26999982` and exit 0 — about 22× the 245/246 ms
interpreter record from #483 — and a 34,032-byte executable against the
98,037,480-byte compiler.

Exact next action: PR #487 is open against `feature/483-backend-performance`
until #485 merges, then retarget to `dev`; await Language Architect review of
the `--native` surface and Forensic Guardian wiki-parity review.

---
