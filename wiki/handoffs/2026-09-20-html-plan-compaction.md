---
type: handoff
status: COMPLETE
date: 2026-09-20
issue: 257
tags: [handoff, stdlib, html, ssr, performance]
aliases: [2026-09-20-html-plan-compaction]
---

# HTML Plan Compaction Handoff

## Objective

Resolve issue #257 with opt-in preparation that joins adjacent static text or byte runs once, while
preserving every existing plan API and treating dynamic typed slots as hard ordering boundaries.

## Ownership and role transitions

1. **Language Architect:** [[Std Html SSR]] and [[Std Html Buffer]] settle additive public APIs,
   compatibility, slot boundaries, retained-length metadata, and measurement limits.
2. **Runtime Engineer:** owns `Std/Html/Ssr.pudu`, `Std/Html/Buffer.pudu`, and their mirrors.
3. **Test Engineer:** owns `UsesHtmlCompact.pudu` and its explicit result in `ServiceSpec.hs`.
4. **Forensic Guardian:** reconciles source, mirrors, MOC, changelog, and this handoff after gates.

## Delivery exception

The repository owner directs issue work to commit directly to `dev`, reference the delivered commit
on the issue, and close it without a pull request. Production validation and source/vault parity
remain required.

## Contract

- `prepare` and `BytePlan` retain exact behavior and shape.
- `prepareCompact` returns the existing `Plan`, with one retained `Markup` block per non-empty static
  run and every `Hole` left in source order.
- `compileCompact` returns the additive `CompactBytePlan`; every `StaticBlock` stores joined bytes and
  their exact length, while every `DynamicBlock` remains distinct.
- Compaction never crosses a slot, does not cache request data globally, and does not change how
  missing values, output budgets, text escaping, trusted markup, destinations, or `on*` attributes
  are handled.

## Measurement

The optimized same-machine probe used 1,200 adjacent `Fixed(Html.text("static"))` pieces. Preparation
ran forty times; response rendering ran eighty times from one prepared plan.

| Phase | Ordinary | Compact |
|---|---:|---:|
| retained plan parts | 1,200 | 1 |
| preparation elapsed | 0.67s | 0.62s |
| preparation maximum RSS | 86,556,672 bytes | 85,491,712 bytes |
| render elapsed | 0.26s | 0.06s |
| render maximum RSS | 87,588,864 bytes | 84,410,368 bytes |

The measurements include compiler/runtime startup and one macOS host. They compare these two probes;
they are not service latency, allocation, network, or portable complexity guarantees.

## Exact next action

Commit directly to `dev`, post the commit on issue #257, close it, and continue to issue #258.

## Completion evidence

- `UsesHtmlCompact.pudu` checks without diagnostics and returns all 19 focused assertions.
- The warning-free optimized build, complete optimized test suite, formatter, diagnostic-code,
  release-plan, API-coverage, residency, lint, LSP session/robustness, and documentation-site gates
  pass.
- The generated-project scaffold stage failed once inside the aggregate gate; its exact command was
  rerun unchanged and passed initialization, dependency layering, run, test, format, lint, and build.
- `git diff --check` passes, source files remain below 500 lines, and source/mirror/MOC/changelog
  parity is complete.

## Referenced by

[[handoffs/_MOC]] · [[Std Html SSR]] · [[Std Html Buffer]] · [[src/Std/_MOC]]
