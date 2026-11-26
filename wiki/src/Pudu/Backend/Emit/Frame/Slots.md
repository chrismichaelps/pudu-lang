---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/Slots.hs"
fidelity: Active
aliases: [Backend Frame Slots]
---

# Backend Frame Slots

Compact a frame module's physical storage according to [[Native Frame Slot Reuse]]. A function's instruction intervals use emission order and contain
their first and last operations. Slots outside a basic block's proven lifetime
keep their own storage. Select the lowest available slot of the same type.
Rewrite all parameters, instructions, terminators and physical descriptors.

## Resolved Grill Log

- **Q:** What lets an interval end for owned values? **A:** A move out
  already clears the source. Every path to subsequent reuse has executed
  that move.
- **Q:** What if nothing can share a slot? **A:** Keep the original function
  so its slot numbering and diagnostic behavior stay stable.

## Referenced by

[[Backend Frame Program]] · [[Native Frame Slot Reuse]]
## Drop slots keep their place (#1028)

A slot a stop may drop is fixed for the whole frame, like a parameter or a
terminator slot, and it is renamed with the other slots when the frame is
compacted.

Resolved Grill Log: a drop table names slots by number, so a compacted frame
would otherwise point the table at the wrong slot.
