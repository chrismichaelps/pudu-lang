---
type: handoff
status: ACTIVE
issue: 570
aliases: [Native Diagnostic Ownership Delivery]
---
# Native Diagnostic Ownership Delivery

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit. [[Native Diagnostic Ownership]] resolves
the contract. Ownership: Backend/{Runtime,Runtime/Text}, FrameRuntimeSpec/BrokenPipeSpec and
matching mirrors, handoff and changelog. No sub-agents. Independent review is
pending. Branch feature/570-native-diagnostic-ownership starts at freshly
fetched dev and fast-forwards #569. The prior slice is committed as ab10eeba.
Preserve all unrelated work, private ignored inputs and the full release gate.

The old counted E7001 regression exits 97 after printing its diagnostic,
proving one surviving allocation (/tmp/pudu-diagnostic-red.log). The reporter
now takes owned_payload, frees it after final stderr use and preserves frame
cleanup/signal ordering. Static sites pass NULL; dynamic message/help views
share one owned allocation. Combined length overflow rejects before copying.
Runtime revision is 16.

Validation: -Werror builds compiled changed runtime/test modules and relinked
CLI/tests. Four real source failures (E7001, E7008/static help, array and Unicode
Str computed-help E7004) compare complete stdout/stderr/status with both
isolated evaluators while allocation accounting requires zero live blocks.
Those and empty/overflow probes pass Clang, GCC 15 and ASan/UBSan in
/tmp/pudu-diagnostic-{clang,gcc,asan}.log. Expanded five-case closed-pipe
matrices pass Clang and ASan/UBSan in /tmp/pudu-diagnostic-pipes-*.log.
Seven focused frame/join/operator/sum/emission/site regressions pass in
/tmp/pudu-diagnostic-regressions.log. No full release run occurred and the
full gate/workflows are unchanged; independent/platform review remains pending.

The user identified the missing PR delivery. GitHub has the original native
PR #487 targeting the performance branch; later native feature branches have
no PRs. The accumulated stack is 71 commits beyond dev before this slice.
Publish reviewable dependency partitions targeting dev, preserving the active
implementation checkout and explicitly marking pending full validation. Do
not create one oversized aggregate PR or quietly merge unreviewed work.

Exact next action: commit #570, then publish the first self-contained native
foundation contracts partition as a draft PR to dev and attach it to this chat.

## Referenced by

[[handoffs/_MOC]] · [[Native Diagnostic Ownership]]
