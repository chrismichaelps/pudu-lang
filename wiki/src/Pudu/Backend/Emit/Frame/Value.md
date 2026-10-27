---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/Value.hs"
fidelity: Active
aliases: [Backend Frame Values]
---
# Backend Frame Values

## Purpose and interface

Export frameValue, slotText and cellMember. Translate pure FrameValue operations
to C expressions over stable frame->slots, preserving canonical integer kind
descriptors and shared arithmetic/shift diagnostic sites. Return Either FrameFault
(EmitState, expression Text, runtime root Set). No source evaluation, allocation,
implicit conversion, compiler/frontend import or host exception.

## Contract and failures

The private cell union uses integer for CoreIntegerType and scalar for Bool/Unit.
Text/Never payloads fail as data. Checked arithmetic, remainder, divide, shifts,
wrapping, saturation and comparisons select the existing production helpers;
logical binary operations are rejected because they require basic blocks.
Descriptor failures are located FrameFault data. Operands are already snapshots.
Only emitted values select helper roots; caller closes dependencies transitively.

## Resolved Grill Log

- **Q:** Re-evaluate a source operand while rendering? **A:** No; only slot reads occur.
- **Q:** Narrow a deferred positive integer? **A:** No; reuse the exact carrier.
- **Q:** Guess an integer descriptor? **A:** No; reject missing canonical metadata.

## Dependencies and consumers

[[Core Frame IR]] · [[Backend Emit State]] · [[Backend Emit Support]] · [[Backend Frame Bodies]]

## Referenced by

[[src/_MOC]] · [[Native Execution Frames]]
