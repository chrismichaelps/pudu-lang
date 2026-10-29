---
type: module
path: "@root/.github/workflows/ci.yml"
fidelity: Active
tags: [test, delivery]
aliases: [Pudu Continuous Verification]
---
# Pudu Continuous Verification

## Purpose and interface

[[Ark Layer Tests]] and [[Ark Layer Gate]] execute with the application graph checks before
compiler builds. Resolved Grill Log: engine layer contracts are enforced on integration requests.
[[Lanes Gate]] runs after the binary64 kernel gate, then [[Lane Collection Gate]].
[[Square Root Range Gate]] runs after the residency check against the resolved compiler path; its
optional timing mode is not a CI performance assertion. Resolved Grill Log: numeric boundary
regressions are repeatable and bit-exact, so they belong in CI rather than a manual run.

Verify development and production integration requests and branch updates. Compiler checks use
an optimized build and a shared executable path. The full suite, source formatting and acceptance,
documentation examples, website suites, package flows, sandbox refusal, diagnostics, release
selection, live language services, generated projects, API coverage and streaming residency retain
their existing obligations. The application graph model tests and actual library gate run first.

## Resolved Grill Log

- **Q:** Make architectural validation a manual-only check? **A:** No; integration executes it.
- **Q:** Replace behavioral tests with a clean dependency graph? **A:** No; both remain mandatory.

## Referenced by

[[Application Layer Gate]] · [[Repository Gates]]

## Derive index contract (#458)

[[Derive Index Output Gate]] runs against the built executable after documentation output checks, exercising root visibility, structured metadata, standard strategies and failure output.

Resolved Grill Log: command serialization is verified through the actual executable rather than only encoder properties.
