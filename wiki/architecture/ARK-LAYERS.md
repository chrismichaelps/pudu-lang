---
type: architecture
status: ACTIVE
aliases: [Ark Dependency Layers]
tags: [architecture, ark, dependencies]
---
# Ark Dependency Layers

The engine is an integrated Pudu library rooted in Ark. Actual source imports define edges;
architectural permission comes from this catalog, never from measured graph depth.

| Layer | Root modules |
| --- | --- |
| 0 | Ark.Math, Ark.Core |
| 1 | Ark.Platform |
| 2 | Ark.Assets, Ark.World |
| 3 | Ark.Render, Ark.Physics, Ark.Audio, Ark.Net |
| 4 | Ark.Animation, Ark.UI |
| 5 | Ark.Game |
| 6 | Ark.Editor, Ark.Tools |
| 7 | Ark.Build |

Across roots, imports descend strictly. Within one root, submodules may compose acyclically.
Submodules inherit their root's layer. Unknown Ark roots, bare Ark, cycles, missing imports,
duplicate declarations and source-path disagreement fail validation. Ark may import shared Std
utilities. Non-Ark sources cannot import Ark: this also rejects reverse edges hidden within a
shared dependency. Peer system integration belongs in a higher composition layer.

The gate scans the complete shipped library, reusing the Pudu declaration scanner and iterative
SCC/depth model. Reports contain identities, relative paths, imports, architectural layers,
structural depths and sorted findings; no source text or private inputs. Zero engine declarations
is valid while the foundation PR is pending. New root families require an explicit catalog review.
This gate checks import architecture, not types, execution, native FFI confinement or performance.
The engine's separate native target must not be inferred from a clean import graph.

## Resolved Grill Log

- **Q:** Infer permitted layers from current imports? **A:** No; doing so lets a bad edge authorize itself.
- **Q:** Ban Math submodules from composing? **A:** No; same-root composition is allowed, cycles are not.
- **Q:** Check only Ark files? **A:** No; shared utilities must not lead back into the engine.
- **Q:** Use recursion for depth/SCCs? **A:** No; reuse explicit stacks and deterministic graph output.

## Referenced by

[[architecture/_MOC]] · [[Ark Layer Model]] · [[Ark Layer Gate]] · [[Ark Layer Tests]]
