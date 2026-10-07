---
type: module
path: "@root/test-fixtures/stdlib/UsesAppMetricsConcurrent.pudu"
fidelity: Active
tags: [test, application, measurements, concurrency]
aliases: [Uses App Metrics Concurrent]
---
# Uses App Metrics Concurrent

## Purpose and algorithm

Eight bounded workers answer 512 requests across two status labels. Exact counter and duration
counts retain all 256 observations per status. An independently synchronized active-handler count
proves handlers still overlap. Verify exact rendered output, separate application stores and unchanged
answers when a measurement cell is missing. A failed assertion names its invariant; success returns
exactly zero through both protocol evaluators.

## Resolved Grill Log

- **Q:** Serialize handlers to obtain correct totals? **A:** No; only snapshot updates hold the lock.
- **Q:** Accept approximate totals because scheduling differs? **A:** No; every observation is retained.
- **Q:** Treat a measurement failure as a request failure? **A:** No; preserve the handler's answer.

## Referenced by

[[Std App]] · [[Protocol Evaluation Spec]] · [[src/_MOC]]
