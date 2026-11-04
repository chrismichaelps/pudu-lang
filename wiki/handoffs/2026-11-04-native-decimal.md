---
type: handoff
status: ACTIVE
issue: 802
aliases: [Native Decimal Delivery]
---
# Native Decimal Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
Core's Decimal type, literal and methods; the frame IR and its lowering;
the Decimal runtime modules (new); Cell, Frame, Frame Value, Support and
Aggregate's Decimal cases; lowering's types, scalars, literals, constants,
primitives (Compiler Lower Decimal, new) and `toDecimal`; the #803
evaluator fix; DecimalPrograms and mirror pages. No sub-agents. Branch
feature/802-native-decimal on feature/800-native-bigint.

Evidence: every corpus program matches the tree interpreter byte for byte;
the Decimal groups pass under Clang, GCC 15 and ASan/UBSan with zero live
allocations; the full test binary passes (759 properties).

Exact next action: consolidate the native stack into dev (oldest first),
then entry result reporting's remaining callable forms.

## Referenced by

[[handoffs/_MOC]] · [[Native Decimal]]
