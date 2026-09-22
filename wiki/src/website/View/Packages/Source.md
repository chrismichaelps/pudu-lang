---
type: module
path: "@root/website/src/View/Packages/Source.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Source]
---
# Website Package Source

Renders a latest-release file tree with a selected file and linkable source lines. Every file route derives from the checked snapshot list; an unknown file has no page. Binary files get a no-preview page, and source links use the release's immutable commit. Encoded path segments are decoded before lookup; each file page names its own canonical URL.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

Resolved Grill Log: source browsing uses registry-mirrored release bytes, so moved or deleted GitHub tags cannot change the page's content until a new snapshot.
