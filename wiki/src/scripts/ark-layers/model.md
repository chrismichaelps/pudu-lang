---
type: module
path: "@root/scripts/ark-layers/model.mjs"
fidelity: Active
aliases: [Ark Layer Model]
tags: [module, ark, dependencies]
---
# Ark Layer Model

## Purpose and algorithm

Pure `analyze(sources)` validates [[Ark Dependency Layers]]. Reuse [[Dependency Layer Model]]
for duplicate identities, iterative SCCs and computed depth. Classify exact first two segments
against the fifteen-root catalog. Missing imports and all cycles fail; non-Ark callers of Ark
fail; Ark callers may reach Std utilities or a known Ark root. Different roots descend strictly;
same-root submodule edges are allowed. Unknown roots fail without a default layer.

Return sourceModules, engineModules, engine module metadata and sorted unique findings. Engine
metadata includes authored imports, including unresolved edges, with architectural layer/null
and structural depth. Stable identity ordering is independent of input order; no source contents.

## Resolved Grill Log

- **Q:** Drop unresolved imports from reports? **A:** No; preserve authored edges alongside findings.
- **Q:** Let an unknown root default to zero? **A:** No; unknown roots require catalog design.

## Referenced by

[[Ark Layer Gate]] · [[Ark Layer Tests]] · [[Ark Dependency Layers]] · [[src/_MOC]]
