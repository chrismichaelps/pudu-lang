---
type: handoff
status: ACTIVE
issue: 519
aliases: [Record Field Order Repair]
---
# Record Field Order Repair

Delivery Owner → Runtime Engineer → Test Engineer. From dev (c13dd93e).
Owned: Eval.hs, Eval/{Env,Install,Compile,Program}.hs, Eval/Loop/Kernel.hs,
RecordOrderSpec.hs, test/Main.hs, pudu-tests.cabal, SEMANTICS and mirrors.

Finding: found while designing native records (#518 stack). A literal's
written order leaked into record values in all three evaluators.

Evidence: the new spec fails without the repair on every path and passes
with it; the full suite passes at -O0.

All 20 clean gates pass (25d3fd03).

Exact next action: Language Architect and Forensic Guardian review of the PR
to dev.

## Referenced by

[[handoffs/_MOC]] · [[Eval Record Order Tests]]
