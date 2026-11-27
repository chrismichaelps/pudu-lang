---
type: handoff
status: DONE
issue: 995
aliases: [Native Ownership Delivery]
---

# Native Ownership Delivery

Architect → Backend Engineer → Test Engineer. Branch `feature/995-native-ownership`
starts from the native parity branch tip. This pass owns [[NATIVE-OWNERSHIP]],
[[Compiler Lower Array]], [[Compiler Frame Body]], [[Backend Frame Bodies]] and
[[Backend Frame Runtime]].

## Delivered

Backend Engineer → Test Engineer. The caller move and argument transfer are in place: `m = f(&m, ...)` moves `m` into the call when no other operand reads it, the caller clears its slot, and frame entry skips the retain for transferred parameters on both the heap and direct paths. A typed fast entry is taken only when no transfer is pending. Only counted aggregates (arrays, maps, sets, stores, records) move. [[Compiler Lower Tail Move]] moves the final read of a counted local, and [[Backend Emit Multi Map]] takes the key's array out of an exclusive tree path and updates both trees in place. The full property suite passes.

## Measurement

`bench/eval/MultiMap.pudu` with the optimized compiler (-O2) on Apple Silicon,
five samples: native 542 ms minimum / 548 ms median, tree 699/700 ms and
compiled 702/703 ms. Before the work the fixture measured native 3446 ms against
evaluator 830 ms. Maps and Records also sit below both evaluators; the figures
are in [[NATIVE-OWNERSHIP]]. [[Runtime Benchmark]] now has a native mode that
builds each fixture once, reports the build beside the samples and labels the
scopes; its focused tests pass.

## Exact next action

None; issue #995 closes with this measurement.

## Referenced by

[[handoffs/_MOC]] · [[NATIVE-OWNERSHIP]]
