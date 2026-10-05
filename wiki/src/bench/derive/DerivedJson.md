---
type: module
path: "@root/bench/derive/DerivedJson.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, bench, derive]
---

# DerivedJson Benchmark Input

## Purpose and contract

Encodes 40,000 orders of two lines each with derived `Encode` implementations, honouring `@json` and `@skip` and prints the total encoded length.

## Grill Log

- **Q:** Print the encoded text? **A:** No; the length proves equality with the other input without measuring output.

## References

[[Derive Benchmark]]
