---
type: module
path: "@root/bench/BinaryBench.pudu"
fidelity: Active
aliases: [Binary Serialization Benchmark]
tags: [module, performance, serialization]
---
# Binary Serialization Benchmark

A deterministic level of 1,000 entities derives [[Std Binary]] Encode/Decode and JSON Encode/Decode.
Each entity has a name, position/velocity float arrays, health, tags and optional owner. After
setup and warmup, measure five framed binary writes/reads and JSON writes/reads separately with
the monotonic nanosecond clock. Consume the final values through whole-level round-trip equality;
report nanoseconds per operation and serialized byte sizes. No window, file IO or setup is timed.

## Resolved Grill Log

- **Q:** Compare a binary node encoder with full JSON encoding? **A:** No; both timings include
  derive tree construction, and both reads include typed reconstruction. Binary includes framing
  and CRC-32; report that difference, and never infer game FPS from serialization timings.
- **Q:** Accept impressive timing without checking decoded data? **A:** No; both final results
  must equal the original level before any results are reported.
- **Q:** Gate on elapsed time? **A:** No; measurements are machine-specific, while equality is a
  deterministic gate. This benchmark is evidence rather than a cross-machine performance promise.

## Referenced by

[[src/_MOC]] · [[Std Binary]] · [[Binary Validation Delivery]]

## Measured sample

Apple M1, 8 GiB RAM, optimized interpreter build, three sequential runs of five operations each:
median binary write 27.526 ms/read 52.821 ms; JSON write 31.190 ms/read 91.472 ms. Framed binary
140,995 bytes versus JSON 130,012 bytes (about 8.45% larger). Both include tree construction and
typed reconstruction; binary also checks its frame CRC. These local means do not establish
latency distributions or cross-machine guarantees.
