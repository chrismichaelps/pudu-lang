---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Toolchain/HostSources.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Toolchain Host Sources]
---

# Native Toolchain Host Sources

Select the packaged host translation units and link flags from a marker in
the generated C. Write their exact contents into a temporary directory
owned by [[Backend Toolchain]], and return compiler arguments.

## Resolved Grill Log

Embed the existing AppKit sources and headers at compiler build time and
register each file as a compiler input. Materialize them only when a macOS
program selects the desktop marker. Put the staging directory on the include path. Keep headers beside their translation
units and use one compiler invocation to preserve cancellation and atomic
publication. A program on another platform selects no AppKit source.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Desktop Adapter Delivery]]
