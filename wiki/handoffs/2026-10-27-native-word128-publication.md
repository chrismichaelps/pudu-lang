---
type: handoff
status: ACTIVE
issue: 501
aliases: [Native Word128 Publication]
---
# Native Word128 Publication

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit → Tooling/Release Engineer. Own Word128.hs, Word128Spec.hs, their
manifest/runner registration and matching vault pages. No sub-agents.
Independent code, architect and wiki review remains pending.

Project the existing portable kernel onto freshly fetched dev in
feature/501-native-word128-kernel. Preserve the accumulated implementation
checkout and all unrelated work. This independently reviewable prerequisite
adds no typed admission or CLI behavior. Full CI will run on the draft PR;
focused local validation precedes publication. The release gate is unchanged.

The two projected modules pass forced GHC -Wall -Werror compilation using
this checkout's source paths. Clang, GCC 15 and ASan/UBSan each execute
1,097 arithmetic and 3,799 shift rows successfully. Both Cabal manifests pass
cabal check; diff whitespace checks pass. Logs: /tmp/pudu-word128-publication-
{clang,gcc,asan}.log. These are macOS arm64 results; full CI/platform evidence
and independent review remain pending. No full local release pipeline ran.

Exact next action: open and attach the dev-targeted draft PR, then inspect its
full GitHub CI before review readiness.

## Referenced by

[[handoffs/_MOC]] · [[Backend Word128 Kernel]] · [[Native Word128 Tests]]
