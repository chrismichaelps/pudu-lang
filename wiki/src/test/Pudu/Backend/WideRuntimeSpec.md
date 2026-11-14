---
type: module
path: "@root/test/Pudu/Backend/WideRuntimeSpec.hs"
fidelity: Active
aliases: [Native Wide Runtime Tests]
grammar: "[[grammar/haskell]]"
---
# Native Wide Runtime Tests

## Purpose and interface

Export wideRuntimeProperties :: [(String, IO Property)]. Compile and execute
actual selected [[Backend Runtime]] parts, without a failure stub. Prove decimal
output/status against independent Integer answers, and minimal wide helper
closures plus exact real diagnostic rendering. Use existing process/text/temp
packages and PUDU_CC or cc; a missing compiler fails this required gate.

## Algorithm and invariants

Exercise endpoints, word crossings, full-width samples, deferred positive
2^127 and transient negative zero. Compare full stdout/status/stderr. Invoke
every wide operation helper in a minimal translation with actual renderer
prerequisites. A checked overflow program prints a marker before its E7005 and
exits one; expected diagnostic bytes are explicit. Compile strict optimized C11
with warnings as errors, then run GCC, sanitizers and full repository gates.
Fixed IO corpora run once; primitive runtime evidence does not admit source
kinds or prove future frame/owned-value cleanup.

## Resolved Grill Log

- **Q:** Keep using the failure stub? **A:** No; the actual renderer must compile and execute.
- **Q:** Compare decimal output only below 64 bits? **A:** No; include both 128-bit extrema and full-width samples.
- **Q:** Hide status truncation behind output? **A:** Check every status separately in the executed program.

## Dependencies and consumers

[[Backend Runtime]] · [[Backend Wide Integer Display]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Wide Runtime Delivery]]
