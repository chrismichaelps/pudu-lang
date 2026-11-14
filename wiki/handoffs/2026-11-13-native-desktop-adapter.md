---
type: handoff
status: ACTIVE
issue: 856
aliases: [Native Desktop Adapter Delivery]
---

# Native Desktop Adapter Delivery

Language Architect → Backend Engineer. The first partition owns the native
toolchain and packaged AppKit sources. The next partition owns lowering,
desktop window lifetimes, and host outcome conversion in [[Native Host Desktop]].

## Resolved Grill Log

Embed the existing platform sources in the compiler at build time. A desktop
runtime marker selects those sources. The native toolchain materializes them
as sibling translation units in a private temporary directory and passes
them and their frameworks to the same bounded compiler invocation. The
resulting executable needs no compiler data directory or separate adapter.
Ordinary generated programs carry no platform sources. Audio can select
another source bundle through the same seam.

## Exact next action

The macOS native smoke matches the interpreter for open, configure, present,
pump, close, and repeated-close refusal. The headless differential checks
also pass.

Verify counted desktop ownership and the unsupported platform branch in CI.

## Referenced by

[[handoffs/_MOC]] · [[Backend Toolchain]] · [[Native Application UI]]
