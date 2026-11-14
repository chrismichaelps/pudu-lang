---
type: handoff
status: HANDED_OFF
issue: 543
aliases: [Native Folded Constant Delivery]
---
# Native Folded Constant Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
No subagents, per user instruction. Independent semantic and Forensic Guardian
review remain promotion gates.

Stacks on validated 19961f7e (#541/#542), all 20 clean gates and 711 test groups
passed. origin/dev fetched before starting; native prerequisites are not on dev.

Owned: Compiler/Lower.hs, Compiler/Lower/{State,Body,Constant}.hs,
production Cabal, test/Pudu/Backend/{ModulePrograms,TextLeakSpec,LowerTypesSpec}.hs
and matching vault pages. Complete resolved mirrors precede code edits.
[[Native Folded Constants]] owns the cross-phase contract.

Implemented the folded-data handoff, canonical scalar/aggregate projector,
module resolution and source-provenance boundaries. Focused evidence: the
constant boundary property passes, including raw Float32, negative-zero and
NaN Core bits; module conformance passes under Clang, GCC 15, ASan/UBSan and
PUDU_EVAL=tree. Constant and imported-function overflow diagnostics pass under
Clang, GCC 15 and ASan/UBSan. All 71 counted programs release every allocation.
An initial test fixture omitted exported constant annotations; it was corrected
to the existing language contract, with no checker changes or relaxed assertions.

Evidence: /Users/chrismperez/.codex/tmp/pudu-native-constants/ contains focused
logs and a stable pudu-test-final executable. The canonical clean 20-gate run
completed with terminal exit 0 (exec session 95861). Actual clean compilation:
339 production modules and 143 test modules; all 712 optimized test groups
passed, followed by every CLI/package/LSP/watch/documentation gate. No source
or test changes occurred during validation. The real CLI builds the imported
constant probe; its executable and both interpreter modes print identical
locked bytes and exit 0. Full C11 emission remains an active goal.

Exact next action: start ready issue #544 from this validated native stack.
A checked probe in /Users/chrismperez/.codex/tmp/pudu-native-references/probe/
prints 9, 7, hello in both interpreter modes; native refuses its &Point
parameter. Shared-reference admission is a prerequisite for ordinary user
methods. The resolved design is prepared separately for that next slice;
complete all assigned mirrors before implementing it. Mutable place writeback,
methods, generic code and the other ledger gaps remain open.

## Referenced by

[[handoffs/_MOC]] · [[Native Folded Constants]]
