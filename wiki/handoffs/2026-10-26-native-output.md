---
type: handoff
status: ACTIVE
issue: 566
aliases: [Native Output Delivery]
---
# Native Output Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. No sub-agents; independent review remains pending. Branch
feature/566-native-output-results starts from fetched dev and fast-forwards
the #565 dependency before new source edits. [[Native Output Results]] resolves
the design.

Ownership: Core.hs, Core/Frame.hs, Compiler/Lower/{Call,Body,Layout}.hs,
Compiler/Frame/Body.hs, Backend/{Runtime,Runtime/Dependencies,
Runtime/Output,Runtime/Process,Emit/Frame,Emit/Frame/Value}.hs, Cabal registration, focused output
corpus and native/leak/emission test registration, and corresponding mirrors.
Preserve the full gate and unrelated source.

The #566 slice passes its focused validation and is ready for a local commit. Direct
output Results use existing Core sums via CoreOutputError/FrameOutputError.
The 8192-byte handle adapter retains pending bytes after failure; entry
reporting follows the separate text builder and pinned top-handler format.

The closed-at-exec mismatch is resolved by a one-time queue/control-pipe
endpoint projection before user code. All seven missing-descriptor masks
are covered, including expected waits and exact flushed prefixes. Fatal
stderr reporting now shares the blocking-descriptor readiness policy; the
new E7004 probe first demonstrated a native exit versus interpreter wait,
then passed after the fix.

Fast check: build with --builddir=dist-fast and -Werror, then run the test
binary with PUDU_TEST_MATCH='native output'. Child invocation
--native-output-oracle PATH runs before test-runner buffering. Final logs:
/tmp/pudu-output-final-{clang,gcc,asan}.log. The isolated fatal/reporting
regression is green in /tmp/pudu-output-fatal-green.log, with its original
failure in /tmp/pudu-output-fatal-red.log. Full gate/workflows stay unchanged.

First-class output builtin values still need a callable representation that
does not add user call depth; do not implement them as ordinary wrappers.
Full numeric, reference/resource, host-service and concurrency coverage
remains in the complete emission goal. The full release gate is unchanged.

All five output groups pass Clang, GCC 15 and ASan/UBSan; six counted programs
release every tracked allocation. Closed-pipe continuation plus five focused
lowering/emission/refusal groups pass. The incremental -Werror build compiled
the changed runtime modules and relinked the CLI and test runner. No full
release run was performed during iteration; Linux/Windows and independent
review remain pending. The slice exceeds the PR review-size limit and needs
partitions before opening a PR. No review or promotion is claimed.

Exact next action: commit the validated #566 slice locally, then resolve the
next callable coverage gap in the vault before changing implementation.

## Referenced by

[[handoffs/_MOC]] · [[Native Output Results]]
