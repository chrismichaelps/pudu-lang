---
type: module
path: "@root/src/Pudu/Backend/Runtime/Frame.hs"
fidelity: Active
aliases: [Backend Frame Runtime]
---
# Backend Frame Runtime

## Purpose and interface

Export frameTypes and frameEngine as embedded C11 line lists. Types define
pudu_cell, pudu_frame, pudu_step and pudu_function. A frame owns a flexible
array of typed cells, split into slots and argument scratch; links point to
its live parent. The descriptor holds counts, parameter slot indices, entry
pc and constant-arity body callback. The engine follows call/return steps with
bounded C stack depth. Globals own the current scalar execution's top and
logical depth; concurrency and reentrant foreign calls remain unadmitted.

## Allocation, failure and lifetime

Check count additions and sizeof multiplication against SIZE_MAX before calloc.
Allocate at least one cell. Initialize parameter cells only after all caller
arguments complete. Calls check depth > callDepthLimit before allocation and
increment. Entry depth is 1. Return copies the step payload into the live
caller, frees the callee exactly once and decrements depth. Entry returns the
copied cell after all storage is freed. Install the runtime cleanup hook before
entry allocation; every source panic and host allocation failure unwinds frames
before exit. Partial allocation does not replace the live top until initialized.
Normal completion clears the hook. Invalid internal state unwinds then aborts;
it is not a user-source error or fallback.

Host allocation failures use [[Host Failure Vocabulary]], stderr and status 1;
they do not fabricate E7002. Source depth failures keep their original call site.
This scalar allocator cannot claim owned-value drop or concurrency coverage.

## Resolved Grill Log

- **Q:** Use automatic storage proportional to source size/depth? **A:** No; each payload is heap-owned and callbacks have constant arity.
- **Q:** Free the child before reading its return? **A:** The step already owns a value copy; transfer to the live parent before freeing the child.
- **Q:** Lose prior frames when calloc fails? **A:** No; the existing top remains published for the cleanup hook.
- **Q:** Match arbitrary OS kills? **A:** No; catchable/reported host exhaustion has the shared process contract.

## Dependencies and consumers

[[Backend Runtime]] · [[Backend Frame Bodies]] · [[Native Execution Frames]]

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]
