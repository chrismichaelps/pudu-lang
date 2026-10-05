---
type: module
path: "@root/bench/service/Service.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, benchmark, http]
aliases: [HTTP Benchmark Service]
---

# HTTP Benchmark Service

## Purpose and interface

The request harness starts this real loopback service, waits for its announced
ephemeral port, then measures fixed text, JSON construction/encoding and HTML
rendering routes. The first program argument supplies its connection budget.
`main` returns a nonzero status when listening fails and otherwise stops after
the requested connection count. Missing/invalid counts retain the 2000 default.

## Algorithm and invariants

Build the routing table, start the existing worker-pool server, print the ready
port, serve the requested budget, and stop the listener. `numberOf` accepts
nonempty ASCII decimal text. The CLI exposes only carried program arguments:
`Env.at(0)` is the budget; executable/subcommand/source names are absent.
Routes preserve their actual document/page work and use ordinary STD APIs.

## Dependencies and consumers

Uses [[Pudu CLI]], `Std.Env`, [[Std Http Server]], [[Std Json]], [[Std Html]]
and their existing route/reply, environment, IO and Option helpers.
Consumed by `bench/request.mjs`; linked from [[src/_MOC]].

## Failure and negative logic

No guessed readiness delay, fixed port, route shortcut, omitted request work or
benchmark recognition in the compiler. A failed/early-stopped server is a failed
measurement, not a completed throughput sample.

## Grill Log

- **Q:** Read the budget at index one? **A:** No; the CLI contract starts carried
  arguments at zero. Index one silently selected the 2000 default and a larger
  unchanged harness run stopped early with ECONNREFUSED. Fix the fixture to the
  existing argument contract before comparing collector defaults.
- **Q:** Lower the request count to hide the early stop? **A:** No; validate the
  original requested budget with a larger run and retain all three routes.
- **Q:** Change library/server behavior for the fixture? **A:** No; only the
  fixture's argument index changes. Both compared executables use that same
  source, workload and connection count.

## Referenced by

[[src/_MOC]] · [[Pudu CLI]]
