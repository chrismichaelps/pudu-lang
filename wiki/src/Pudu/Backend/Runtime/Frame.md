---
type: module
path: "@root/src/Pudu/Backend/Runtime/Frame.hs"
fidelity: Active
aliases: [Backend Frame Runtime]
---
# Backend Frame Runtime

## Purpose and interface

Export frameTypes :: Bool -> [Text] and frameEngine :: [Text] as embedded C11. Types define
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

## Item buffers (#556)

Resolved Grill Log: the cell union gains `pudu_items *items` wherever boxes
exist.

## Referenced by

[[src/_MOC]] · [[Native Frame Pressure Repair]]

## Wide frame bridge (#506)

Export frameTypes :: Bool -> [Text]. Add pudu_wide_int wide to pudu_cell only when the flag is true; narrow-only cells retain their exact layout. Keep frameEngine allocation, copies, cleanup and iterative dispatch unchanged. Resolved Grill Log: whole-cell copies preserve both wide words and sign, with no new ownership or C recursion. [[Native Wide Frame Bridge]].

## Floating cell member (#512)

`pudu_cell` gains `uint64_t floating`. The union is still the larger of its
members, so the narrow-layout check stays meaningful only for programs
without wide integers; floats keep the narrow cell at eight bytes.

## Text-aware frames (#515)

`frameTypes` adds `pudu_text text` to the cell only for programs with text.
`pudu_function` gains `texts`, `text_count` and `text_result`. A new frame
retains the text it receives; freeing a frame, on return or unwind, releases
its text slots; a returned text replaces (and releases) the destination's old
value, or is released when the call has no destination.

## Char cell member (#518)

`pudu_cell` gains `uint32_t character`, always present. It is narrower than
`pudu_int`, so no layout grows.

## Owned cells (#521)

`frameTypes` takes a third flag for boxes: it forward-declares `pudu_box`,
adds `pudu_box *box` to the cell, and writes the box struct, `pudu_box_new`
and `pudu_box_retain`. `pudu_owned` pairs a slot with its kind, and
`pudu_function` carries `owned_count`, `owned` and `result_kind`. The engine
retains entering arguments, releases owned slots when a frame ends, and drops
a replaced destination or a discarded result through `pudu_drop_cell`.
