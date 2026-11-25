---
type: handoff
status: ACTIVE
issue: 995
aliases: [Native Ownership Delivery]
---

# Native Ownership Delivery

Architect → Backend Engineer. Branch `feature/995-native-ownership` starts from
the native parity branch tip. This pass owns [[NATIVE-OWNERSHIP]],
[[Compiler Lower Array]], [[Compiler Frame Body]], [[Backend Frame Bodies]] and
[[Backend Frame Runtime]].

## Next action

Add a last-use pass over Core that turns the final read of a counted local into
a move, so a parameter passed to `multiMapAdd` arrives held once; then measure
`bench/eval/MultiMap.pudu`.

## Delivered

Backend Engineer → Test Engineer. The caller move and argument transfer are in place: `m = f(&m, ...)` moves `m` into the call when no other operand reads it, the caller clears its slot, and frame entry skips the retain for transferred parameters on both the heap and direct paths. A typed fast entry is taken only when no transfer is pending. Only counted aggregates (arrays, maps, sets, stores, records) move. The full property suite passes. MultiMap timing is unchanged until the callee's own reads stop retaining.

## Referenced by

[[handoffs/_MOC]] · [[NATIVE-OWNERSHIP]]
