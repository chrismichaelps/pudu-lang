---
type: handoff
status: IN_REVIEW
issue: 668
aliases: [Lane Delivery]
tags: [handoff, delivery, performance]
---
# Lane Delivery

Branch feature/668-float-lanes stacks on the binary64 kernels (#661, #665) because it extends
the same builtin, checker and resolver tables. Role transitions: Language Architect → Runtime
Engineer → Library Engineer → Test Engineer → independent Language Architect and Forensic
Guardian.

Observed gap: no packed numeric storage served a hot loop. Array values are persistent boxed
sequences, `Std.Buffer.writeF64` copied its whole byte string per write and `Std.Column`
rebuilt columns per append. Delivered [[Lane Kernel Identity]], [[Runtime Lanes]],
[[Eval Builtin Lanes]] and [[Std Lanes]]: value-semantics lanes whose whole-lane kernels make
one native pass each. Malformed bytes abort with E7012; mismatches and bad indices answer `None`.

Evidence: [[Lanes Fixture]] matches every kernel with its scalar definition, including signed
zeros and NaN extremes; [[Lanes Gate]] adds positioned type and partial-value refusals and runs
in CI. [[Lanes Benchmark]] measurements are recorded in the pull request. No full gates were
run locally, by request.

Exact next action: merge lanes into the engine branch and build Ark.Core and the World archetype
store with component columns as lanes.

## Referenced by

[[handoffs/_MOC]] · [[Std Lanes]]
