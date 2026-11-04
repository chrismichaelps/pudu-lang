---
type: handoff
status: HANDED_OFF
issue: 541
aliases: [Native Refutable Binding Delivery]
---
# Native Refutable Binding Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
User instruction: work without subagents. Independent review remains required
before promotion; implementation authors do not self-approve.

Owned: Compiler/Lower/Match.hs, Compiler/Lower/Body.hs,
test/Pudu/Backend/SumPrograms.hs and matching vault pages.
Prerequisite #542 additionally owns Frontend/Syntax/Pattern.hs,
Semantic/Resolve/{Bindings,Context}.hs, Type/Check/Pattern.hs,
test/Pudu/Type/Check{Spec,/PatternSpec}.hs, production Cabal and their mirrors.
This fixes documented alternative binding admission rather than narrowing the
native test to avoid a checker defect. Contracts and
resolved Grill Logs existed before implementation. Stacks on #540 at
404bb91d because its prerequisites are not on dev; origin/dev was fetched.

Re-anchored from Claude's C11 emission completion session. #539 passed its
full gate; #540 failed only the optimized suite in its original gate. Its
existing direct suite rerun (PID 43948 at resumption) was still live and
was preserved. On 2026-10-22 its process and scratch worktree were absent;
its terminal result is unavailable. The clean current gate must establish
full-suite compatibility for the stack. No pass is inferred for that old run.

Final focused evidence (2026-10-22): Clang, GCC 15, Clang ASan/UBSan and
PUDU_EVAL=tree passed both native sum families including the Never-subject
regression. All 69 counted programs released every allocation. The alternative
binding property actually executed and passed, including E2019's code, message,
help and source location. Diagnostic-code and application-layer checks passed.
Logs: /Users/chrismperez/.codex/tmp/pudu-native-let-else/.

The clean canonical 20-gate run completed successfully (exec session 98773,
terminal exit 0). Actual clean compilation of 338 library modules and 143
test modules passed with -Werror; all 711 optimized test groups passed, then
all CLI, formatting, package, LSP, watch and documentation gates passed.
The wrapper preserved each canonical command's output separately and retained
the clean-build deletion. No production or test changes occurred during it.

#542 is a ready prerequisite discovered by #541's conformance corpus. Its
bounded fix shares this branch with #541; independent semantic and forensic
review remain promotion gates. No subagents were started.

Exact next action: start ready issue #543 from this validated stack and
complete its touched mirrors before passing compileFolded into native module
scopes. [[Native Folded Constants]] and [[Compiler Lower Constant]] are the
resolved design; next-constants.md in the evidence directory records the
inspected compiler contracts. Full C11 emission remains an active goal.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Match]]
