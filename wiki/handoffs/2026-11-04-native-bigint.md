---
type: handoff
status: ACTIVE
issue: 800
aliases: [Native BigInt Delivery]
---
# Native BigInt Delivery

Backend Engineer → Test Engineer → Forensic Guardian self-audit. Owned:
the BigInt runtime modules (new), Support's BigInt helpers, Cell's owned
cell, Frame's cell flag, ownership switches and entry release, Frame
Value's conversions and display, Aggregate's kind codes, frame State's
moves, lowering's admission, BigIntPrograms and mirror pages. No
sub-agents. Branch feature/800-native-bigint on feature/798-native-dev-sync.

Evidence: every corpus program matches the tree interpreter byte for byte;
the BigInt groups pass under Clang, GCC 15 and ASan/UBSan with zero live
allocations; the carrier was differentially tested on its own; every
backend property label passes.

Exact next action: Decimal values natively: the interpreter's scaled
decimal (exact `+ - *`, division that is exact or fails, `decimalDivide`
and `decimalRound` with their modes, rendering), as a BigInt coefficient
and a scale in the C runtime.

## Referenced by

[[handoffs/_MOC]] · [[Native BigInt]]
