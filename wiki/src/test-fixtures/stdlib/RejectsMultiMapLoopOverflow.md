---
type: module
path: "@root/test-fixtures/stdlib/RejectsMultiMapLoopOverflow.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, stdlib]
---

# RejectsMultiMapLoopOverflow

## Purpose and interface

Checked Int8 overflow inside a native MultiMap loop must retain the scalar addition span and E7005. The focused compatibility check runs
both evaluators against the original and optimized library and asserts E7005.

## Dependencies and consumers

Imports [[Std MultiMap]]. Used by focused MultiMap diagnostic validation.

## Grill Log

Resolved: keep the refusal code, source span, and nonzero exit behavior. Do not
raise arithmetic bounds or constant evaluation limits to improve a benchmark.

## Referenced by

[[src/_MOC]] · [[Eval MultiMap Kernel]]
