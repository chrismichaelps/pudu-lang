---
type: handoff
status: ACTIVE
issue: 501
aliases: [Native Wide Integer Delivery]
---
# Native Wide Integer Delivery

Delivery Owner → Language Architect → Backend Engineer → Test Engineer.
[[Native Wide Integers]] resolves the portable arithmetic prerequisite #501.
Direct ownership: Runtime.Integer.Word128, Word128Spec, both Cabal registrations,
test runner registration and their mirrors. No subagents execute.

Use feature/501-native-word128 stacked on ca2da6d1 because the required native
work is not on dev yet. Architecture/mirror edits prepared before this branch
belong only to #501. Preserve unrelated untracked dist-ticky. Fresh dev ancestry
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

Exact next action: prepare a ready dependent issue and resolved mirrors for
selectable Word128 helpers plus the exact signed carrier, then implement its
independent executed value corpus. Keep typed arithmetic, frame integration,
source admission and full-language completion explicitly pending.

## Referenced by

[[handoffs/_MOC]] · [[Native Wide Integers]] · [[Native Unsigned Integer Delivery]]
