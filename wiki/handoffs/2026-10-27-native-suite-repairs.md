---
type: handoff
status: ACTIVE
issue: 636
aliases: [Native Suite Repair Delivery]
---
# Native Suite Repair Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Runtime Process/Dependencies/Output/registration, FrameEmitSpec,
FloatRuntimeSpec and their mirror pages. No sub-agents. Branch
feature/636-native-suite-repairs on feature/633-native-panic.

The release gate (unchanged) run at the #631 commit failed only its
optimized full suite. Both failing backend properties predate #631: the
frame-body spec hand-assembled a scalar runtime that cannot hold the Result
aggregates printing programs now carry, and process_io left
pudu_wait_writable unused in minimal selections, which clang rejects. The
fixes strict-compile the real emitter's output and make wait_writable a part
its two users depend on. The float spec's dependency table now checks only
integer parts; its old filter was wrong and hidden behind the compile error.

The optimized suite at #631 failed three properties in all: the two above
and the shared-reference refusal table, whose borrowed print Result case now
builds with the interpreter's output (it moved to the reference corpus and a
Decimal reference took its place). The E6001 table's open-result case was
already moved in #633.

Evidence: frame, runtime, output, pipe, diagnostic, module, leak and
reference groups pass under Clang, GCC 15 and ASan/UBSan where they compile C.

Exact next action: confirm test/gates.sh unchanged at this branch's tip in a
detached worktree and confirm the optimized suite passes; then continue
first-class builtin values with the next prelude builtin that has a direct
native lowering, keeping #634 open for panic's typing.

## Referenced by

[[handoffs/_MOC]] · [[Native Emission Coverage]]
