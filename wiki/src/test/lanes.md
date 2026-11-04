---
type: module
path: "@root/test/lanes.mjs"
fidelity: Active
aliases: [Lanes Gate]
tags: [module, test, performance, lanes]
---
# Lanes Gate

## Purpose

Runs [[Lanes Fixture]], which compares every [[Std Lanes]] operation with its scalar result,
including length, index and NaN boundaries. Requires a positioned type refusal for an Array
passed as lanes and an E7012 abort for bytes that are not whole binary64 values. Checks
formatting of the module, fixture and [[Lanes Benchmark]]. `--bench` runs the benchmark and
prints JSON timings; it asserts equal results, not speed. Registered in
[[Pudu Continuous Verification]].

## Referenced by

[[Std Lanes]] · [[Lane Delivery]]
