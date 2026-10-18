---
type: handoff
status: ACTIVE
issue: 502
aliases: [Native Wide Integer Delivery]
---
# Native Wide Integer Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
[[Native Wide Integers]] resolves the portable arithmetic prerequisite #501.
Direct ownership for #502: Word128 selectable catalogue, Wide.Value,
WideValueSpec, manifests, runner and mirrors. No subagents execute.

Use feature/502-native-wide-values stacked on 058b7300 because the required
native work is not on dev yet. Architecture/mirror edits prepared before this
branch belong only to #502. Preserve unrelated untracked dist-ticky. Fresh dev ancestry
and independent implementation/architect/wiki review remain promotion gates;
no self-approval or production-ready claim.

Raw kernel support does not admit Int128/UInt128 yet. Exact signed policies,
frame cells, literals, printing, statuses, diagnostics and full differential
source corpora remain required by the original full-emission objective.

The raw kernel and registered corpus now pass Clang strict C11, GCC 15 and
Clang ASan/UBSan: 1,097 arithmetic rows plus 3,799 shift rows. All 19 clean gates
pass with 670 test groups; logs are under ~/.codex/tmp/pudu-wide/validation/. A separate Int128/UInt128 checked source probe confirms both evaluator
anchors documented in [[Native Wide Integers]]. The complete
raw catalogue cannot be embedded unused; individual helper selection remains
an explicit typed-adapter integration requirement.

Test Engineer → Delivery Owner → Language Architect: the prerequisite is
locally validated. Independent review remains pending before promotion.

Backend Engineer → Test Engineer → Delivery Owner: #502 is locally validated.
75 values/5,625 comparisons, all 16 minimal helper selections, unchanged raw
corpus, Clang/GCC 15 and ASan/UBSan pass. All 19 clean gates pass with 672
groups and 319 strict frame C11 translations. Logs: ~/.codex/tmp/pudu-502/.
Independent implementation/architect/wiki review and more platforms remain pending.

Exact next action: continue ready #503's portable arithmetic/bitwise/shift
adapter with the resolved operation contracts. Typed frame/source admission
and the full language objective remain incomplete.

## Referenced by

[[handoffs/_MOC]] · [[Native Wide Integers]] · [[Native Unsigned Integer Delivery]]
