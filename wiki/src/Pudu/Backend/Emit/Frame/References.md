---
type: module
path: "@root/src/Pudu/Backend/Emit/Frame/References.hs"
fidelity: Active
aliases: [Backend Frame Slot References]
---

# Backend Frame Slot References

Traverse slot references of each instruction, value shape and terminator
in [[Core Frame IR]]. [[Backend Frame Slots]] uses the same traversal
to collect references and rewrite them. Preserve constructors, spans,
metadata and reference order.

## Resolved Grill Log

- **Q:** Use a catch-all for standalone value shapes? **A:** Cover every
  constructor explicitly so a new shape with a slot becomes a compiler
  warning until the traversal accounts for it.

## Referenced by

[[Backend Frame Slots]] · [[Core Frame IR]]
