---
type: module
path: "@root/bench/TextBench.pudu"
fidelity: Active
aliases: [Ark Text Benchmark]
tags: [module, ark, performance, text]
---
# Ark Text Benchmark

Lays out a 640 by 480 screen of text (40 lines of 80 characters; spaces add no glyph) into one [[Ark
Text]] batch and draws it, 10 times each. Prints nanoseconds per layout and per draw, and panics
unless the batch holds exactly one glyph per visible character and the draw lights pixels.

## Referenced by

[[Ark UI Gate]] · [[Ark Text]]
