---
type: module
path: "@root/website/src/Web/PackagePages.pudu"
fidelity: Active
tags: [website, routing, packages]
aliases: [website Web PackagePages]
---
# Website Package Pages

The routes under `/@owner`, shared by [[website Web Routes]] (the complete local site) and
[[website Web Dynamic]] (the function): project overview, releases, source files, API reference,
tickets and contributions with their pages and records, and owner profiles with their pages.

`Pages` names the index a page finds its project in and a `detail` step that fills a found project
with what one tab shows (`overview`, `releases`, `source` plus the file, `docs`, `tickets`,
`contributions`). The local site passes the fully loaded project through; the function fills it from
the snapshot directory or from GitHub ([[website Service LivePackages]]). Only handles beginning with
`@` name projects. `missing` answers every refusal, so each host keeps its own 404 page and caching.

See [[website Web Routes]] · [[website Web Dynamic]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Duplicate the package routes in the function? **A:** No; one route list with an injected
  project filler. _Rationale:_ the static and live hosts must render identical pages.

Resolved Grill Log: the router decides which tab is asked for and renders views; where the data comes
from is the caller's `detail`, so no GitHub or file-system policy lives here.
