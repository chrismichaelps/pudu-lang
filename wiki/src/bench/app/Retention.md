---
type: module
path: "bench/app/Retention.pudu"
fidelity: Active
tags: [benchmark, application, resources]
aliases: [App Retention Probe]
---
# App Retention Probe

## Purpose and algorithm

Load the application dependency closure, compose one server handler and invoke it sequentially.
Each request carries a distinct body and must receive its exact successful response. The environment
setting `PUDU_RETENTION_COUNT` selects 1..1000000 requests, defaulting to 100. Print the completed count
and return zero. This isolates request containment from transport and production concurrency.

## Resolved Grill Log

- **Q:** Claim capacity from this workload? **A:** No; compare retained-memory growth under identical
  handler loads. Startup, dependency linking and evaluator overhead remain in the measurement.

## Referenced by

[[Std Http Server]] · [[2026-10-07-runtime-disposal]] · [[src/_MOC]]
