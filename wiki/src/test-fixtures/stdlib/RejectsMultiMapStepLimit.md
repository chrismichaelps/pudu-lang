---
type: module
path: "@root/test-fixtures/stdlib/RejectsMultiMapStepLimit.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, stdlib]
---

# RejectsMultiMapStepLimit

## Purpose and interface

A constant-building MultiMap loop keeps the original bounded evaluator iteration refusal E7002. The focused compatibility check runs
both evaluators against the original and optimized library and asserts E7002.

## Dependencies and consumers

Imports [[Std MultiMap]]. Used by focused MultiMap diagnostic validation.

## Grill Log

Resolved: keep the refusal code, source span, and nonzero exit behavior. Do not
raise arithmetic bounds or constant evaluation limits to improve a benchmark.

## Referenced by

[[src/_MOC]] · [[Eval MultiMap Kernel]]
