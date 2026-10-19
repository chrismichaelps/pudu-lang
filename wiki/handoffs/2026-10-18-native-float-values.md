---
type: handoff
status: HANDED_OFF
issue: 510
aliases: [Native Floating Value Delivery]
---
# Native Floating Value Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
#509 is committed as 016aed63 with all 20 clean gates/682 groups passing.
Own Runtime/Float/Value.hs, FloatValueSpec.hs, explicit registration and matching
vault pages. Complete resolved mirrors precede implementation. No subagents;
preserve unrelated dist-ticky. Stack on #509 because freshly fetched dev lacks
these prerequisites; keep each review partition below 600 changed lines.

Resolve exact transport, Double-first arithmetic, Float32 normalization,
sign-bit negation and unordered comparisons in [[Native Floating Values]].
The optional IEC macro is absent on working Mac compilers; dimensions alone do
not establish IEEE conformance. Actual raw-bit corpus evidence is mandatory.
Compiler/target ABI, floating exception-flag parity and foreign environment
behavior remain explicit
source-integration obligations. No source admission or runtime revision change.

Preflight: ~/.codex/tmp/pudu-float/arithmetic-probe/ contains 17,184 arithmetic
rows per Clang/GCC and 4,294 narrowing encodings matching GHC. This host evidence
guides permanent tests; it does not replace production helper execution.

Backend Engineer → Test Engineer: production helper and permanent corpus now
exist. The first warning gate exposed a corrected test-only precedence error.
Fixed normalization goldens then reproduced GHC 9.14.1 constant-folding without
Float32 rounding; a NOINLINE oracle preserves actual runtime normalization.
Clang pure decode operands and GCC nested multiply/subtract exposed distinct
NaN payload reordering; a NaN-only subtraction propagation path repairs both
without canonicalizing payloads. All 54,344 rows, 15 minimal roots and three
policy/ABI refusals pass Clang, GCC 15 and ASan/UBSan. LeakSanitizer is
unavailable on this Mac and is not claimed.

Additional target evidence: both compilers also pass all focused checks at -O0.
Actual helper/optimized GHC probes match 12,064 default-environment rows for
bits and normalized IEEE exception flags. Larger-heap runs match 48,256 rows
per compiler across nearest/down/up/toward-zero. The ordinary-heap upward run
exposes one inexact-status discrepancy with identical bits; a trace places GHC
GC between the clear/read at that exact row, and the larger-heap rerun removes
it. The no-arithmetic control is clean. Preserve these observations in
~/.codex/tmp/pudu-510/flags/; do not claim unconditional foreign-environment
parity from this controlled helper evidence.

Final validation: all 20 clean gates pass; the exact gate session exits zero.
Fresh -Werror compilation includes 322 production and 130 test modules. The
full suite runs 685 groups, 54,344 floating rows, the retained 63,661 formatter
encodings and 351 strict frame translations. Progress checking and all five
progress-generator tests pass. Durable logs: ~/.codex/tmp/pudu-510/validation/.

Exact next action: integrate the floating catalogue and printer through a general
runtime dependency facade under a ready successor issue, then implement the
Core/frame bridge and source admission described in
~/.codex/tmp/pudu-510/integration-next.md. No source coverage or revision change
is claimed here. Independent review and other supported platforms remain open.

## Referenced by

[[handoffs/_MOC]] · [[Native Floating Values]] · [[Native Floating Value Tests]]
