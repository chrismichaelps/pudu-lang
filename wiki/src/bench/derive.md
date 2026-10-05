---
type: module
path: "@root/bench/derive.sh"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/pudu]]"
tags: [module, bench, derive]
aliases: [Derive Benchmark]
---

# Derive Benchmark

## Purpose and contract

`bench/derive.sh <pudu>` runs `bench/derive/DerivedJson.pudu` and
`bench/derive/HandwrittenJson.pudu` five times per evaluator and reports the
fastest run of each. Both encode the same 40,000 orders and print the total
encoded length; the script refuses to report if the two outputs differ.

## Measurements

2026-10-05, GHC 9.10.3, -O2, Apple silicon, fastest of five (seconds):
derived 0.96 tree / 0.78 compiled, handwritten 0.96 tree / 0.77 compiled.
`pudu expand` shows the derived encoder is the handwritten one.

## Grill Log

- **Q:** Compare against a push-accumulating handwritten encoder? **A:** No;
  against the array literal a person writes, which the derive must match.

## References

[[Derive Design]] · [[Derive Field Callbacks]] · [[src/bench/README]]
