---
type: module
path: "@root/src/Pudu/Eval/Builtin/Lanes.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, performance, lanes]
aliases: [Eval Builtin Lanes]
---

# Eval Builtin Lanes

## Purpose and interface

`callLaneKernel` converts runtime values for [[Runtime Lanes]] and wraps results: `Option`
results become `Some`/`None`, three lanes a tuple. Bytes whose length is not a multiple of eight
abort with E7012 before any kernel runs; so do arguments outside the signature, which only an
unchecked call can supply. Minimum and maximum treat NaN as missing; `floor` reuses the exact
float kernel.

## Grill Log

- **Q:** Treat raster color storage as binary64? **A:** No; both raster entries exempt only
  their first RGBA8 argument from alignment checks. Depth and all vertex lanes remain checked.
  The perspective entry dispatches its extra homogeneous-w lane to the shared raster driver;
  expected size/weight failures remain None, while malformed lane storage retains E7012.

- **Q:** Return `None` for malformed bytes? **A:** No; `Std.Lanes` never builds them, and its
  checked `fromBytes` refuses them. Reaching a kernel with them is a program defect.

## Referenced by

[[Lane Kernel Identity]] · [[Eval Call]]
