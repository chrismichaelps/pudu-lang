---
type: handoff
status: ACTIVE
issue: 856
aliases: [Native Desktop Adapter Delivery]
---

# Native Desktop Adapter Delivery

Language Architect → Backend Engineer. The first partition owns the native
toolchain and packaged AppKit sources. The next partition owns lowering,
desktop window lifetimes, and host outcome conversion.

## Resolved Grill Log

Embed the existing platform sources in the compiler at build time. A desktop
runtime marker selects those sources. The native toolchain materializes them
as sibling translation units in a private temporary directory and passes
them and their frameworks to the same bounded compiler invocation. The
resulting executable needs no compiler data directory or separate adapter.
Ordinary generated programs carry no platform sources. Audio can select
another source bundle through the same seam.

## Exact next action

Lower the desktop builtins to host outcomes using the selected AppKit bundle.
The warning-as-error library build and macOS adapter link probe passed.

## Referenced by

[[handoffs/_MOC]] · [[Backend Toolchain]] · [[Native Application UI]]
