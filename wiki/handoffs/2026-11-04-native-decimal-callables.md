---
type: handoff
status: ACTIVE
issue: 806
aliases: [Native Decimal Callable Delivery]
---
# Native Decimal Callable Delivery

Architect → Test Engineer → Backend Engineer → Forensic Guardian self-audit.
Branch feature/806-native-decimal-callables starts from integrated dev.
Owned: Compiler Lower Decimal and Intrinsic, Backend Decimal Programs,
Backend Text Leak Tests, their mirrors and the native coverage/navigation
pages. Preserve unrelated work; no subagents.

Backend Engineer → Tooling Engineer: the full gate exposed the native
Decimal integration's missing E7010 registry entry, already present on dev.
Additional bounded ownership: test/diagnostic-codes.mjs and its mirror.
Both reporting sites mean the same non-terminating Decimal quotient and
retain their exact message/help; register that shared condition explicitly.

The seven Decimal primitives reuse the direct-call answer builder with an
explicit validated result type. Builtin closure ABI, tag identity, rendering
and uncounted frames stay unchanged. Missing/mismatched checked callable
facts refuse at the reference. No semantic or runtime ABI change.

Regression coverage: aliases, captures, generic higher-order calls,
collections, shadowing, source-order arguments, early transfer, None results,
entry builtin rendering, argument diagnostics and counted cleanup.

Independent implementation and Forensic Guardian review remain required
before merge; this self-audit does not substitute for either review.

The unchanged lowerer failed the new corpus with E6001 at decimalOf. The
shared builder now passes the focused native Decimal groups under Clang
with tree and compiled evaluators, GCC 15, and Clang ASan/UBSan. Three
library-free programs return every counted allocation to zero. The real
CLI alias repro prints Some(12.30) with identical stdout/stderr/status in
both evaluator modes and the native executable. GHC 9.14.1 is installed.

Author audit: changed implementation and gate files have matching resolved
mirrors; introduced vault links resolve, with existing unrelated broken
references left unchanged. This slice does not change the coverage area count.

Clean GHC 9.14.1 optimized warnings-as-errors build and full test suite pass.
The full gate invocation passed 47 checks and failed only the diagnostic
registry's missing E7010 entry. After inspecting both identical reporting
conditions, the registry fix passes its focused gate (172 codes, 38 shared,
393 sources). No Haskell source changed after the full suite; every other
gate, including formatting, memory bounds, package, LSP and docs checks,
passed in that full invocation. The original nonzero gate result is retained
in the validation record rather than described as a clean script exit.

Delivery: PR #807 targets dev and remains draft. CI on the final tip and
independent implementation/wiki-parity review remain promotion obligations.

Exact next action: obtain independent implementation and wiki-parity review
on PR #807 before merging.

## Referenced by

[[handoffs/_MOC]] · [[Native Decimal]] · [[Native Emission Coverage]]
