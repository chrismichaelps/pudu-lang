---
type: module
path: "@root/website/src/Web/Routes.pudu"
fidelity: Active
tags: [website, http, routing]
aliases: [website Web Routes]
---
# Website Web Routes

Maps home, search, module, symbol, documentation, package catalog/search/profile/project/source/docs/releases/tickets/contributions, about, donation, health, and local asset paths to services and views. It
also creates synthetic requests for platform rendering and route tests. `routes` and `render` take the
loaded documentation beside the catalogue. `/docs` is the documentation index and `/docs/:page` one
page, answering 404 for an address no page has; `/guide` renders the index with `/docs` as its
canonical address. Both documentation views receive the catalogue's language version for their
metadata. A route matches only a path with its own number of segments, so `/docs/:page`
never captures `/docs/:module/:kind/:name`. Specific site and asset routes precede general package paths; package file parameters are URL-decoded and admitted only by the snapshot's file listing.
Numbered catalogue, handle, ticket, and contribution paths serve bounded list pages. The local
asset route admits only the reviewed package file icons.
Package search accepts an optional project filter. The filter searches inside that project, so
declaration matches come from it alone and no project rows are listed; pagination preserves it.
`GET /packages/suggest?q=&filter=` answers the suggestion box with bounded JSON from
[[website View Packages Suggest]], including standard library matches from the loaded catalogue.

Resolved Grill Log: route handlers translate only; catalogue lookup and ranking remain services.
Same-kind, same-name declarations are passed to one symbol-family view rather than discarded or
assigned unstable ordinal URLs. The kind segment also separates case-folding type/function paths.

## Package pages shared (#367)

The `/@owner` routes moved to [[website Web PackagePages]], which this router serves with the fully
loaded snapshot and an identity `detail` step, so the function renders the same pages.

Resolved Grill Log: one package route list serves both hosts; this module keeps only its own 404 view.
