---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Foreign/Extent.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Foreign Extent]
---

# Foreign Extent

Describe a declared length's unit and the native parameters it bounds.
The checked relation contains the length's native index and a nonempty,
ordered set of target indices.

## Resolved Grill Log

- Keep indices after declaration checking. The interpreter sees native
  positions and lowering translates them to caller positions when omitting
  output and callback context slots.
- Keep element counts and byte sizes distinct. The ABI supplies the size
  of a typed element when conversion to bytes is necessary.

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Foreign Pointers and Runs]] · [[Foreign Crossing]]

## Resolved Grill Log for foreign syntax cache

The extent unit has a generic representation for stored syntax tags.
