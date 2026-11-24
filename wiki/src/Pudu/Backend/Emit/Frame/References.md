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

Resolved Grill Log: a variant switch rewrites only its subject slot. Tags
and labels are independent of physical slot allocation.

## Resolved Grill Log

- **Q:** Use a catch-all for standalone value shapes? **A:** Cover every
  constructor explicitly so a new shape with a slot becomes a compiler
  warning until the traversal accounts for it.

## Resolved Grill Log for #876 — Native callback lowering

Rewrite the saved callback handler or token slot during physical slot
compaction. The ABI signature contains no frame IDs.

## Resolved Grill Log for #877 — Post-call settlement

Foreign loan settlement refers to no frame slots.

## Referenced by

[[Backend Frame Slots]] · [[Core Frame IR]]

## Stored callable dispatch (#956)

Resolved Grill Log: The closure-target test refers to its closure slot. Linked body identity is independent of slot allocation.
