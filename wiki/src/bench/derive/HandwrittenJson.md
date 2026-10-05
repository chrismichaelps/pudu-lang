---
type: module
path: "@root/bench/derive/HandwrittenJson.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, bench, derive]
---

# HandwrittenJson Benchmark Input

## Purpose and contract

Encodes 40,000 orders of two lines each with hand-written `Encode` implementations writing the same object literals and prints the total encoded length.

## Grill Log

- **Q:** Print the encoded text? **A:** No; the length proves equality with the other input without measuring output.

## References

[[Derive Benchmark]]
