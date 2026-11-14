---
type: handoff
status: ACTIVE
issue: 524
aliases: [Entry Call Span Repair]
---
# Entry Call Span Repair

Delivery Owner → Runtime Engineer → Test Engineer. From dev (c13dd93e).
Owned: Eval/Program.hs, EntryAritySpec.hs, test/Main.hs, pudu-tests.cabal and
mirrors.

Finding: reported as warnings during `pudu test`; the repository run stopped at
test-fixtures/lspcompletion/Root.pudu on an uncaught exception.

Evidence: the spec fails without the repair and passes with it; the full
suite passes at -O0; a repository-wide `pudu test` now runs to the end;
all 20 clean gates pass (5e01325b).

Exact next action: Forensic Guardian review of the PR to dev.

## Referenced by

[[handoffs/_MOC]] · [[Eval Entry Arity Tests]]
