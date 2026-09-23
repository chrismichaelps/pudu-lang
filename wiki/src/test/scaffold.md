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
It additionally creates a named library through the real CLI, adds a local Git dependency, installs
the graph twice to prove stable lock content, checks and tests it, and verifies its manifest against
the package identity and publication shape. A separate generated application installs the released
library tag and imports its root, catching dependencies that work only in the publisher's tree.
The library receives a local Git dependency, commits its stable lock, and publishes a tag to a
temporary bare remote through `pudu release`. No public network or repository is touched.
The application's missing-import help must name `src` alone for a file under `src/` and
`test, src` for a suite under `test/`, both with the generated manifest and with one that still
declares `src = "src"` and `./src/` as self dependencies; `pudu test` passes under each. A
declaration search over a generated source file must answer from that file, not from package search.

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
