---
type: module
path: "@root/test/Pudu/Backend/FrameRuntimeSpec.hs"
fidelity: Active
aliases: [Native Frame Runtime Tests]
---
# Native Frame Runtime Tests

## Purpose and interface

Export frameRuntimeProperties. Compile actual production frame executables under
strict C11, injecting counted calloc/free wrappers and an atexit leak assertion.
Verify normal nested returns, failed entry/callee allocations and correct output
prefixes. Source arithmetic/depth panics must also leave no live frame. Corrupt
test descriptor counts to exercise addition/multiplication overflow before any
allocator invocation. No production fault-injection switch or source semantics
change. Missing cc is visibly reported. Expected memory text/status is literal.

## Resolved Grill Log

- **Q:** Test a separate runtime prototype? **A:** No; call the production emitter and instrument its allocator at C preprocessing boundaries.
- **Q:** Rely on OS cleanup after exit? **A:** No; an atexit counter fails with status 97 on any live allocation.
- **Q:** Suppress generated warnings? **A:** No; require strict C11 warnings as errors.

## Dependencies and consumers

[[Backend Frame Program]] · [[Backend Frame Runtime]] · [[Host Failure Vocabulary]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]
