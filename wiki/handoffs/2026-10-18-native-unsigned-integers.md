---
type: handoff
status: HANDED_OFF
issue: 500
aliases: [Native Unsigned Integer Delivery]
---
# Native Unsigned Integer Delivery

Delivery Owner → Language Architect → Compiler Engineer → Test Engineer.
Direct ownership covers Lower.Types admission, unsigned corpus/projection/refusal/
entry tests, registration and matching vault pages. The existing runtime/frame
contracts are reused. No subagents execute; preserve unrelated dist-ticky.

[[Native Unsigned Integers]] resolves #500. Begin a fresh
feature/500-native-unsigned-widths stacked on 68d92918: required native ABI work
is not yet on dev. This continuation does not authorize unreviewed promotion.
Prior signed validation remains in [[Native Signed Integer Delivery]].

Require full unsigned/high-bit mathematical expectations, checked underflow,
zero/nonzero negation, logical shifts with platform Int counts, canonical kind
identity, all scalar transfers and exact observable parity. Strict C11,
sanitizers, complete gates, independent review and platform evidence remain
delivery requirements; all other full-emission obligations remain active.

Test Engineer → Delivery Owner: implementation and local validation complete.
All 19 clean gates pass (669 groups, 319 strict C11 translations). All 20
native groups pass against the tree evaluator under AddressSanitizer/UBSan.
Five unsigned entry-status comparisons and static rejection boundaries pass.
Durable local evidence: ~/.codex/tmp/pudu-500/validation/. Independent
implementation/Language Architect/Forensic Guardian review and additional
platform evidence remain pending before promotion; no PR has been merged.

Exact next action: continue [[Native Wide Integer Delivery]] for the resolved
portable Int128/UInt128 arithmetic prerequisite #501.

## Referenced by

[[handoffs/_MOC]] · [[Native Unsigned Integers]] · [[Native C11 Backend Delivery]]
