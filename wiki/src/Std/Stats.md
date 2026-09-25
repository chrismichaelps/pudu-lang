---
type: module
path: "@root/lib/Std/Stats.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, numeric, statistics]
aliases: [Std Stats]
---

# Std Stats

## Purpose and interface

Descriptive statistics over `Float` samples, plus a single-pass accumulator for streams.

Exports:
- `type Summary = { count, minimum, maximum, mean, deviation }`.
- `type Running = { count, mean, squares, minimum, maximum }`: constant-size streaming state.
- `mean`, `median`, `percentile(values, rank)` (linear interpolation between order statistics, rank 0–100).
- `variance` (n − 1), `populationVariance` (n), `deviation` (sample).
- `covariance`, `correlation` (Pearson) over paired samples.
- `histogram(values, low, high, buckets) -> Array[Int]` over `[low, high)`.
- `summarize(values) -> Option[Summary]`.
- `running()`, `observe(state, value)`, `runningMean`, `runningVariance`.

## Semantics

- Every function returns `None` where the statistic is undefined: an empty sample, fewer than two
  values for a sample variance, mismatched pair lengths, a rank outside 0–100 or NaN, or a constant
  side in a correlation. No sentinel value is returned.
- Variance is computed with Welford's update, so a sample with a large mean and small spread keeps
  its precision; `summarize` and the `Running` accumulator share that update.

## Grill Log

- **Q:** Generic over numeric traits? **A:** No. _Rationale:_ a mean of integers is not an integer,
  and statistics over `Decimal` need a rounding policy `Std.Decimal.mean` already names.
  _Rejected:_ `T: Add + Div` signatures that truncate.
- **Q:** Which percentile definition? **A:** Linear interpolation between the order statistics at
  `rank / 100 * (n - 1)`, the definition most analysis tools default to; its median equals the
  textbook median for both parities.
- **Q:** Why a streaming accumulator? **A:** Summarising a file or a metrics stream should not
  require holding it; `Running` holds five numbers for any input length.

## Dependencies and consumers

- Depends on `Std.List` and [[Std Math Float]].
- Consumed by benchmarks, metrics summaries, and data programs.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]]
