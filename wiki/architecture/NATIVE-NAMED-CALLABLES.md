---
type: architecture
aliases: [Native Named Callable Dispatch]
tags: [backend, callables, runtime]
---
# Native Named Callable Dispatch

A named function used as a value must enter its actual function once. The
current generated forwarding function introduces an extra counted frame and
can report E7002 at the reference instead of the invocation. Remove that
forwarding call; preserve the existing refcounted callable box and its cell-0
function identity, display name, equality site and empty captures.

## Resolved Grill Log

- CoreClosureInfo gains closureHasEnvironment. Lifted lambdas set it true;
  named targets set it false. This is explicit ABI metadata, never inferred
  from a display name, capture count or parameter type.
- Named closures point directly at the admitted target, enqueue that target
  and register its observation metadata. They do not generate a new function.
- Layout collection derives a named callable's full type from its actual
  parameter/result types. A lifted lambda still takes its callable type from
  its explicit first environment parameter. Zero-argument named functions
  must still appear in their callable layout.
- A call-through-value step marks closure_call and retains the scratch layout
  [closure, arguments...]. The dispatcher skips scratch cell zero only when
  the target does not take an environment. Parameter counts and source depth
  checks remain strict, and the step keeps the actual invocation span.
- Each actual source function call checks and increments depth exactly once.
  Direct calls, lambda captures, result transfer and unwind ownership retain
  their existing paths. The caller owns the skipped callable box until its
  ordinary slot cleanup; it is neither a target parameter nor a leaked value.
- Append environment metadata to pudu_function and closure_call to pudu_step;
  bump private runtime revision to 14. Validate function/argument bounds before
  using the new offset. No syntax or evaluator changes.

## Evidence obligations

Prove the old early failure at the exact recursive boundary and the invocation
span on the first excessive call. Cover zero/multiple/owned arguments, mixed
named/lambda values, rendering/equality, higher-order return and all tracked
allocations. Run focused Clang/GCC/ASan+UBSan and both evaluators, plus frame
allocator, closure-shape and deterministic-emission regressions. Full-suite,
platform and independent review remain promotion obligations.

## Referenced by

[[Native Closures]] · [[Native Emission Coverage]] · [[Native Named Callable Delivery]] · [[Compiler Lower Lambda]] · [[Backend Frame Runtime]]
