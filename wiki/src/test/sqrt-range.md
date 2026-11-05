---
type: module
path: "@root/test/sqrt-range.py"
fidelity: Active
aliases: [Square Root Range Gate]
tags: [module, math, test]
---
# Square Root Range Gate

## Purpose and algorithm

Use a supplied compiler and repository library root to generate a temporary Pudu program.
Golden positive cases include 1e±300, subnormal/normal boundaries, maximum finite, powers and
adjacent floats across exponents, rung boundaries and deterministic random finite bit patterns.
Compare output with host math.sqrt bit for bit: the kernel is correctly rounded. Domain output checks negative/NaN
refusal, positive infinity and both zero signs. Require the existing Float math fixture's
twenty checks and formatting of the changed module and [[Root Kernel Benchmark]].

Optional `--bench` runs that benchmark, parses consumed-result timings and sampled relative
errors, and prints JSON medians/accuracy rather than asserting machine-dependent speed.
A second generated program checks exact-kernel contracts: signed zeros through floor, ceil and
trunc, half-away rounding including 0.49999999999999994, single-rounding fma, bit round-trips
and the smallest subnormal, and every `Option` domain refusal. A checked call of `floatSqrt` with
an integer must be refused. Temporary files always disappear. [[Pudu Continuous Verification]] registers the correctness
check; benchmarking stays explicit. No full gate invocation or C11 build.

## Resolved Grill Log

- **Q:** Assert only a relative tolerance at ordinary values? **A:** No; bit-distance goldens
  cover exponent boundaries and subnormals, where the old initial guess failed catastrophically.
- **Q:** Keep a two-ULP budget? **A:** No; the hardware root is correctly rounded, so any
  distance is a regression.
- **Q:** Turn one benchmark into a native speed promise? **A:** No; report current runtime and
  sampled accuracy separately, and adopt no approximate engine API without justified benefit.

## Referenced by

[[Std Math Float]] · [[Root Kernel Benchmark]] · [[Square Root Delivery]] · [[src/_MOC]]
