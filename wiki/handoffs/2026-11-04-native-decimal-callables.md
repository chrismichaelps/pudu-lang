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

Author audit: four changed implementation files have matching resolved
mirrors; introduced vault links resolve, with existing unrelated broken
references left unchanged. This slice does not change the coverage area count.

Exact next action: finish the clean optimized repository gates, then open
the reviewable PR to dev with captured validation evidence.

## Referenced by

[[handoffs/_MOC]] · [[Native Decimal]] · [[Native Emission Coverage]]
