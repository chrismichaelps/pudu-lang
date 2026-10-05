---
type: module
path: "@root/bench/layers.test.mjs"
fidelity: Active
tags: [module, test, tooling, performance]
aliases: [Dependency Layer Tests]
---

# Dependency Layer Tests

## Purpose and interface

`node --test bench/layers.test.mjs` validates [[Dependency Layer Report]],
[[Dependency Layer Model]] and [[Dependency Layer View]] without building GHC.
Fixtures and CLI outputs live in invocation-owned temporary directories and are
removed on completion. Browser smoke supplements the pure model/HTML checks.

## Test contract

Cover diamond dependencies, cycles, self edges, stable layers, external imports,
duplicate identities and long chains. Fake imports in nested comments or strings
must not enter the graph. Check safe, qualified, package and multiline imports.
Profile fixtures distinguish individual from inherited cost, complete trees from
flat summaries, and ticky Alloc from Alloc'd. Preserve global/local/unattributed
owners, reject malformed numbers and tables, and retain unknown cost as null.
HTML hostile labels cannot terminate embedded JSON or become executable markup.
CLI success emits parsable JSON and offline HTML; invalid flags/profiles and
source/profile destination collisions fail without replacing input files.

## Resolved Grill Log

- **Q:** Test only implementation-shaped snapshots? **A:** No; independent
  small graph oracles and deliberately different allocation columns establish
  mathematical layers and prevent real cost double-counting regressions.
- **Q:** Require a compiler rebuild for report tests? **A:** No; small authentic
  format fixtures establish parsing contracts. A fresh actual workload separately
  establishes end-to-end attribution against the current compiler.

## Referenced by

[[Dependency Layer Report]] · [[src/_MOC]] · [[Benchmark Guide]]
