---
type: handoff
status: ACTIVE
issue: 502
aliases: [Native Wide Value Publication]
---
# Native Wide Value Publication

Language Architect → Backend Engineer → Test Engineer → Forensic Guardian
self-audit → Tooling/Release Engineer. Own Wide.Value, WideValueSpec, their
registration and matching vault pages. Include the unchanged Word128 source
prerequisite from PR #573 so this dev-targeted partition builds independently;
its full raw arithmetic corpus remains in #573. No sub-agents. Independent
code, architect and wiki review remains pending. Preserve all other work.

Branch feature/502-wide-value-contracts starts at freshly fetched dev.
This projection retains actual signs, exact limits and selective dependencies;
source admission, arithmetic policies, frame ABI and full parity remain open.
The full release gate and workflows are unchanged.

Forced GHC -Wall -Werror compilation of all three projected modules passes.
Both Cabal manifests pass cabal check. Clang, GCC 15 and ASan/UBSan each pass
75 values, 5,625 comparisons and 16 standalone helper selections. Logs:
/tmp/pudu-wide-value-publication-{clang,gcc,asan}.log. This is macOS arm64
evidence; full GitHub CI and independent review remain pending. No full local
release pipeline ran. The raw arithmetic corpus was separately validated in
PR #573; this partition retains its identical kernel implementation.

Exact next action: open and attach the dev-targeted draft PR, then inspect its
full GitHub CI before review readiness.

## Referenced by

[[handoffs/_MOC]] · [[Backend Wide Integer Values]] · [[Native Wide Value Tests]]
