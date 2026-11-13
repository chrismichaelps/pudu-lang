---
type: handoff
status: ACTIVE
issue: 854
aliases: [Native Foreign Slot Delivery]
---

# Native Foreign Slot Delivery

Language Architect → Backend Engineer. This branch carries [[Native Foreign
Handles Delivery]]. The first partition owns checked slot positions, scalar
slot storage, and tuple construction. ADR-0022 governs ordinary mutable
loans and their existing copy-in/copy-out lowering.

## Resolved Grill Log

Preserve declared ABI order independently of source operand order. The
wrapper initializes each scalar slot to zero and passes its address. The
checked tuple retains the native result, including unit, before the slot
values. Record, text, and handle slots require their own conversion and
ownership settlement before the full issue can close.

## Exact next action

Extend slot conversion to records and text, then settle owned handle slots
as a batch. Scalar differential and counted checks pass.

## Referenced by

[[handoffs/_MOC]] · [[Native Foreign Call Sites]]
