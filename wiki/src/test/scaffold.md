---
type: module
path: "@root/test/scaffold.mjs"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, cli, scaffold]
aliases: [Generated Project Gate]
---

# Generated Project Gate

## Purpose and interface

Given the path to a freshly built `pudu` executable, create a project outside the repository and
exercise the commands its README promises: check, run, test, lint, formatter check, build, and bundled
execution. It also changes one assertion and requires `pudu test` to fail visibly.

## Governance and algorithm

The gate checks every expected Pudu layer and reads their imports to prove the generated graph is
`Main -> App.Greeting -> Domain.Greeting`, with no outward import from the domain. Running outside
the checkout catches distribution-only standard-library failures. Linting proves the template
starts with no policy debt. The temporary project and large
bundle are removed on both successful and failing assertions.

## Grill Log

- **Q:** Treat file existence as a working scaffold? **A:** No. _Rationale:_ imports, test
  discovery, bundling, and distribution lookup can fail only when commands execute. _Accepted:_ run
  the complete first-use workflow. _Rejected:_ template snapshots alone.
- **Q:** Check only a passing generated test? **A:** No. _Rationale:_ a test command that reports
  every suite as passing is worse than no test command. _Accepted:_ mutate one expected value and
  require a visible failure.

Resolved Grill Log: the generated project is verified as an executable Pudu dependency graph from
outside repository state.

## Referenced by

[[Repository Gates]] · [[Pudu CLI Init]] · [[Pudu CLI Init Spec]]
