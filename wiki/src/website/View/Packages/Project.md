---
type: module
path: "@root/website/src/View/Packages/Project.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Project]
---
# Website Package Project

Renders a project's overview and its releases tab.

The overview shows the README as a file (a `README.md` header over the rendered text) beside a side
column of sections divided by hairlines: Install (the unversioned command with a copy button),
Latest release (version in monospace, date, and a link to all releases), Dependencies, Topics, and
Details (module root, licence, and the repository as `owner/repo ↗`). Below 900px the side column
follows the README. The project summary belongs in the shared banner.

The releases tab opens with the shared tab heading ([[website View Packages Frame]]), then the latest
release as a block: a "Latest" tag, the version in large monospace, the byline with the commit, its
notes, and its exact install command with a copy button beside a link to the source. Earlier releases
follow as a ledger table with monospace versions and a yanked tag; the publisher column folds away on
a phone.
An absent README title falls back to the package name as the page's primary heading.

See [[architecture/PACKAGES]] · [[website View Packages Frame]].

## Grill Log

- **Q:** Put the install command only in the banner's disclosure? **A:** Also in the overview's side
  column. _Rationale:_ it is the one action most readers came for, and a visible line with a copy
  button needs no disclosure.

Resolved Grill Log: release facts come from the immutable registry document; the view does not infer a version from a mutable GitHub tag.
