---
type: module
path: "@root/test/Pudu/Eval/BinarySpec.hs"
fidelity: Active
aliases: [Binary Codec Properties]
tags: [module, test, runtime, serialization]
---
# Binary Codec Properties

`binaryProperties` runs native codec properties through the ordinary test runner and manifest.
Generate bounded trees containing every node form, arbitrary signed 64-bit integers and arbitrary
binary64 bits, raw/reals blocks, Unicode, options, arrays and named record/variant fields.
Normalize write-side Fields/Choice into read-side maps before comparing re-encoded canonical
bytes; this retains exact float bits while allowing field order to change on map decoding.
Check every strict truncation of a generated encoding, fixed malformed tags/flags/UTF-8/counts,
name indices and duplicate fields, nesting at 512/513, trailing bytes and invalid writer inputs.
Independent golden bytes pin the little-endian integer and floating representation.

## Resolved Grill Log

- **Q:** Compare floating values with Eq? **A:** No; NaNs are unequal and signed zeros equal.
  Canonical bytes plus independent golden bit patterns protect the actual representation.
- **Q:** Demand identical field order after map decoding? **A:** No; compare canonical map
  encodings, preserving names/values while accepting declaration-order differences.
- **Q:** Leave random tree size to chance? **A:** No; depth and child count are explicitly capped.
- **Q:** Treat random byte acceptance as a round-trip oracle? **A:** No; malformed fixed wire
  cases and every strict truncation must refuse with the expected cause.

## Referenced by

[[Eval Binary]] · [[Repository Test Runner]] · [[Pudu Test Cabal Manifest]] · [[src/_MOC]]
