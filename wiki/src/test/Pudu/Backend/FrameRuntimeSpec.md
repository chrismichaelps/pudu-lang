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

## Owned output allocation accounting (#568)

Resolved Grill Log: count malloc as well as calloc because source output
Results now allocate text and boxes. Keep calloc failure-attempt numbering and
all exact output/status assertions; retain strict C warnings and the zero-live
allocation check. Refer to the malloc wrapper in the test entry so scalar-only
probes still compile without suppressing unused-function diagnostics.

## Aggregate length overflow (#569)

Resolved Grill Log: production-emitted tuple programs carry text_join. Inject
synthetic huge part lengths with separators or labels before source execution
and require exact memory-failure status/text with zero live allocations. This
checks rejection before byte access without allocating enormous host buffers.
Keep all original frame failure-attempt and source-panic assertions.

## Diagnostic ownership (#570)

Resolved Grill Log: Add counted dynamic E7001/E7008 and computed-help E7004 source failures. Require preserved stdout, status one, diagnostic/message/help evidence and no live allocations. Add a synthetic combined-length overflow rejection before byte access. Respect PUDU_CC in this existing harness so focused GCC/sanitizer runs exercise the actual cases.

The focused runtime harness now fails explicitly when its selected compiler is
missing; no unsupported compiler run is counted as successful evidence.

Synthetic empty message/help views also verify release of the minimum copied
allocation and preservation of an explicitly present empty help line.

The same dynamic-failure cases also run through the isolated compiled/tree
output oracle, with identical saved source paths. Require byte-for-byte
stdout/stderr and exit-status equality in addition to allocation accounting.
This keeps exact computed-help/source-span validation in the focused lane.
