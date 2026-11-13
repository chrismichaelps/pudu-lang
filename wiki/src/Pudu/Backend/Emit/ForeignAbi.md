---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/ForeignAbi.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Foreign ABI]
---
# Backend Emit Foreign ABI

The C side of every foreign crossing type (#852): its boundary type, the
conversions between it and a frame cell, and for each record a struct laid out
in declaration order, nested records as nested structs, so the C compiler gives
it the platform's own layout. Each record has a pack function (a record box to
its struct, text fields copied through the nought check into the call's held
copies) and an unpack function (a struct to a new box through the record's
constructor, text fields copied out and checked, temporaries released).

## Resolved Grill Log

- **Q:** Flatten nested records? **A:** Preserve each nested struct. The
  interpreter's libffi description now preserves the same tail padding (#863).
- **Q:** One site per text field for E7024? **A:** One site whose message is
  built at the call, naming the field as the interpreter does.

## Referenced by

[[Backend Emit Foreign]] · [[Native Foreign Call Sites]]
