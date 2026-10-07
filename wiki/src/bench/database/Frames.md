---
type: module
path: "@root/bench/database/Frames.pudu"
fidelity: Active
tags: [benchmark, database, transport]
aliases: [Database Frame Benchmark]
---
# Database Frame Benchmark

## Purpose and interface

Measure consumption of 20,000 exact database frames sent in a batch over a real local connection.
Print elapsed milliseconds for the consumption loop. Construction and checking are outside that
interval. Every frame's kind and payload must agree before the benchmark succeeds.

## Algorithm

A joined sender owns a local accepted connection. The consumer uses the shipped session reader
and a fixed deadline, preserving the returned buffer after each message. Every resource is closed.
Compare the same built runtime, payload, count and host before and after; retain multiple samples.

## Resolved Grill Log

- **Q:** Treat local timing as a production capacity guarantee? **A:** No; it measures one workload.
- **Q:** Report faster incomplete consumption? **A:** No; every frame must validate.

## Referenced by

[[src/_MOC]] · [[Std Db Session]]
