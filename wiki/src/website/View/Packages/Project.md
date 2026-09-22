---
type: module
path: "@root/website/src/View/Packages/Project.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Project]
---
# Website Package Project

Renders a project's overview from its README and metadata, and the releases tab with notes, publication details, prior versions, and install commands. On the overview, compact metadata sits beside a bounded README reading surface; the project summary belongs in the shared banner.
An absent README title falls back to the package name as the page's primary heading.

See [[architecture/PACKAGES]] · [[website View Packages Frame]].

## Grill Log

Resolved Grill Log: release facts come from the immutable registry document; the view does not infer a version from a mutable GitHub tag.
