---
type: module
path: "@root/bench/layers.mjs"
fidelity: Active
tags: [module, tooling, performance]
aliases: [Dependency Layer Report]
---

# Dependency Layer Report

## Purpose and interface

Generate an offline, reusable HTML treemap and companion JSON for the Haskell
compiler's source import graph, optionally joined to measured GHC costs.
`node bench/layers.mjs --root packages/pudu/v0.1 --profile run.ticky
--out /tmp/pudu-layers.html --label "MultiMap tree"` selects explicit inputs.
Profile is optional; no profile means structural module/coupling views only.
`--json path` chooses the companion destination. Default output is an invocation
owned temporary directory. `--help` documents options. Never build implicitly.

## Algorithm and dependencies

Walk the source root in stable order, excluding build/cache/vendor directories
and symlinks; read .hs files and fail on duplicate module identities. Use
[[Dependency Layer Model]] for import extraction, SCC condensation, dependency
layers and exclusive profile attribution; [[Dependency Layer View]] renders
interactive HTML. SHA-256 hashes identify the source corpus and supplied profile.
Record source paths, capture time and optional caller label, but do not assert
that a profile was produced from those sources. Costs of unmatched modules stay
visible separately. Write HTML and JSON only to caller-selected destinations;
refuse to overwrite a source or supplied profile. No private inputs are read.

## Negative logic and failures

Invalid options, missing/empty roots, unsupported or malformed profiles, duplicate
modules and unsafe output collisions fail with actionable stderr and nonzero
status. Missing CPU/entry measures stay null, not zero. A graph cycle is a source
import cycle, including SOURCE imports, not proof of a runtime bug. Profiling
allocation is cumulative allocation, not RSS or retained heap. Haskell bootstrap
latency and native code generation are outside this tool's measurements.

## Resolved Grill Log

- **Q:** Infer resource costs from dependency count? **A:** No; structural
  metrics are separate and measured cost columns require a supplied profile.
- **Q:** Assume matching sources because names join? **A:** No; report both
  hashes and require the caller to establish build provenance independently.
- **Q:** Add a server or remote chart library? **A:** No; HTML works offline,
  uses native accessible controls and includes escaped data without network calls.
- **Q:** Rebuild the compiler on report invocation? **A:** No; profiling remains
  an explicit, separate experiment, and ordinary performance acceptance uses the
  uninstrumented executable.

## Referenced by

[[src/_MOC]] · [[Benchmark Guide]] · [[Dependency Layer Tests]] ·
[[handoffs/2026-10-01-derive-integration]]
