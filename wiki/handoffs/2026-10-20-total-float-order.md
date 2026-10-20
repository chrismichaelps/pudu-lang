---
type: handoff
status: ACTIVE
issue: 522
aliases: [Total Float Order Repair]
---
# Total Float Order Repair

Delivery Owner → Runtime Engineer → Test Engineer. From dev (c13dd93e).
Owned: Eval/Value.hs, FloatOrderSpec.hs, test/Main.hs, pudu-tests.cabal,
SEMANTICS and mirrors.

Finding: found while matching native tuple ordering (#521). With a NaN
member, base's Ord defaults turned compare's GT-both-ways into `<` and `>`
both true, and ordered maps held duplicate keys.

Evidence: the spec fails without the repair and passes with it.

Exact next action: run the clean 20 gates, then open the PR to dev.

## Referenced by

[[handoffs/_MOC]] · [[Eval Float Order Tests]]
