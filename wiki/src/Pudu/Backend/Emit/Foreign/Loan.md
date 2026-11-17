---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Foreign/Loan.hs"
fidelity: Active
grammar: C11
aliases: [Backend Emit Foreign Loan]
---

# Backend Emit Foreign Loan

Emit the ABI pointer signature and the caller-facing C wrapper for scalar
and record loans. C locals hold copied pointees. A mutable wrapper returns
the source result followed by the loan finals in source input order.

## Interface

- `loanWrapper` emits the loan wrapper and its protected call boundary.
- `foreignCallName` selects the caller-facing symbol.
- `loanResult` and input queries describe the tuple and native parameters.

## Resolved Grill Log

- Keep scratch locals in the outer wrapper. The inner jump boundary may
  return after C has changed those locals, and their values remain defined.
- Arm diagnostic capture after the native function returns. The protected
  boundary returns mutable finals before the calling frame replays a report.
- Pack records with [[Backend Emit Foreign ABI]] so the native type supplies
  alignment and padding. Never pass an address into a Pudu aggregate box.

## Resolved Grill Log for #877 — C11 array crossings

Copy runs into aligned storage after checking element and byte extents. Use sizeof at the target for stride. Unpack mutable runs into independent Pudu arrays before releasing the scratch, and release it before delivering failure.

## Resolved Grill Log for #877 — Returned run copying

Share ABI array decoding between copy-out and returned allocations. The caller retains responsibility for validation and for the native allocation’s ownership.

## Resolved Grill Log for #877 — Native nullable loans

Generate null without allocating scratch for an absent loan. Its array extent is zero, while a present zero-length array still allocates scratch.

## Referenced by

[[Backend Emit Foreign]] · [[Backend Module Map]] · [[Foreign Pointer Delivery]]
