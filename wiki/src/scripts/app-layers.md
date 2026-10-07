---
type: module
path: "@root/scripts/app-layers.mjs"
fidelity: Active
tags: [tooling, application, graph]
aliases: [Application Layer Gate]
---
# Application Layer Gate

## Purpose and interface

Scan the shipped Pudu library and enforce [[Application Dependency Layers]]. Print a concise
report, or stable structured output with `--json`. Any finding exits unsuccessfully.

## Algorithm

Walk source files in stable order, read module declarations through [[Application Layer Model]],
and require each declared identity to match its library-relative path. Invalid arguments and
source failures fail explicitly. The command reads library sources only and mutates nothing.

## Resolved Grill Log

- **Q:** Depend on measured runtime costs to enforce imports? **A:** No; this gate is structural.
- **Q:** Silently accept an empty source tree? **A:** No; require shipped module sources.

## Referenced by

[[src/_MOC]] · [[Application Dependency Layers]] · [[Repository Gates]] · [[Pudu Continuous Verification]]
