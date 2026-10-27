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

The diagnostic ownership repair is committed as 4bff2f7f.

Role transition: Forensic Guardian → Tooling/Release Engineer for publication.
Draft PR [#571](https://github.com/chrismichaelps/pudu-lang/pull/571) is now open
against dev from feature/486-native-core-contracts in /tmp/pudu-native-core-pr.
It publishes only the existing Core contracts and one registered contract test,
with 464 additions/one deletion. GHC -Werror checks, the focused property and
both Cabal manifest checks pass. Full compiler, Raylib, musl and website CI jobs
are running; independent review is pending. The PR is attached to this chat.
The main implementation checkout remains clean and its commits are preserved.

PR #571 now passes all five GitHub checks: compiler, musl runtime, Lambda,
website renderer and Raylib shared-library integration. It remains a draft
pending independent code, architect and wiki review.

Draft PR [#572](https://github.com/chrismichaelps/pudu-lang/pull/572) targets dev
from feature/486-native-diagnostic-contracts in /tmp/pudu-native-diagnostics-pr
(commit 5157bafb). Six E6001–E6006 constructor/rendering cases, forced GHC
-Werror compilation, registry and both manifest checks pass. Website CI passes;
compiler, musl and Raylib checks are running. No native invocation is admitted.

Draft PR [#573](https://github.com/chrismichaelps/pudu-lang/pull/573) targets dev
from feature/501-native-word128-kernel in /tmp/pudu-native-word128-pr
(implementation commit d8054127). Its raw kernel matches the accumulated source.
Forced GHC -Wall -Werror compilation and both manifest checks pass. Clang,
GCC 15 and ASan/UBSan each execute 1,097 arithmetic and 3,799 shift rows
against independent Integer answers. No source-language admission is implied.
All three PRs are attached; the full release gate/workflows remain unchanged.
The user forbids sub-agents, so independent review remains explicitly pending.

Exact next action: inspect PR #572/#573 CI and publish the existing independent
wide-carrier dependency (#502) as the next reviewable dev-targeted partition;
retain the complete Native Emission Coverage obligations for subsequent work.

## Referenced by

[[handoffs/_MOC]] · [[Native Diagnostic Ownership]]
