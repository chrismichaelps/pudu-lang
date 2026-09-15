---
type: module
path: "@root/website/src/Web/Routes.pudu"
fidelity: Active
tags: [website, http, routing]
aliases: [website Web Routes]
---
# Website Web Routes

Maps home, search, module, symbol, documentation, about, donation, health, and local asset paths to services and views. It
also creates synthetic requests for platform rendering and route tests. `routes` and `render` take the
loaded documentation beside the catalogue. `/docs` is the documentation index and `/docs/:page` one
page, answering 404 for an address no page has; `/guide` renders the index with `/docs` as its
canonical address. A route matches only a path with its own number of segments, so `/docs/:page`
never captures `/docs/:module/:kind/:name`.

Resolved Grill Log: route handlers translate only; catalogue lookup and ranking remain services.
Same-kind, same-name declarations are passed to one symbol-family view rather than discarded or
assigned unstable ordinal URLs. The kind segment also separates case-folding type/function paths.
